"""
DeepSeek聊天服务模块，提供与DeepSeek API的交互功能
"""

import json
import logging
import asyncio
from typing import AsyncGenerator, Dict, Any, Optional, List

from openai import AsyncOpenAI

from app.core.config import settings
from app.services.mcp import MCPServiceManager
from app.services.mcp.manager import MCPManager
from app.services.mcp.tool_handler import ToolHandler
from app.services.mcp.models import MCPTransportType
from app.schemas.chat import UserMCPConfig

logger = logging.getLogger(__name__)

# 设置调试模式标志，从配置或环境变量获取
debug_mode = getattr(settings, "DEBUG_MCP_SERVICE", False)

# 如果启用了debug_mode，设置记录额外的调试信息
if debug_mode:
    logger.setLevel(logging.DEBUG)
    logger.debug("已启用MCP服务的调试模式")
else:
    logger.setLevel(logging.INFO)


class DeepSeekChatService:
    """DeepSeek聊天服务，用于处理聊天请求并返回流式响应"""

    def __init__(self):
        """初始化DeepSeek API客户端"""
        self.client = AsyncOpenAI(
            api_key=settings.DEEPSEEK_API_KEY,
            base_url=settings.DEEPSEEK_API_BASE,
        )
        # 初始化MCP服务管理器
        self.mcp_manager = MCPManager()
        self.tool_handler = ToolHandler(self.mcp_manager.mcp_service)

    async def initialize_all_mcp_clients(self):
        """
        初始化所有配置中的MCP客户端

        Returns:
            初始化的MCP客户端字典
        """
        return await self.mcp_manager.initialize_all_clients()

    async def initialize_user_mcp_client(self, config: UserMCPConfig):
        """
        初始化用户自定义MCP客户端

        Args:
            config: 用户自定义MCP配置（字典，键为服务器名称，值为服务器配置）

        Returns:
            初始化后的MCP客户端
        """
        return await self.mcp_manager.initialize_user_client(config)

    async def get_active_mcp_client(
        self, server_name: str = None, user_mcp_config: Optional[UserMCPConfig] = None
    ):
        """
        获取活动的MCP客户端，根据优先级：
        1. 用户配置的自定义客户端
        2. 指定名称的服务器客户端
        3. 默认的第一个服务器客户端
        """
        return await self.mcp_manager.get_active_client(server_name, user_mcp_config)

    async def get_all_tools(self):
        """
        获取所有服务器的所有工具
        """
        # 确保初始化所有服务器
        await self.initialize_all_mcp_clients()
        
        # 获取所有工具
        return await self.mcp_manager.get_all_tools()

    async def generate_chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: str,
        temperature: float = None,
        use_mcp: bool = False,
        user_mcp_config: Optional[UserMCPConfig] = None,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        通过DeepSeek API生成聊天完成

        Args:
            messages: 聊天消息列表
            model: 模型名称
            temperature: 模型温度，默认使用系统配置值
            use_mcp: 是否使用MCP工具
            user_mcp_config: 用户自定义MCP配置

        Yields:
            聊天完成响应块
        """
        try:
            # 从消息中获取服务器名称
            server_name = self._extract_server_name(messages)

            # 初始化MCP客户端并获取工具
            tools = None
            if use_mcp:
                tools = await self._prepare_tools(user_mcp_config, server_name)

            # 构建API请求参数
            params = await self._build_api_params(messages, model, temperature, tools)

            # 调用API
            logger.info(f"开始调用 {model} 模型生成聊天完成")
            response = await self.client.chat.completions.create(**params)

            # 处理流式响应
            async for chunk_dict in self._process_streaming_response(
                response, use_mcp, messages, model, temperature
            ):
                yield chunk_dict

        except Exception as e:
            logger.error(f"调用DeepSeek API错误: {str(e)}")
            raise

    def _extract_server_name(self, messages: List[Dict[str, str]]) -> Optional[str]:
        """从消息中提取服务器名称"""
        for msg in messages:
            if msg.get("role") == "user" and msg.get("content"):
                content = msg.get("content")
                if isinstance(content, dict) and "extra_params" in content:
                    extra_params = content.get("extra_params", {})
                    return extra_params.get("mcp_server_name")
        return None

    async def _prepare_tools(
        self, user_mcp_config: Optional[UserMCPConfig], server_name: Optional[str]
    ) -> Optional[List[Dict[str, Any]]]:
        """准备MCP工具"""
        tools = None
        
        try:
            if user_mcp_config:
                # 使用用户自定义配置
                await self.initialize_user_mcp_client(user_mcp_config)
                tools = await self.mcp_manager.get_all_tools()
            elif server_name:
                # 使用指定服务器
                server_config = settings.MCP_SERVERS.get(server_name, {})
                if not server_config:
                    logger.warning(f"未找到服务器名称: {server_name}")
                else:
                    await self.mcp_manager.initialize_server_client(server_name)
                    tools = await self.mcp_manager.get_all_tools()
            else:
                # 使用所有服务器
                tools = await self.get_all_tools()
        except Exception as e:
            logger.error(f"准备MCP工具时出错: {str(e)}")
            
        return tools

    async def _build_api_params(
        self, 
        messages: List[Dict[str, str]], 
        model: str, 
        temperature: float,
        tools: Optional[List[Dict[str, Any]]]
    ) -> Dict[str, Any]:
        """构建API请求参数"""
        params = {
            "model": model,
            "messages": messages,
            "stream": True,
            "temperature": temperature or settings.DEEPSEEK_DEFAULT_TEMPERATURE,
        }

        if tools:
            params["tools"] = tools
            
        return params

    async def _process_streaming_response(
        self,
        response,
        use_mcp: bool,
        messages: List[Dict[str, str]],
        model: str,
        temperature: float,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """处理流式响应"""
        tool_calls = []
        content_buffer = ""
        sent_tool_calls = set()  # 记录已发送的工具调用ID

        # 处理流式响应
        async for chunk in response:
            # 将原始chunk转换为字典
            chunk_dict = None
            if hasattr(chunk, "model_dump"):
                chunk_dict = chunk.model_dump()
            else:
                chunk_dict = dict(chunk)

            # 更新内容缓冲区
            if (
                hasattr(chunk.choices[0].delta, "content")
                and chunk.choices[0].delta.content
            ):
                content_buffer += chunk.choices[0].delta.content

            # 处理推理内容 (特别针对deepseek-reasoner模型)
            if (
                model == "deepseek-reasoner"
                and hasattr(chunk.choices[0].delta, "reasoning_content")
                and chunk.choices[0].delta.reasoning_content is not None
            ):
                chunk_dict = self._process_reasoner_chunk(chunk, chunk_dict)
                yield chunk_dict
                continue

            # 处理工具调用
            if (
                hasattr(chunk.choices[0].delta, "tool_calls")
                and chunk.choices[0].delta.tool_calls
            ):
                tool_calls = await self.tool_handler.update_tool_calls(
                    chunk, tool_calls
                )

            # 发送内容（没有工具调用信息）
            if (
                hasattr(chunk.choices[0].delta, "content")
                and chunk.choices[0].delta.content
            ):
                yield chunk_dict

            # 如果是最后一个块且包含usage信息，确保传递它
            if (
                hasattr(chunk.choices[0], "finish_reason")
                and chunk.choices[0].finish_reason == "stop"
                and hasattr(chunk, "usage")
            ):
                logger.info(f"检测到包含token使用统计的最终响应: {chunk.usage}")
                yield chunk_dict

            # 处理工具调用完成事件
            is_tool_call_finished = (
                hasattr(chunk.choices[0], "finish_reason")
                and chunk.choices[0].finish_reason == "tool_calls"
            )

            # 检查是否有新完成的工具调用需要发送
            if tool_calls and is_tool_call_finished:
                # 发送所有尚未发送的工具调用（开始调用）
                for i, tool_call in enumerate(tool_calls):
                    tool_id = tool_call.get("id", str(i))
                    if tool_id not in sent_tool_calls:
                        # 发送工具调用开始消息
                        start_chunk = {
                            "choices": [{"delta": {}, "finish_reason": None}],
                            "tool_call_start": True,
                            "complete_tool_calls": [tool_call],
                        }
                        yield start_chunk
                        sent_tool_calls.add(tool_id)

                # 如果启用了工具，执行工具调用
                if use_mcp:
                    # 处理工具调用并获取结果
                    tool_results = await self.tool_handler.process_tool_calls(
                        tool_calls
                    )
                    
                    # 发送工具调用结果
                    for tool_call, result in tool_results:
                        result_chunk = {
                            "choices": [{"delta": {}, "finish_reason": None}],
                            "tool_call_result": True,
                            "complete_tool_calls": [tool_call],
                            "tool_result": str(result),
                        }
                        yield result_chunk

                    # 更新消息列表，添加工具调用和结果
                    updated_messages = self._update_messages_with_tool_results(
                        messages, content_buffer, tool_calls, tool_results
                    )
                    
                    # 递归调用生成新的完成
                    try:
                        async for new_chunk in self.generate_chat_completion(
                            messages=updated_messages,
                            model=model,
                            temperature=temperature,
                            use_mcp=False,  # 避免无限递归
                        ):
                            yield new_chunk
                    except Exception as recursive_error:
                        logger.error(f"递归调用chat completion时出错: {str(recursive_error)}")
                        yield {
                            "choices": [
                                {
                                    "delta": {
                                        "content": f"\n\n继续对话时出错: {str(recursive_error)}"
                                    },
                                    "finish_reason": "error",
                                }
                            ]
                        }

    def _process_reasoner_chunk(self, chunk, chunk_dict):
        """处理推理模型的响应块"""
        if (
            "choices" in chunk_dict
            and chunk_dict["choices"]
            and "delta" in chunk_dict["choices"][0]
        ):
            if "reasoning_content" not in chunk_dict["choices"][0]["delta"]:
                chunk_dict["choices"][0]["delta"]["reasoning_content"] = (
                    chunk.choices[0].delta.reasoning_content
                )
        logger.debug(
            f"处理推理内容: {chunk.choices[0].delta.reasoning_content}"
        )
        return chunk_dict

    def _update_messages_with_tool_results(
        self, 
        messages, 
        content_buffer, 
        tool_calls, 
        tool_results
    ):
        """使用工具调用结果更新消息列表"""
        updated_messages = messages.copy()
        
        # 将助手消息添加到消息列表
        updated_messages.append(
            {
                "role": "assistant",
                "content": content_buffer,
                "tool_calls": tool_calls,
            }
        )
        
        # 添加工具结果消息
        for tool_call, result in tool_results:
            updated_messages.append(
                {
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": str(result),
                }
            )
            
        return updated_messages

    async def cleanup(self):
        """清理资源"""
        try:
            await self.mcp_manager.cleanup()
            logger.debug("MCP服务资源清理完成")
        except Exception as e:
            logger.error(f"清理MCP服务资源时出错: {str(e)}")
            logger.debug(f"错误详情: {type(e).__name__}", exc_info=True)
