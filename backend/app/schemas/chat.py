from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from app.core.config import settings


class ChatMessage(BaseModel):
    """单个聊天消息模型"""

    role: str
    content: str


class MCPServerConfig(BaseModel):
    """单个MCP服务器配置"""

    url: str = Field(..., description="SSE服务器URL")
    env: Optional[Dict[str, str]] = Field(
        default_factory=dict, description="环境变量，如API密钥等"
    )


# 定义用户自定义MCP配置类型，是一个字典，键为服务器名称，值为服务器配置
UserMCPConfig = Dict[str, Dict[str, Any]]
"""用户自定义MCP服务器配置字典

键为服务器名称，值为服务器配置
例如：{"math-tools": {"url": "http://localhost:8001/sse", "env": {}}}
"""


class ChatRequest(BaseModel):
    """聊天请求模型"""

    current_message: ChatMessage
    context_messages: List[ChatMessage] = Field(default_factory=list)
    model: str
    use_deep_thinking: bool = False
    use_mcp: bool = False  # 全局控制是否启用MCP工具功能
    use_base_tools: bool = False  # 是否使用基本MCP工具
    user_mcp_config: Optional[UserMCPConfig] = None  # 用户自定义MCP服务器配置
    temperature: Optional[float] = Field(
        default=None, description="模型温度参数，控制输出的随机性"
    )
    mcp_server_name: Optional[str] = Field(
        default=None, description="指定使用的MCP服务器名称"
    )
    context_length: int = Field(
        default=settings.DEFAULT_CONTEXT_LENGTH,
        description="上下文长度，控制发送API时只使用最后N条消息作为上下文",
    )
