"""
DeepSeek聊天处理模块，处理聊天请求并返回SSE格式的响应
"""

import logging
import traceback
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.crud.user import user as user_crud
from app.schemas.chat import ChatRequest
from .deepseek_chat import DeepSeekChatService
from .token_manager import TokenManager
from .message_processor import MessageProcessor

logger = logging.getLogger(__name__)


async def handle_deepseek_chat(
    request: ChatRequest, db: AsyncSession, user_id: int
) -> AsyncGenerator[str, None]:
    """
    处理DeepSeek聊天请求并返回SSE格式的响应

    Args:
        request: 聊天请求对象
        db: 异步数据库会话
        user_id: 用户ID

    Yields:
        SSE格式的聊天响应内容
    """
    # 初始化DeepSeek聊天服务
    chat_service = DeepSeekChatService()

    # 检查用户token是否足够
    if not await user_crud.check_token_available(db, user_id, 10):  # 预估需要的token
        yield MessageProcessor.format_error_message("Token不足，请充值后继续使用")
        return

    # 确定使用的模型
    if not request.model or request.model == "deepseek":
        # 前端未传入模型名称或传入通用"deepseek"
        if request.use_deep_thinking:
            model = "deepseek-reasoner"
        else:
            model = "deepseek-chat"
    else:
        # 使用前端指定的模型
        model = settings.DEFAULT_MODEL

    # 准备聊天消息
    messages = []

    # 添加系统提示
    messages.append({"role": "system", "content": settings.DEEPSEEK_SYSTEM_PROMPT})

    # 检查是否使用深度思考模型
    is_reasoner = request.use_deep_thinking

    # 添加上下文消息，保留最近的context_length条
    context_messages = request.context_messages
    if len(context_messages) > request.context_length:
        context_messages = context_messages[-request.context_length :]

    # 如果是deepseek-reasoner模型，需要特殊处理消息序列
    if is_reasoner and context_messages:
        # 处理消息序列，确保第一条是用户消息，并且用户和助手消息交替出现
        processed_messages = []

        # 查找第一条用户消息
        first_user_msg_index = -1
        for i, msg in enumerate(context_messages):
            if msg.role == "user":
                first_user_msg_index = i
                break

        if first_user_msg_index == -1:
            # 如果没有用户消息，使用当前消息（如果是用户消息）
            if request.current_message.role == "user":
                # 只添加当前用户消息，跳过所有上下文
                logger.warning(
                    "上下文中没有用户消息，且当前消息是用户消息，将跳过所有上下文消息"
                )
                context_messages = []
            else:
                # 如果当前消息也不是用户消息，则无法满足要求
                logger.error(
                    "无法为deepseek-reasoner模型准备有效的消息序列：没有用户消息"
                )
                # 返回一个只有系统消息的列表，让API返回错误
                yield MessageProcessor.format_error_message(
                    "无法为深度思考模型准备有效的消息序列：没有用户消息"
                )
                return
        else:
            # 开始处理消息序列，确保用户和助手消息交替出现
            # 首先添加第一条用户消息
            processed_messages.append(context_messages[first_user_msg_index])

            # 然后交替添加用户和助手消息
            expected_role = (
                "assistant"  # 第一条消息是用户消息，所以下一个期望是助手消息
            )

            # 遍历剩余消息，按照交替顺序添加
            for i, msg in enumerate(context_messages):
                # 跳过已经添加的第一条用户消息
                if i == first_user_msg_index:
                    continue

                # 如果消息角色与期望的角色匹配，则添加并切换期望角色
                if msg.role == expected_role:
                    processed_messages.append(msg)
                    expected_role = (
                        "user" if expected_role == "assistant" else "assistant"
                    )

            # 替换原始消息列表
            logger.warning(
                "为deepseek-reasoner模型重新排序消息，确保用户和助手消息交替出现"
            )
            context_messages = processed_messages

    # 添加处理后的上下文消息
    for msg in context_messages:
        messages.append({"role": msg.role, "content": msg.content})

    # 添加当前消息，确保与前一条消息角色不同
    current_msg_role = request.current_message.role
    current_msg_content = request.current_message.content

    # 如果是deepseek-reasoner模型且有上下文消息，检查当前消息是否与最后一条消息角色相同
    if is_reasoner and len(messages) > 1 and messages[-1]["role"] == current_msg_role:
        logger.warning(
            f"当前消息角色({current_msg_role})与最后一条消息角色相同，不添加到消息序列中"
        )
    else:
        # 添加当前消息
        messages.append({"role": current_msg_role, "content": current_msg_content})

    # 如果是deepseek-reasoner模型，再次检查消息序列是否有效
    if is_reasoner:
        # 检查第一条非系统消息是否为用户消息
        if len(messages) > 1 and messages[1]["role"] != "user":
            logger.error(
                "无法为deepseek-reasoner模型准备有效的消息序列：第一条非系统消息不是用户消息"
            )
            # 返回一个错误消息
            yield MessageProcessor.format_error_message(
                "无法为深度思考模型准备有效的消息序列：第一条非系统消息不是用户消息"
            )
            return

        # 检查是否有连续的相同角色消息
        for i in range(1, len(messages) - 1):
            if messages[i]["role"] == messages[i + 1]["role"]:
                logger.error(
                    f"无法为deepseek-reasoner模型准备有效的消息序列：消息{i + 1}和{i + 2}都是{messages[i]['role']}角色"
                )
                logger.warning(f"消息序列：{[msg['role'] for msg in messages]}")

                # 尝试修复消息序列，删除连续相同角色的消息
                fixed_messages = [messages[0]]  # 保留系统消息
                last_role = None

                # 重新构建消息序列，确保角色交替
                for j in range(1, len(messages)):
                    current_role = messages[j]["role"]
                    if current_role != last_role:  # 只添加与前一条消息角色不同的消息
                        fixed_messages.append(messages[j])
                        last_role = current_role

                # 检查修复后的消息序列是否有效
                if len(fixed_messages) > 1 and fixed_messages[1]["role"] != "user":
                    logger.error(
                        "修复后的消息序列仍然无效：第一条非系统消息不是用户消息"
                    )
                    yield MessageProcessor.format_error_message(
                        "无法为深度思考模型准备有效的消息序列：修复后仍然无效"
                    )
                    return

                logger.warning(
                    f"修复后的消息序列：{[msg['role'] for msg in fixed_messages]}"
                )
                messages = fixed_messages

    # 获取温度设置
    temperature = request.temperature

    # 判断是否使用任何类型的MCP工具
    # 首先检查全局MCP开关是否开启
    use_mcp = request.use_mcp and (
        request.use_base_tools or request.user_mcp_config is not None
    )

    # 检查模型与工具使用的兼容性
    if use_mcp and model == "deepseek-reasoner":
        logger.warning("深度思考模型(deepseek-reasoner)不支持工具调用功能")
        yield MessageProcessor.format_error_message(
            "深度思考模型不支持工具调用功能，请选择普通模式或关闭工具调用"
        )
        return

    # 如果请求使用MCP工具，初始化对应的MCP客户端
    if use_mcp:
        try:
            logger.info("正在初始化MCP客户端...")

            # 根据配置决定使用哪种MCP客户端
            if request.user_mcp_config:
                # 使用用户自定义MCP配置
                logger.info("使用用户自定义MCP配置")
                logger.info(f"用户配置的服务器: {list(request.user_mcp_config.keys())}")
                await chat_service.initialize_user_mcp_client(request.user_mcp_config)
                logger.info("用户自定义MCP客户端初始化成功")
            else:
                # 使用基本MCP工具
                logger.info("使用基础MCP工具")
                # 获取服务器名称
                server_name = request.mcp_server_name

                # 如果指定了服务器名称，先检查是否有效
                if server_name:
                    if server_name not in settings.MCP_SERVERS:
                        logger.warning(
                            f"指定的MCP服务器名称无效: {server_name}，将使用所有服务器"
                        )
                        server_name = None
                    else:
                        logger.info(f"使用指定的MCP服务器: {server_name}")
                        await chat_service.initialize_mcp_client(server_name)
                else:
                    # 如果未指定服务器名称，初始化所有服务器
                    logger.info("未指定服务器名称，将使用所有可用服务器")
                    await chat_service.initialize_all_mcp_clients()

                logger.info("基础MCP客户端初始化成功")
        except Exception as e:
            logger.error(f"初始化MCP客户端失败: {str(e)}")
            yield MessageProcessor.format_error_message(f"初始化工具失败: {str(e)}")
            return

    # 最后一个有效响应块，用于提取token使用信息
    last_chunk_dict = None

    try:
        # 调用DeepSeek聊天服务生成回复
        async for chunk in chat_service.generate_chat_completion(
            messages,
            model,
            temperature,
            use_mcp=use_mcp,
            user_mcp_config=request.user_mcp_config,
        ):
            # 转换响应块为字典
            if hasattr(chunk, "model_dump"):
                chunk_dict = chunk.model_dump()
            else:
                chunk_dict = dict(chunk)

            # 保存最后一个包含usage的响应块，用于获取token使用情况
            if "usage" in chunk_dict and chunk_dict["usage"] is not None:
                logger.info(f"捕获到token使用信息: {chunk_dict['usage']}")
                last_chunk_dict = chunk_dict

            # 提取正文内容、推理内容和工具调用
            content, reasoning_content, tool_calls = MessageProcessor.extract_content(
                chunk_dict
            )

            # 记录提取到的内容类型(调试用)
            if model == "deepseek-reasoner":
                logger.debug(
                    f"从deepseek-reasoner响应中提取内容: content={content is not None}, "
                    f"reasoning_content={reasoning_content is not None}, "
                    f"tool_calls={tool_calls is not None}"
                )
                if reasoning_content:
                    logger.debug(f"推理内容样本: {reasoning_content[:50]}...")

            # 特殊处理工具调用开始和结果事件
            if (
                "tool_call_start" in chunk_dict
                and chunk_dict["tool_call_start"]
                and "complete_tool_calls" in chunk_dict
            ):
                # 工具调用开始事件
                tool_call = chunk_dict["complete_tool_calls"][0]
                yield MessageProcessor.format_sse_message(
                    content=None, reasoning_content=None, tool_calls=[tool_call]
                )
                continue

            if (
                "tool_call_result" in chunk_dict
                and chunk_dict["tool_call_result"]
                and "complete_tool_calls" in chunk_dict
            ):
                # 工具调用结果事件
                tool_call = chunk_dict["complete_tool_calls"][0]
                # 将工具结果放在tool_call中，而不是content中
                if "tool_result" in chunk_dict and chunk_dict["tool_result"]:
                    tool_call["result"] = chunk_dict["tool_result"]
                yield MessageProcessor.format_sse_message(
                    content=None, reasoning_content=None, tool_calls=[tool_call]
                )
                continue

            # 处理普通内容
            if content is not None or reasoning_content is not None:
                if model == "deepseek-reasoner" and (
                    content is not None or reasoning_content is not None
                ):
                    # 深度思考模式：确保同时传递content和reasoning_content
                    logger.debug(
                        f"为deepseek-reasoner生成SSE消息，内容长度: content={len(content) if content else 0}, "
                        f"reasoning_content={len(reasoning_content) if reasoning_content else 0}"
                    )
                    yield MessageProcessor.format_sse_message(
                        content, reasoning_content
                    )
                elif content is not None:
                    yield MessageProcessor.format_sse_message(
                        content=content, reasoning_content=None
                    )

    except Exception as e:
        logger.error(f"处理聊天请求时出错: {str(e)}")
        logger.error(f"错误详情: {traceback.format_exc()}")
        yield MessageProcessor.format_error_message(f"处理请求时出错: {str(e)}")

    finally:
        # 在结束前处理token使用情况
        if last_chunk_dict and "usage" in last_chunk_dict:
            usage_data = last_chunk_dict["usage"]
            await TokenManager.update_token_usage(db, user_id, usage_data)
        else:
            logger.warning("未获取到有效的token使用数据，跳过token使用统计")

        # 清理数据库连接
        try:
            if not db.is_active:
                await db.close()
                logger.warning("数据库清理完毕")
        except Exception as e:
            logger.error(f"清理数据库连接时出错: {str(e)}")

        # 清理MCP客户端资源
        if use_mcp:
            try:
                await chat_service.cleanup()
            except Exception as e:
                logger.error(f"清理MCP客户端资源时出错: {str(e)}")
                logger.error(f"错误详情: {traceback.format_exc()}")

        # 发送结束标记
        yield "data: [DONE]\n\n"
