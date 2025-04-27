"""
MCP工具调用的请求和响应数据模型
"""

from typing import Dict, Any


class MCPToolRequest:
    """MCP工具调用请求"""

    def __init__(self, tool_name: str, arguments: Dict[str, Any]):
        self.tool_name = tool_name
        self.arguments = arguments
        self.is_list_tools_request = False  # 标记是否为获取工具列表的请求


class MCPListToolsRequest:
    """MCP获取工具列表请求"""

    def __init__(self):
        self.is_list_tools_request = True


class MCPToolResponse:
    """MCP工具调用响应"""

    def __init__(
        self, result: str = None, error: str = None, tools: Dict[str, Any] = None
    ):
        self.result = result
        self.error = error
        self.tools = tools  # 工具列表
