"""
工具处理模块，负责处理MCP工具调用
"""

import json
import logging
from typing import List, Dict, Any, Tuple

logger = logging.getLogger(__name__)


class ToolHandler:
    """工具处理器，负责处理工具调用"""

    def __init__(self, mcp_service):
        """
        初始化工具处理器
        
        Args:
            mcp_service: MCP服务实例
        """
        self.mcp_service = mcp_service

    async def update_tool_calls(
        self, chunk, existing_tool_calls: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        更新工具调用信息
        
        Args:
            chunk: 响应块
            existing_tool_calls: 现有的工具调用列表
            
        Returns:
            更新后的工具调用列表
        """
        if not hasattr(chunk.choices[0].delta, "tool_calls"):
            return existing_tool_calls
            
        updated_tool_calls = existing_tool_calls.copy()
        
        for tool_call in chunk.choices[0].delta.tool_calls:
            # 查找或创建工具调用
            if tool_call.index >= len(updated_tool_calls):
                # 新的工具调用
                new_tool_call = {
                    "id": tool_call.id
                    if hasattr(tool_call, "id") and tool_call.id
                    else "",
                    "type": "function",
                    "function": {"name": "", "arguments": ""},
                }
                updated_tool_calls.append(new_tool_call)
                logger.info(f"模型开始新的工具调用 #{tool_call.index + 1}")

            # 更新工具调用信息
            if (
                hasattr(tool_call.function, "name")
                and tool_call.function.name
            ):
                updated_tool_calls[tool_call.index]["function"]["name"] = (
                    tool_call.function.name
                )
                logger.info(
                    f"工具调用 #{tool_call.index + 1} 使用工具: {tool_call.function.name}"
                )

            if (
                hasattr(tool_call.function, "arguments")
                and tool_call.function.arguments
            ):
                updated_tool_calls[tool_call.index]["function"]["arguments"] += (
                    tool_call.function.arguments
                )
                
        return updated_tool_calls

    async def process_tool_calls(
        self, tool_calls: List[Dict[str, Any]]
    ) -> List[Tuple[Dict[str, Any], str]]:
        """
        处理工具调用并获取结果
        
        Args:
            tool_calls: 工具调用列表
            
        Returns:
            工具调用和结果的元组列表
        """
        logger.info(f"处理 {len(tool_calls)} 个工具调用")
        results = []
        
        for tool_call in tool_calls:
            try:
                tool_name = tool_call["function"]["name"]
                arguments_json = tool_call["function"]["arguments"]

                # 解析参数
                try:
                    arguments = json.loads(arguments_json)
                except json.JSONDecodeError:
                    logger.error(f"无法解析工具参数: {arguments_json}")
                    result = f"Error: 无法解析工具参数: {arguments_json}"
                    results.append((tool_call, result))
                    continue

                # 调用工具
                try:
                    result = await self.mcp_service.call_tool(
                        tool_name, arguments
                    )
                    logger.info(f"工具 {tool_name} 返回结果: {result}")
                except Exception as tool_error:
                    logger.error(
                        f"调用工具 '{tool_name}' 时出错: {str(tool_error)}"
                    )
                    # 将错误信息作为工具调用结果返回
                    result = f"Error: {str(tool_error)}"
                
                results.append((tool_call, result))
                
            except Exception as e:
                logger.error(f"处理工具调用时出错: {str(e)}")
                results.append((tool_call, f"Error: {str(e)}"))
                
        return results 