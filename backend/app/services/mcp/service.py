"""
MCP服务管理模块，提供统一的MCP客户端管理和工具调用功能
"""

import json
import logging
import asyncio
from typing import Dict, Any, Optional, List

from .client import MultiprocessMCPClientService
from .models import MCPTransportType

logger = logging.getLogger(__name__)


class MCPServiceManager:
    """
    MCP服务管理类，负责管理多个MCP客户端并提供统一的接口
    """

    def __init__(self):
        """初始化MCP服务管理器"""
        self.mcp_clients = {}  # 存储多个MCP客户端的字典，键为服务器名称
        self.tool_to_server_map = {}  # 工具名称到服务器名称的映射

    async def initialize_mcp_client(
        self, 
        server_name: str,
        url: str,
        transport_type: str = MCPTransportType.SSE,
        env: Optional[Dict[str, str]] = None
    ):
        """
        初始化MCP客户端

        Args:
            server_name: MCP服务器名称
            url: MCP服务器URL
            transport_type: 传输类型，可以是"sse"或"streamable_http"
            env: 环境变量，包含认证信息等

        Returns:
            初始化后的MCP客户端
        """
        # 如果已经初始化过该服务器的客户端，直接返回
        if server_name in self.mcp_clients and self.mcp_clients[server_name]:
            return self.mcp_clients[server_name]

        # 初始化MCP客户端
        logger.info(f"初始化MCP客户端: {server_name}，使用传输类型: {transport_type}，URL: {url}")
        
        try:
            # 创建新的MCP客户端
            mcp_client = MultiprocessMCPClientService(
                url=url, 
                transport_type=transport_type, 
                env=env or {}
            )
            
            # 连接到服务器
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
            
        except Exception as e:
            logger.error(f"初始化MCP客户端时出错: {str(e)}")
            raise

    async def initialize_from_config(self, config: Dict[str, Any]):
        """
        从配置初始化MCP客户端

        Args:
            config: MCP服务器配置，格式为：
                   {
                     "url": "http://...",
                     "env": {"API_KEY": "..."},
                     "transportType": "sse"
                   }

        Returns:
            初始化后的MCP客户端
        """
        if not config:
            raise ValueError("MCP配置为空")
        
        url = config.get("url")
        if not url:
            raise ValueError("MCP配置中未指定URL")
        
        # 获取传输类型，默认为SSE
        transport_type = config.get("transportType", MCPTransportType.SSE)
        
        # 获取环境变量
        env = config.get("env", {})
        
        # 生成唯一服务器名称
        server_name = f"config_client_{len(self.mcp_clients) + 1}"
        
        # 初始化客户端
        return await self.initialize_mcp_client(
            server_name=server_name,
            url=url,
            transport_type=transport_type,
            env=env
        )

    async def initialize_from_configs(self, configs: Dict[str, Dict[str, Any]]):
        """
        从多个配置初始化MCP客户端

        Args:
            configs: 服务器名称到配置的映射，格式为：
                    {
                      "server1": {"url": "...", "env": {...}, "transportType": "..."},
                      "server2": {"url": "...", "env": {...}, "transportType": "..."}
                    }

        Returns:
            初始化的MCP客户端字典
        """
        initialized_clients = {}
        
        for server_name, config in configs.items():
            try:
                client = await self.initialize_mcp_client(
                    server_name=server_name,
                    url=config.get("url"),
                    transport_type=config.get("transportType", MCPTransportType.SSE),
                    env=config.get("env", {})
                )
                initialized_clients[server_name] = client
            except Exception as e:
                logger.error(f"初始化MCP客户端 '{server_name}' 时出错: {str(e)}")
                # 继续初始化其他客户端
        
        return initialized_clients

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
            所有工具的列表，格式符合OpenAI API工具格式
        """
        all_tools = []
        # 从所有客户端收集工具
        for client_name, client in self.mcp_clients.items():
            logger.debug(f"从客户端 {client_name} 获取工具列表")

            # 确保工具列表是最新的
            await client.update_available_tools()

            for tool_name, tool_info in client.available_tools.items():
                # 处理不同类型客户端的工具信息格式
                tool_function = {
                    "name": tool_name,
                    "description": tool_info.get("description", ""),
                    "parameters": tool_info.get("inputSchema", {}),
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
        try:
            # 获取对应的MCP客户端
            mcp_client = await self.get_client_for_tool(tool_name)
            
            # 调用工具
            result = await mcp_client.call_tool(tool_name, arguments)
            logger.info(f"工具 {tool_name} 返回结果: {result}")
            return result
        except Exception as e:
            logger.error(f"调用工具 '{tool_name}' 时出错: {str(e)}")
            raise

    async def cleanup(self):
        """清理所有MCP客户端资源"""
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
                        await asyncio.wait_for(client.disconnect(), timeout=5.0)
                        logger.info(f"已清理MCP客户端: {server_name}")
                    except asyncio.TimeoutError:
                        logger.warning(f"清理MCP客户端'{server_name}'超时")
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