"""
MCP客户端服务模块，提供与MCP服务器的连接和工具调用功能
"""

import json
import logging
import asyncio
import time
import os
import signal
import traceback
import queue
from typing import Dict, Any, Optional
from multiprocessing import Process, Queue, Manager

from .mcp_models import MCPToolRequest, MCPListToolsRequest, MCPToolResponse
from .mcp_worker import mcp_worker_process

logger = logging.getLogger(__name__)


class MultiprocessMCPClientService:
    """基于多进程的MCP客户端服务，为每个MCP服务器创建一个专用进程"""

    def __init__(self, url: str, env: Optional[Dict[str, str]] = None):
        """
        初始化多进程MCP客户端服务

        Args:
            url: SSE服务器URL
            env: 环境变量，如API密钥等
        """
        self.url = url
        self.env = env or {}
        self.available_tools = {}
        self.process = None
        self.request_queue = None
        self.response_queue = None
        self.shutdown_event = None
        self.manager = None

    async def connect(self) -> bool:
        """
        启动工作进程并连接到MCP服务器

        Returns:
            连接是否成功
        """
        # 如果已经有进程在运行，先清理
        if self.process and self.process.is_alive():
            await self.disconnect()

        try:
            # 创建进程间通信所需的队列和事件
            self.manager = Manager()
            self.request_queue = Queue()
            self.response_queue = Queue()
            self.shutdown_event = self.manager.Event()

            # 启动工作进程
            self.process = Process(
                target=mcp_worker_process,
                args=(
                    self.url,
                    self.env,
                    self.request_queue,
                    self.response_queue,
                    self.shutdown_event,
                ),
            )
            self.process.daemon = True  # 设置为守护进程，主进程退出时自动终止
            self.process.start()

            logger.info(f"已启动MCP工作进程 PID: {self.process.pid} 连接到 {self.url}")

            # 等待工作进程连接成功或返回错误
            # 使用异步方式轮询队列
            start_time = time.time()
            timeout = 15.0  # 15秒超时

            while time.time() - start_time < timeout:
                try:
                    # 非阻塞检查响应队列
                    if not self.response_queue.empty():
                        response = self.response_queue.get_nowait()
                        if response.error:
                            logger.error(f"MCP工作进程连接失败: {response.error}")
                            await self.disconnect()
                            return False

                    # 检查进程是否还活着
                    if not self.process.is_alive():
                        logger.error("MCP工作进程意外终止")
                        await self.disconnect()
                        return False

                    # 获取可用工具列表
                    await self.update_available_tools()
                    if self.available_tools:
                        logger.info(
                            f"MCP工作进程连接成功，可用工具: {list(self.available_tools.keys())}"
                        )
                        return True

                    # 短暂等待后继续检查
                    await asyncio.sleep(0.1)

                except Exception as e:
                    logger.error(f"检查MCP工作进程状态时出错: {str(e)}")
                    await self.disconnect()
                    return False

            # 超时处理
            logger.error("等待MCP工作进程连接超时")
            await self.disconnect()
            return False

        except Exception as e:
            logger.error(f"启动MCP工作进程时出错: {str(e)}")
            await self.disconnect()
            return False

    async def update_available_tools(self) -> Dict[str, Any]:
        """
        获取可用工具列表

        Returns:
            可用工具的字典
        """
        # 如果工具列表已经存在且进程仍在运行，直接返回
        if self.available_tools and self.process and self.process.is_alive():
            return self.available_tools

        # 如果进程未运行，返回空字典
        if not self.process or not self.process.is_alive():
            self.available_tools = {}
            return self.available_tools

        try:
            # 清理任何现有的响应
            self._clear_response_queue()

            # 发送获取工具列表的请求
            logger.debug(f"发送获取工具列表请求到进程 {self.process.pid}")
            self.request_queue.put(MCPListToolsRequest())

            # 等待响应，使用更短的超时时间
            response = await self._wait_for_response(timeout=3.0)

            # 如果有响应且包含工具列表
            if response and response.tools:
                logger.info(f"成功获取工具列表: {list(response.tools.keys())}")
                self.available_tools = response.tools
                return self.available_tools

            # 如果没有获取到工具列表，但进程仍在运行，使用空字典
            logger.warning("未能获取工具列表，使用空字典")
            self.available_tools = {}
            return self.available_tools

        except Exception as e:
            logger.error(f"更新可用工具列表时出错: {str(e)}")
            self.available_tools = {}
            return {}

    def _clear_response_queue(self):
        """清空响应队列"""
        try:
            while not self.response_queue.empty():
                try:
                    self.response_queue.get_nowait()
                except queue.Empty:
                    break
        except Exception as e:
            logger.error(f"清空响应队列时出错: {str(e)}")

    async def _wait_for_response(
        self, timeout: float = 5.0
    ) -> Optional[MCPToolResponse]:
        """
        等待响应

        Args:
            timeout: 超时时间（秒）

        Returns:
            响应或None（如果超时或出错）
        """
        start_time = time.time()

        while time.time() - start_time < timeout:
            # 检查进程是否还活着
            if not self.process.is_alive():
                logger.error("MCP工作进程已终止")
                return None

            # 检查是否有响应
            if not self.response_queue.empty():
                try:
                    response = self.response_queue.get()

                    # 检查是否有错误
                    if response.error:
                        logger.error(f"获取响应时出错: {response.error}")
                        return None

                    return response
                except Exception as e:
                    logger.error(f"获取响应时出错: {str(e)}")
                    return None

            # 短暂等待后继续检查
            await asyncio.sleep(0.1)

        # 超时处理
        logger.error(f"等待响应超时 ({timeout}秒)")
        return None

    async def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """
        调用MCP工具

        Args:
            tool_name: 工具名称
            arguments: 工具参数

        Returns:
            工具执行结果

        Raises:
            ValueError: 当MCP会话未初始化或工具不可用时
            Exception: 调用工具过程中的其他错误
        """
        # 验证工具调用的有效性
        if not self.process or not self.process.is_alive():
            raise ValueError("MCP工作进程未运行")

        if tool_name not in self.available_tools:
            raise ValueError(f"工具 '{tool_name}' 不可用")

        try:
            # 记录工具调用信息
            logger.info(f"正在调用MCP工具: {tool_name}")
            logger.info(
                f"工具描述: {self.available_tools[tool_name].get('description', '无描述')}"
            )
            logger.info(
                f"输入参数: {json.dumps(arguments, ensure_ascii=False, indent=2)}"
            )

            # 创建工具调用请求
            request = MCPToolRequest(tool_name, arguments)

            # 发送请求到工作进程
            self.request_queue.put(request)

            # 等待响应
            start_time = time.time()
            timeout = 60.0  # 60秒超时

            while time.time() - start_time < timeout:
                # 检查进程是否还活着
                if not self.process.is_alive():
                    raise ValueError("MCP工作进程已终止")

                # 检查是否有响应
                if not self.response_queue.empty():
                    response = self.response_queue.get()

                    # 检查是否有错误
                    if response.error:
                        raise ValueError(f"工具调用出错: {response.error}")

                    # 记录结果
                    duration = time.time() - start_time
                    logger.info(f"工具 '{tool_name}' 调用完成，耗时: {duration:.2f}秒")
                    logger.info(f"工具调用结果: {response.result}")

                    return response.result

                # 短暂等待后继续检查
                await asyncio.sleep(0.1)

            # 超时处理
            raise TimeoutError(f"调用工具 '{tool_name}' 超时")

        except Exception as e:
            logger.error(f"调用工具 '{tool_name}' 时出错: {str(e)}")
            # 记录详细错误信息
            logger.error(f"错误详情: {traceback.format_exc()}")
            raise

    async def disconnect(self) -> None:
        """
        断开与MCP服务器的连接并清理资源
        """
        try:
            logger.debug(f"准备断开与MCP服务器的连接并清理资源: {self.url}")

            # 发送关闭命令到工作进程
            if self.request_queue and self.process and self.process.is_alive():
                try:
                    self.request_queue.put("SHUTDOWN")
                    logger.debug("已发送关闭命令到工作进程")
                except Exception as e:
                    logger.error(f"发送关闭命令时出错: {str(e)}")

            # 设置关闭事件
            if self.shutdown_event:
                try:
                    self.shutdown_event.set()
                    logger.debug("已设置关闭事件")
                except Exception as e:
                    logger.error(f"设置关闭事件时出错: {str(e)}")

            # 等待进程终止
            if self.process and self.process.is_alive():
                try:
                    # 给进程一些时间来清理资源
                    logger.debug("等待工作进程终止...")
                    self.process.join(timeout=3.0)

                    # 如果进程仍在运行，强制终止
                    if self.process.is_alive():
                        logger.warning("工作进程未能正常终止，强制终止")
                        self.process.terminate()
                        self.process.join(timeout=1.0)

                        # 如果仍然无法终止，使用更强力的方法
                        if self.process.is_alive():
                            logger.warning("工作进程仍在运行，使用SIGKILL信号")
                            try:
                                os.kill(self.process.pid, signal.SIGKILL)
                            except Exception as e:
                                logger.error(f"发送SIGKILL信号时出错: {str(e)}")
                except Exception as e:
                    logger.error(f"等待进程终止时出错: {str(e)}")

            # 清理队列
            if self.request_queue:
                try:
                    # 清空请求队列
                    while not self.request_queue.empty():
                        try:
                            self.request_queue.get_nowait()
                        except queue.Empty:
                            pass
                except Exception as e:
                    logger.error(f"清理请求队列时出错: {str(e)}")

            if self.response_queue:
                try:
                    # 清空响应队列
                    while not self.response_queue.empty():
                        try:
                            self.response_queue.get_nowait()
                        except queue.Empty:
                            pass
                except Exception as e:
                    logger.error(f"清理响应队列时出错: {str(e)}")

            # 关闭Manager
            if self.manager:
                try:
                    self.manager.shutdown()
                    logger.debug("已关闭Manager")
                except Exception as e:
                    logger.error(f"关闭Manager时出错: {str(e)}")

            # 清空引用
            self.process = None
            self.request_queue = None
            self.response_queue = None
            self.shutdown_event = None
            self.manager = None
            self.available_tools = {}

            logger.info("已断开与MCP服务器的连接并清理资源")
        except Exception as e:
            logger.error(f"断开MCP服务器连接时出错: {str(e)}")
            logger.debug(f"错误详情: {type(e).__name__}", exc_info=True)
