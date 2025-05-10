"""
MCP客户端服务模块，提供与MCP服务器的连接和工具调用功能
支持SSE和Streamable HTTP传输
"""

import json
import logging
import asyncio
import time
import queue
from typing import Dict, Any, Optional
from multiprocessing import Process, Queue, Manager

from .models import MCPToolRequest, MCPListToolsRequest, MCPToolResponse, MCPTransportType
from .worker import mcp_worker_process

logger = logging.getLogger(__name__)


class MultiprocessMCPClientService:
    """基于多进程的MCP客户端服务，为每个MCP服务器创建一个专用进程"""

    def __init__(
        self, 
        url: str, 
        transport_type: str = MCPTransportType.SSE, 
        env: Optional[Dict[str, str]] = None
    ):
        """
        初始化多进程MCP客户端服务

        Args:
            url: MCP服务器URL
            transport_type: 传输类型，可以是"sse"或"streamable_http"
            env: 环境变量，如API密钥等
        """
        self.url = url
        self.transport_type = transport_type
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
                    self.transport_type,
                ),
            )
            self.process.daemon = True  # 设置为守护进程，主进程退出时自动终止
            self.process.start()

            logger.info(f"已启动MCP工作进程 PID: {self.process.pid} 连接到 {self.url} 使用 {self.transport_type}")

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

            # 清理任何现有的响应
            self._clear_response_queue()

            # 发送工具调用请求
            self.request_queue.put(MCPToolRequest(tool_name=tool_name, arguments=arguments))

            # 等待响应，使用较长的超时时间
            response = await self._wait_for_response(timeout=60.0)

            # 如果没有获取到响应或有错误
            if not response:
                raise Exception("工具调用超时或未收到响应")

            if response.error:
                raise Exception(f"工具调用出错: {response.error}")

            return response.result or ""

        except ValueError as e:
            # 重新抛出ValueError
            raise e
        except Exception as e:
            logger.error(f"调用工具 '{tool_name}' 时出错: {str(e)}")
            raise Exception(f"调用工具 '{tool_name}' 时出错: {str(e)}")

    async def disconnect(self) -> None:
        """关闭连接并清理资源"""
        try:
            logger.info("正在关闭MCP连接")

            # 发送关闭信号
            if self.request_queue:
                try:
                    self.request_queue.put("SHUTDOWN", block=False)
                except Exception:  # 修复裸异常
                    pass

            # 设置关闭事件
            if self.shutdown_event:
                self.shutdown_event.set()

            # 等待进程自行终止
            if self.process and self.process.is_alive():
                logger.info(f"等待MCP工作进程 {self.process.pid} 终止")
                self.process.join(timeout=2.0)

                # 如果进程仍在运行，强制终止
                if self.process.is_alive():
                    logger.warning(f"强制终止MCP工作进程 {self.process.pid}")
                    self.process.terminate()
                    self.process.join(timeout=1.0)

            # 清理队列和共享对象
            self.request_queue = None
            self.response_queue = None
            self.shutdown_event = None
            self.process = None

            # 关闭manager
            if self.manager:
                self.manager.shutdown()
                self.manager = None

            # 清空工具列表
            self.available_tools = {}

            logger.info("MCP连接已关闭")

        except Exception as e:
            logger.error(f"关闭MCP连接时出错: {str(e)}")
            # 尝试强制清理，即使出错
            self.request_queue = None
            self.response_queue = None
            self.shutdown_event = None
            self.process = None
            self.manager = None
            self.available_tools = {} 