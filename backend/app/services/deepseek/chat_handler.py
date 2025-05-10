"""
DeepSeek聊天处理模块，处理聊天请求并返回SSE格式的响应
"""

import logging
import traceback
from typing import AsyncGenerator, List, Dict, Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.crud.user import user as user_crud
from app.schemas.chat import ChatRequest
from .deepseek_chat import DeepSeekChatService
from .token_manager import TokenManager
from .message_processor import MessageProcessor
from .message_handler import MessageHandler

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
    message_handler = MessageHandler()

    # 检查用户token是否足够
    if not await user_crud.check_token_available(db, user_id, 10):  # 预估需要的token
        yield MessageProcessor.format_error_message("Token不足，请充值后继续使用")
        return

    # 确定使用的模型
    model = determine_model(request)

    # 准备聊天消息
    try:
        messages = await prepare_messages(request, message_handler)
    except ValueError as e:
        yield MessageProcessor.format_error_message(str(e))
        return

    # 获取温度设置
    temperature = request.temperature

    # 检查是否使用MCP工具
    use_mcp, mcp_compatible = check_mcp_compatibility(request, model)
    if not mcp_compatible:
        yield MessageProcessor.format_error_message(
            "深度思考模型不支持工具调用功能，请选择普通模式或关闭工具调用"
        )
        return
        
    # 如果请求使用MCP工具，初始化对应的MCP客户端
    if use_mcp:
        try:
            await initialize_mcp_clients(chat_service, request)
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
            # 处理响应块
            chunk_dict, response_message = await process_response_chunk(chunk, model)
            
            # 保存最后一个包含usage的响应块，用于获取token使用情况
            if "usage" in chunk_dict and chunk_dict["usage"] is not None:
                logger.info(f"捕获到token使用信息: {chunk_dict['usage']}")
                last_chunk_dict = chunk_dict
                
            # 发送响应
            if response_message:
                yield response_message

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

        # 清理资源
        await cleanup_resources(db, chat_service, use_mcp)

        # 发送结束标记
        yield "data: [DONE]\n\n"


def determine_model(request: ChatRequest) -> str:
    """
    根据请求确定使用的模型
    
    Args:
        request: 聊天请求对象
        
    Returns:
        模型名称
    """
    if not request.model or request.model == "deepseek":
        # 前端未传入模型名称或传入通用"deepseek"
        if request.use_deep_thinking:
            return "deepseek-reasoner"
        else:
            return "deepseek-chat"
    else:
        # 使用前端指定的模型
        return settings.DEFAULT_MODEL


async def prepare_messages(request: ChatRequest, message_handler: MessageHandler) -> List[Dict[str, Any]]:
    """
    准备聊天消息
    
    Args:
        request: 聊天请求对象
        message_handler: 消息处理器
        
    Returns:
        处理后的消息列表
    """
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
        processed_messages = await message_handler.process_reasoner_messages(
            context_messages, request.current_message
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
        await message_handler.validate_reasoner_messages(messages)
        
    return messages


def check_mcp_compatibility(request: ChatRequest, model: str) -> tuple[bool, bool]:
    """
    检查MCP工具兼容性
    
    Args:
        request: 聊天请求对象
        model: 模型名称
        
    Returns:
        (是否使用MCP, 是否兼容) 的元组
    """
    # 判断是否使用任何类型的MCP工具
    # 首先检查全局MCP开关是否开启
    use_mcp = request.use_mcp and (
        request.use_base_tools or request.user_mcp_config is not None
    )

    # 检查模型与工具使用的兼容性
    if use_mcp and model == "deepseek-reasoner":
        logger.warning("深度思考模型(deepseek-reasoner)不支持工具调用功能")
        return use_mcp, False
        
    return use_mcp, True


async def initialize_mcp_clients(chat_service: DeepSeekChatService, request: ChatRequest) -> None:
    """
    初始化MCP客户端
    
    Args:
        chat_service: DeepSeek聊天服务
        request: 聊天请求对象
    """
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
                await chat_service.get_active_mcp_client(server_name)
        else:
            # 如果未指定服务器名称，初始化所有服务器
            logger.info("未指定服务器名称，将使用所有可用服务器")
            await chat_service.initialize_all_mcp_clients()

        logger.info("基础MCP客户端初始化成功")


async def process_response_chunk(chunk, model: str) -> tuple[Dict[str, Any], str]:
    """
    处理响应块
    
    Args:
        chunk: 响应块
        model: 模型名称
        
    Returns:
        (处理后的块字典, SSE消息) 的元组
    """
    # 转换响应块为字典
    if hasattr(chunk, "model_dump"):
        chunk_dict = chunk.model_dump()
    else:
        chunk_dict = dict(chunk)

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
        return chunk_dict, MessageProcessor.format_sse_message(
            content=None, reasoning_content=None, tool_calls=[tool_call]
        )

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
        return chunk_dict, MessageProcessor.format_sse_message(
            content=None, reasoning_content=None, tool_calls=[tool_call]
        )

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
            return chunk_dict, MessageProcessor.format_sse_message(
                content, reasoning_content
            )
        elif content is not None:
            return chunk_dict, MessageProcessor.format_sse_message(
                content=content, reasoning_content=None
            )
    
    return chunk_dict, None


async def cleanup_resources(db: AsyncSession, chat_service: DeepSeekChatService, use_mcp: bool) -> None:
    """
    清理资源
    
    Args:
        db: 异步数据库会话
        chat_service: DeepSeek聊天服务
        use_mcp: 是否使用了MCP工具
    """
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
