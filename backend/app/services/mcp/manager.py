"""
MCP管理器模块，负责初始化和管理MCP客户端
"""

import logging
from typing import Dict, Any, Optional, List

from app.core.config import settings
from app.services.mcp import MCPServiceManager
from app.services.mcp.models import MCPTransportType
from app.schemas.chat import UserMCPConfig

logger = logging.getLogger(__name__)


class MCPManager:
    """MCP管理器，负责初始化和管理MCP客户端"""

    def __init__(self):
        """初始化MCP服务管理器"""
        self.mcp_service = MCPServiceManager()
        self.clients = {}

    async def initialize_all_clients(self) -> Dict[str, Any]:
        """
        初始化所有配置中的MCP客户端

        Returns:
            初始化的MCP客户端字典
        """
        configs = {}
        for server_name, server_config in settings.MCP_SERVERS.items():
            configs[server_name] = {
                "url": server_config.get("url"),
                "env": server_config.get("env", {}),
                "transportType": server_config.get("transport_type", MCPTransportType.SSE)
            }
        
        return await self.mcp_service.initialize_from_configs(configs)

    async def initialize_user_client(self, config: UserMCPConfig) -> Any:
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
        configs = {}
        for server_name, server_config in config.items():
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
            
            # 获取传输类型
            transport_type = server_config.get("transportType", MCPTransportType.SSE)
            
            # 添加到配置字典
            configs[server_name] = {
                "url": server_config.get("url"),
                "env": env,
                "transportType": transport_type
            }
        
        # 初始化客户端
        initialized_clients = await self.mcp_service.initialize_from_configs(configs)
        
        # 返回第一个初始化成功的客户端（如果有）
        if initialized_clients:
            first_server = next(iter(initialized_clients.keys()))
            return initialized_clients[first_server]
        else:
            raise ValueError("没有成功初始化的MCP客户端")

    async def initialize_server_client(self, server_name: str) -> Any:
        """
        初始化指定服务器的MCP客户端

        Args:
            server_name: 服务器名称

        Returns:
            初始化后的MCP客户端
        """
        if server_name not in settings.MCP_SERVERS:
            raise ValueError(f"未找到服务器名称: {server_name}")
            
        server_config = settings.MCP_SERVERS[server_name]
        return await self.mcp_service.initialize_mcp_client(
            server_name=server_name,
            url=server_config.get("url"),
            transport_type=server_config.get("transport_type", MCPTransportType.SSE),
            env=server_config.get("env", {})
        )

    async def get_active_client(
        self, server_name: str = None, user_mcp_config: Optional[UserMCPConfig] = None
    ) -> Any:
        """
        获取活动的MCP客户端，根据优先级：
        1. 用户配置的自定义客户端
        2. 指定名称的服务器客户端
        3. 默认的第一个服务器客户端

        Args:
            server_name: 服务器名称
            user_mcp_config: 用户自定义MCP配置

        Returns:
            活动的MCP客户端
        """
        # 优先使用用户自定义配置
        if user_mcp_config:
            try:
                return await self.initialize_user_client(user_mcp_config)
            except Exception as e:
                logger.error(f"初始化用户自定义MCP客户端失败: {str(e)}")
                # 如果用户配置初始化失败，继续尝试其他方法

        # 使用指定服务器名称
        if server_name and server_name in settings.MCP_SERVERS:
            try:
                return await self.initialize_server_client(server_name)
            except Exception as e:
                logger.error(f"初始化指定服务器MCP客户端失败: {str(e)}")
                # 继续尝试默认服务器

        # 使用默认服务器
        if settings.MCP_SERVERS:
            default_server = next(iter(settings.MCP_SERVERS.keys()))
            server_config = settings.MCP_SERVERS[default_server]
            return await self.mcp_service.initialize_mcp_client(
                server_name=default_server,
                url=server_config.get("url"),
                transport_type=server_config.get("transport_type", MCPTransportType.SSE),
                env=server_config.get("env", {})
            )
        else:
            raise ValueError("没有可用的MCP服务器")

    async def get_all_tools(self) -> List[Dict[str, Any]]:
        """
        获取所有服务器的所有工具

        Returns:
            所有工具的列表
        """
        return await self.mcp_service.get_all_tools()
        
    async def cleanup(self) -> None:
        """清理所有资源"""
        await self.mcp_service.cleanup() 