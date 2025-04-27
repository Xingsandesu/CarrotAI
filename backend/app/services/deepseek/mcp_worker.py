"""
MCP工作进程模块，处理MCP客户端连接和工具调用
"""

import os
import logging
import asyncio
import queue
from typing import Dict, Any
from multiprocessing import Queue

from .mcp_models import MCPToolResponse


def mcp_worker_process(
    url: str,
    env: Dict[str, str],
    request_queue: Queue,
    response_queue: Queue,
    shutdown_event,
):
    """MCP工作进程，处理工具调用请求"""
    from mcp import ClientSession
    from mcp.client.sse import sse_client
    from contextlib import AsyncExitStack

    # 配置日志
    logger = logging.getLogger(f"mcp_worker_{os.getpid()}")
    logger.setLevel(logging.INFO)

    # 创建事件循环
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    # 会话和工具信息
    session = None
    available_tools = {}
    exit_stack = AsyncExitStack()

    # 获取请求头
    def get_headers():
        headers = {}
        for key, value in env.items():
            headers[key] = value
        return headers

    # 连接到MCP服务器
    async def connect():
        nonlocal session, available_tools, exit_stack

        try:
            logger.info(f"进程 {os.getpid()} 连接到SSE endpoint: {url}")

            # 使用SSE客户端连接到服务器
            streams_context = sse_client(url=url, headers=get_headers())
            streams = await exit_stack.enter_async_context(streams_context)

            # 创建会话
            session_context = ClientSession(*streams)
            session = await exit_stack.enter_async_context(session_context)

            # 初始化会话
            await session.initialize()

            # 获取可用工具
            response = await session.list_tools()
            available_tools = {tool.name: tool for tool in response.tools}

            logger.info(f"进程 {os.getpid()} 已连接到SSE MCP服务器: {url}")
            logger.info(f"可用工具: {list(available_tools.keys())}")

            return True
        except Exception as e:
            logger.error(f"进程 {os.getpid()} 连接到SSE MCP服务器时出错: {str(e)}")
            return False

    # 调用工具
    async def call_tool(tool_name: str, arguments: Dict[str, Any]):
        if not session:
            return MCPToolResponse(error="MCP会话未初始化")

        if tool_name not in available_tools:
            return MCPToolResponse(error=f"工具 '{tool_name}' 不可用")

        try:
            logger.info(f"进程 {os.getpid()} 正在调用MCP工具: {tool_name}")
            result = await session.call_tool(tool_name, arguments)
            logger.info(f"进程 {os.getpid()} 工具 '{tool_name}' 调用完成")
            return MCPToolResponse(result=result.content)
        except Exception as e:
            logger.error(f"进程 {os.getpid()} 调用工具 '{tool_name}' 时出错: {str(e)}")
            return MCPToolResponse(error=str(e))

    # 清理资源
    async def cleanup():
        nonlocal session, exit_stack

        try:
            if exit_stack:
                logger.info(f"进程 {os.getpid()} 正在清理资源")
                await exit_stack.aclose()
                logger.info(f"进程 {os.getpid()} 资源清理完成")
        except Exception as e:
            logger.error(f"进程 {os.getpid()} 清理资源时出错: {str(e)}")

    # 主处理循环
    async def main_loop():
        # 连接到MCP服务器
        if not await connect():
            response_queue.put(MCPToolResponse(error="无法连接到MCP服务器"))
            return

        try:
            while not shutdown_event.is_set():
                try:
                    # 非阻塞方式获取请求，超时后检查shutdown_event
                    request = request_queue.get(block=True, timeout=0.5)

                    # 处理请求
                    if request == "SHUTDOWN":
                        logger.info(f"进程 {os.getpid()} 收到关闭命令")
                        break

                    # 处理获取工具列表请求
                    if (
                        hasattr(request, "is_list_tools_request")
                        and request.is_list_tools_request
                    ):
                        logger.info(f"进程 {os.getpid()} 收到获取工具列表请求")
                        # 将工具列表转换为可序列化的字典
                        tools_dict = {}
                        for name, tool in available_tools.items():
                            # 提取工具的关键属性
                            tool_info = {
                                "name": name,
                                "description": tool.description
                                if hasattr(tool, "description")
                                else "",
                                "inputSchema": tool.inputSchema
                                if hasattr(tool, "inputSchema")
                                else {},
                            }
                            tools_dict[name] = tool_info

                        # 返回工具列表
                        response = MCPToolResponse(tools=tools_dict)
                        response_queue.put(response)
                        continue

                    # 调用工具并返回结果
                    response = await call_tool(request.tool_name, request.arguments)
                    response_queue.put(response)

                except queue.Empty:
                    # 队列为空，继续循环
                    continue
                except Exception as e:
                    logger.error(f"进程 {os.getpid()} 处理请求时出错: {str(e)}")
                    response_queue.put(
                        MCPToolResponse(error=f"处理请求时出错: {str(e)}")
                    )
        finally:
            # 清理资源
            await cleanup()
            logger.info(f"进程 {os.getpid()} 已退出")

    # 运行主循环
    try:
        loop.run_until_complete(main_loop())
    except Exception as e:
        logger.error(f"进程 {os.getpid()} 主循环出错: {str(e)}")
    finally:
        loop.close()
