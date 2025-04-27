"""
DeepSeek聊天服务模块，提供与DeepSeek API的交互功能
"""

import json
import logging
import asyncio
from typing import AsyncGenerator, Dict, Any, Optional, List

from openai import AsyncOpenAI

from app.core.config import settings
from .mcp_client import MultiprocessMCPClientService
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
        self.mcp_clients = {}  # 存储多个MCP客户端的字典，键为服务器名称
        self.tool_to_server_map = {}  # 工具名称到服务器名称的映射
        # 设置是否使用多进程实现
        self.use_multiprocess = True  # 默认使用多进程实现

    async def initialize_all_mcp_clients(self):
        """
        初始化所有配置中的MCP客户端

        Returns:
            初始化的MCP客户端字典
        """
        for server_name in settings.MCP_SERVERS:
            if server_name not in self.mcp_clients:
                await self.initialize_mcp_client(server_name)

        return self.mcp_clients

    async def initialize_mcp_client(self, server_name: str = None):
        """
        初始化MCP客户端

        Args:
            server_name: MCP服务器名称，用于从配置中获取服务器URL和环境变量

        Returns:
            初始化后的MCP客户端
        """
        # 如果未指定服务器名称，使用默认的第一个服务器
        if not server_name and settings.MCP_SERVERS:
            server_name = next(iter(settings.MCP_SERVERS.keys()))

        # 检查服务器名称是否有效
        if not server_name or server_name not in settings.MCP_SERVERS:
            raise ValueError(f"无效的MCP服务器名称: {server_name}")

        # 如果已经初始化过该服务器的客户端，直接返回
        if server_name in self.mcp_clients and self.mcp_clients[server_name]:
            return self.mcp_clients[server_name]

        # 获取服务器配置
        server_config = settings.MCP_SERVERS[server_name]

        # 初始化MCP客户端
        url = server_config.get("url")
        env = server_config.get("env", {})

        if not url:
            raise ValueError(f"MCP服务器配置中未指定URL: {server_name}")

        # 创建新的MCP客户端，根据配置选择使用多进程或异步实现
        if self.use_multiprocess:
            logger.info(f"使用多进程实现初始化MCP客户端: {server_name}")
            mcp_client = MultiprocessMCPClientService(url=url, env=env)
            success = await mcp_client.connect()
            if not success:
                raise ValueError(f"无法连接到MCP服务器: {url}")

        # 存储客户端引用
        self.mcp_clients[server_name] = mcp_client

        # 更新工具到服务器的映射
        for tool_name in mcp_client.available_tools:
            self.tool_to_server_map[tool_name] = server_name

        logger.info(f"已初始化MCP客户端: {server_name}")
        return mcp_client

    async def initialize_user_mcp_client(self, config: UserMCPConfig):
        """
        初始化用户自定义MCP客户端

        Args:
            config: 用户自定义MCP配置（字典，键为服务器名称，值为服务器配置）

        Returns:
            初始化后的MCP客户端
        """
        # 如果配置为空，直接返回
        if not config:
            raise ValueError("用户MCP配置为空")

        # 初始化所有服务器的客户端
        for server_name, server_config in config.items():
            # 检查配置是否有效
            if not server_config.get("url"):
                logger.warning(f"服务器 {server_name} 的配置中未指定URL，已跳过")
                continue

            # 处理环境变量，确保没有空键
            env = server_config.get("env", {})
            if env:
                # 过滤掉空键
                filtered_env = {}
                for key, value in env.items():
                    if key and key.strip():  # 确保键不为空
                        filtered_env[key] = value
                env = filtered_env or {}
            else:
                env = {}

            # 创建专用客户端，根据配置选择使用多进程或异步实现
            if self.use_multiprocess:
                logger.info(f"使用多进程实现初始化用户自定义MCP客户端: {server_name}")
                url = server_config.get("url")
                mcp_client = MultiprocessMCPClientService(url=url, env=env)
                success = await mcp_client.connect()
                if not success:
                    logger.warning(f"无法连接到用户自定义MCP服务器: {url}，已跳过")
                    continue

                # 存储客户端
                self.mcp_clients[server_name] = mcp_client

                # 更新工具到服务器的映射
                for tool_name in mcp_client.available_tools:
                    self.tool_to_server_map[tool_name] = server_name

                logger.info(f"成功初始化服务器 {server_name} 的MCP客户端")

        # 返回第一个初始化成功的客户端（如果有）
        if self.mcp_clients:
            first_server = next(iter(self.mcp_clients.keys()))
            return self.mcp_clients[first_server]
        else:
            raise ValueError("没有成功初始化的MCP客户端")

    async def get_active_mcp_client(
        self, server_name: str = None, user_mcp_config: Optional[UserMCPConfig] = None
    ):
        """
        获取活动的MCP客户端，根据优先级：
        1. 用户配置的自定义客户端
        2. 指定名称的服务器客户端
        3. 默认的第一个服务器客户端

        Args:
            server_name: 服务器名称
            user_mcp_config: 用户自定义MCP配置（字典，键为服务器名称，值为服务器配置）

        Returns:
            活动的MCP客户端
        """
        # 优先使用用户自定义配置
        if user_mcp_config:
            # 检查是否已经初始化了用户自定义客户端
            # 如果没有，初始化它们
            has_initialized = False
            for server_name in user_mcp_config.keys():
                if server_name in self.mcp_clients:
                    has_initialized = True
                    break

            if not has_initialized:
                await self.initialize_user_mcp_client(user_mcp_config)

            # 返回第一个初始化成功的客户端
            if self.mcp_clients:
                first_server = next(iter(self.mcp_clients.keys()))
                return self.mcp_clients[first_server]
            else:
                raise ValueError("没有成功初始化的MCP客户端")

        # 使用指定服务器名称
        if server_name:
            if server_name not in self.mcp_clients:
                await self.initialize_mcp_client(server_name)
            return self.mcp_clients[server_name]

        # 使用默认服务器
        if settings.MCP_SERVERS:
            default_server = next(iter(settings.MCP_SERVERS.keys()))
            if default_server not in self.mcp_clients:
                await self.initialize_mcp_client(default_server)
            return self.mcp_clients[default_server]
        else:
            raise ValueError("没有可用的MCP服务器")

    async def get_client_for_tool(self, tool_name: str):
        """
        获取特定工具对应的MCP客户端

        Args:
            tool_name: 工具名称

        Returns:
            对应的MCP客户端
        """
        if tool_name not in self.tool_to_server_map:
            raise ValueError(f"未找到工具 '{tool_name}' 对应的服务器")

        server_name = self.tool_to_server_map[tool_name]
        return self.mcp_clients[server_name]

    async def get_all_tools(self):
        """
        获取所有服务器的所有工具

        Returns:
            所有工具的列表
        """
        # 确保初始化所有服务器
        await self.initialize_all_mcp_clients()

        all_tools = []
        # 从所有客户端收集工具
        for client_name, client in self.mcp_clients.items():
            logger.debug(f"从客户端 {client_name} 获取工具列表")

            # 确保工具列表是最新的
            if isinstance(client, MultiprocessMCPClientService):
                # 对于多进程客户端，显式更新工具列表
                await client.update_available_tools()

            for tool_name, tool_info in client.available_tools.items():
                # 处理不同类型客户端的工具信息格式
                if isinstance(client, MultiprocessMCPClientService):
                    # 多进程客户端的工具信息是字典
                    tool_function = {
                        "name": tool_name,
                        "description": tool_info.get("description", ""),
                        "parameters": tool_info.get("inputSchema", {}),
                    }
                else:
                    # 异步客户端的工具信息是对象
                    tool_function = {
                        "name": tool_name,
                        "description": tool_info.description
                        if hasattr(tool_info, "description")
                        else "",
                        "parameters": tool_info.inputSchema
                        if hasattr(tool_info, "inputSchema")
                        else {},
                    }

                # 添加到工具列表
                all_tools.append(
                    {
                        "type": "function",
                        "function": tool_function,
                    }
                )

        logger.info(
            f"收集了 {len(all_tools)} 个工具，来自 {len(self.mcp_clients)} 个服务器"
        )
        return all_tools

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
            server_name = None
            for msg in messages:
                if msg.get("role") == "user" and msg.get("content"):
                    content = msg.get("content")
                    if isinstance(content, dict) and "extra_params" in content:
                        extra_params = content.get("extra_params", {})
                        server_name = extra_params.get("mcp_server_name")
                        break

            # 初始化MCP客户端并获取工具
            tools = None
            if use_mcp:
                if user_mcp_config:
                    # 如果有用户自定义配置，使用用户配置的客户端
                    # 检查是否已经初始化了用户自定义客户端
                    initialized_servers = []
                    for server_name in user_mcp_config.keys():
                        if server_name in self.mcp_clients:
                            initialized_servers.append(server_name)

                    # 如果没有初始化，初始化它们
                    if not initialized_servers:
                        await self.initialize_user_mcp_client(user_mcp_config)
                        # 重新获取初始化的服务器列表
                        initialized_servers = [
                            name
                            for name in user_mcp_config.keys()
                            if name in self.mcp_clients
                        ]

                    logger.info(f"已初始化的MCP服务器: {initialized_servers}")

                    # 初始化工具列表
                    tools = []

                    # 从所有初始化的服务器收集工具
                    for server_name in initialized_servers:
                        mcp_client = self.mcp_clients[server_name]

                        # 确保工具列表是最新的
                        if isinstance(mcp_client, MultiprocessMCPClientService):
                            await mcp_client.update_available_tools()

                            # 收集该服务器的工具
                            server_tools = [
                                {
                                    "type": "function",
                                    "function": {
                                        "name": tool_name,
                                        "description": tool_info.get("description", ""),
                                        "parameters": tool_info.get("inputSchema", {}),
                                    },
                                }
                                for tool_name, tool_info in mcp_client.available_tools.items()
                            ]

                            # 添加到总工具列表
                            tools.extend(server_tools)
                            logger.info(
                                f"从服务器 {server_name} 收集了 {len(server_tools)} 个工具"
                            )
                        else:
                            # 异步客户端的工具信息是对象
                            server_tools = [
                                {
                                    "type": "function",
                                    "function": {
                                        "name": tool_name,
                                        "description": tool.description
                                        if hasattr(tool, "description")
                                        else "",
                                        "parameters": tool.inputSchema
                                        if hasattr(tool, "inputSchema")
                                        else {},
                                    },
                                }
                                for tool_name, tool in mcp_client.available_tools.items()
                            ]

                            # 添加到总工具列表
                            tools.extend(server_tools)
                            logger.info(
                                f"从服务器 {server_name} 收集了 {len(server_tools)} 个工具"
                            )

                    logger.info(
                        f"总共收集了 {len(tools)} 个工具从 {len(initialized_servers)} 个服务器"
                    )
                elif server_name:
                    # 如果指定了服务器名称，使用指定服务器的客户端
                    mcp_client = await self.initialize_mcp_client(server_name)

                    # 确保工具列表是最新的
                    if isinstance(mcp_client, MultiprocessMCPClientService):
                        await mcp_client.update_available_tools()

                    # 根据客户端类型处理工具信息
                    if isinstance(mcp_client, MultiprocessMCPClientService):
                        # 多进程客户端的工具信息是字典
                        tools = [
                            {
                                "type": "function",
                                "function": {
                                    "name": tool_name,
                                    "description": tool_info.get("description", ""),
                                    "parameters": tool_info.get("inputSchema", {}),
                                },
                            }
                            for tool_name, tool_info in mcp_client.available_tools.items()
                        ]
                    else:
                        # 异步客户端的工具信息是对象
                        tools = [
                            {
                                "type": "function",
                                "function": {
                                    "name": tool_name,
                                    "description": tool.description
                                    if hasattr(tool, "description")
                                    else "",
                                    "parameters": tool.inputSchema
                                    if hasattr(tool, "inputSchema")
                                    else {},
                                },
                            }
                            for tool_name, tool in mcp_client.available_tools.items()
                        ]
                else:
                    # 如果没有指定，使用所有服务器的所有工具
                    tools = await self.get_all_tools()

            # 构建API请求参数
            params = {
                "model": model,
                "messages": messages,
                "stream": True,
                "temperature": temperature or settings.DEEPSEEK_DEFAULT_TEMPERATURE,
            }

            # 如果有工具，添加到请求参数
            if tools:
                params["tools"] = tools

            # 调用API
            logger.info(f"开始调用 {model} 模型生成聊天完成")
            response = await self.client.chat.completions.create(**params)

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

                # 提取有效内容
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
                    # 确保reasoning_content字段存在于chunk_dict中
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
                    yield chunk_dict
                    continue

                # 处理工具调用
                if (
                    hasattr(chunk.choices[0].delta, "tool_calls")
                    and chunk.choices[0].delta.tool_calls
                ):
                    for tool_call in chunk.choices[0].delta.tool_calls:
                        # 查找或创建工具调用
                        if tool_call.index >= len(tool_calls):
                            # 新的工具调用
                            new_tool_call = {
                                "id": tool_call.id
                                if hasattr(tool_call, "id") and tool_call.id
                                else "",
                                "type": "function",
                                "function": {"name": "", "arguments": ""},
                            }
                            tool_calls.append(new_tool_call)
                            logger.info(f"模型开始新的工具调用 #{tool_call.index + 1}")

                        # 更新工具调用信息
                        if (
                            hasattr(tool_call.function, "name")
                            and tool_call.function.name
                        ):
                            tool_calls[tool_call.index]["function"]["name"] = (
                                tool_call.function.name
                            )
                            logger.info(
                                f"工具调用 #{tool_call.index + 1} 使用工具: {tool_call.function.name}"
                            )

                        if (
                            hasattr(tool_call.function, "arguments")
                            and tool_call.function.arguments
                        ):
                            tool_calls[tool_call.index]["function"]["arguments"] += (
                                tool_call.function.arguments
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
                        logger.info(f"模型完成了 {len(tool_calls)} 个工具调用")

                        # 处理工具调用
                        for tool_call in tool_calls:
                            try:
                                tool_name = tool_call["function"]["name"]
                                arguments_json = tool_call["function"]["arguments"]

                                # 解析参数
                                try:
                                    arguments = json.loads(arguments_json)
                                except json.JSONDecodeError:
                                    logger.error(f"无法解析工具参数: {arguments_json}")
                                    continue

                                # 获取对应的MCP客户端
                                try:
                                    active_mcp_client = await self.get_client_for_tool(
                                        tool_name
                                    )
                                except ValueError as e:
                                    logger.error(
                                        f"找不到工具 '{tool_name}' 对应的服务器: {str(e)}"
                                    )
                                    continue

                                # 调用工具
                                try:
                                    result = await active_mcp_client.call_tool(
                                        tool_name, arguments
                                    )
                                    logger.info(f"工具 {tool_name} 返回结果: {result}")
                                except Exception as tool_error:
                                    logger.error(
                                        f"调用工具 '{tool_name}' 时出错: {str(tool_error)}"
                                    )
                                    # 将错误信息作为工具调用结果返回
                                    result = f"Error: {str(tool_error)}"

                                # 发送工具调用结果消息
                                result_chunk = {
                                    "choices": [{"delta": {}, "finish_reason": None}],
                                    "tool_call_result": True,
                                    "complete_tool_calls": [tool_call],
                                    "tool_result": str(result),
                                }
                                yield result_chunk

                                # 将工具结果添加到消息
                                messages.append(
                                    {
                                        "role": "assistant",
                                        "content": content_buffer,
                                        "tool_calls": [tool_call],
                                    }
                                )

                                messages.append(
                                    {
                                        "role": "tool",
                                        "tool_call_id": tool_call["id"],
                                        "content": str(result),
                                    }
                                )

                            except Exception as e:
                                logger.error(f"处理工具调用时出错: {str(e)}")
                                # 添加错误消息
                                yield {
                                    "choices": [
                                        {
                                            "delta": {
                                                "content": f"\n\n工具调用出错: {str(e)}"
                                            },
                                            "finish_reason": None,
                                        }
                                    ]
                                }

                        # 使用更新后的消息生成新的完成
                        logger.info("使用工具调用结果继续对话")
                        try:
                            async for new_chunk in self.generate_chat_completion(
                                messages=messages,
                                model=model,
                                temperature=temperature,
                                use_mcp=False,  # 避免无限递归
                            ):
                                yield new_chunk
                        except Exception as recursive_error:
                            logger.error(
                                f"递归调用chat completion时出错: {str(recursive_error)}"
                            )
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

        except Exception as e:
            logger.error(f"调用DeepSeek API错误: {str(e)}")
            raise

    async def cleanup(self):
        """清理资源"""
        try:
            # 清理所有MCP客户端
            clients_count = len(self.mcp_clients)
            if clients_count == 0:
                logger.debug("没有MCP客户端需要清理")
                return

            logger.debug(f"开始清理所有MCP客户端，共 {clients_count} 个")

            # 创建一份客户端字典的副本再迭代，避免在迭代过程中修改字典
            clients_to_cleanup = dict(self.mcp_clients)
            self.mcp_clients = {}  # 先清空字典，避免重复清理
            self.tool_to_server_map = {}  # 清空工具映射

            # 对每个客户端进行清理
            for server_name, client in clients_to_cleanup.items():
                if not client:
                    continue

                try:
                    logger.debug(f"开始清理MCP客户端: {server_name}")
                    # 使用超时保护，防止清理过程卡住
                    try:
                        # 根据客户端类型调用不同的断开连接方法
                        if isinstance(client, MultiprocessMCPClientService):
                            logger.debug(f"清理多进程MCP客户端: {server_name}")
                            await client.disconnect()
                            logger.info(f"已清理多进程MCP客户端: {server_name}")
                        else:
                            # 异步客户端
                            logger.debug(f"清理异步MCP客户端: {server_name}")
                            await asyncio.wait_for(client.disconnect(), timeout=5.0)
                            logger.info(f"已清理异步MCP客户端: {server_name}")
                    except asyncio.TimeoutError:
                        logger.warning(f"清理MCP客户端'{server_name}'超时")
                    except Exception as e:
                        # 捕获并记录取消作用域错误，但不中断清理流程
                        if "cancel scope" in str(e):
                            logger.warning(
                                f"清理MCP客户端'{server_name}'时遇到cancel scope错误，已忽略: {str(e)}"
                            )
                        else:
                            raise
                except Exception as e:
                    logger.error(f"清理MCP客户端 '{server_name}' 时出错: {str(e)}")
                    logger.debug(f"错误详情: {type(e).__name__}", exc_info=True)

            logger.debug("MCP客户端资源清理完成")
        except Exception as e:
            logger.error(f"清理MCP客户端资源时出错: {str(e)}")
            logger.debug(f"错误详情: {type(e).__name__}", exc_info=True)
            # 确保字典被清空
            self.mcp_clients = {}
            self.tool_to_server_map = {}
