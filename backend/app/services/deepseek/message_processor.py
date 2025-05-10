"""
消息处理模块，处理并格式化聊天消息
"""

import json
import logging
from typing import Dict, Any, Optional, List, Tuple

logger = logging.getLogger(__name__)


class MessageProcessor:
    """消息处理器，处理并格式化聊天消息"""

    @staticmethod
    def format_sse_message(
        content: Optional[str] = None,
        reasoning_content: Optional[str] = None,
        tool_calls: Optional[List[Dict[str, Any]]] = None,
    ) -> str:
        """
        将内容格式化为SSE消息格式

        Args:
            content: 要格式化的内容
            reasoning_content: 推理过程内容
            tool_calls: 原始工具调用信息

        Returns:
            格式化后的SSE消息
        """
        # 确保三个字段都存在，空值使用空字符串或空数组
        data = {
            "content": content or "",
            "reasoning_content": reasoning_content or "",
            "tool_calls": tool_calls or [],
        }
        return f"data: {json.dumps(data)}\n\n"

    @staticmethod
    def format_error_message(error: str) -> str:
        """
        将错误信息格式化为SSE消息

        Args:
            error: 错误信息

        Returns:
            格式化后的SSE错误消息
        """
        data = {
            "error": error,
            "content": "",
            "reasoning_content": "",
            "tool_calls": [],
        }
        return f"data: {json.dumps(data)}\n\n"

    @staticmethod
    def extract_content(
        chunk: Dict[str, Any],
    ) -> Tuple[Optional[str], Optional[str], Optional[List[Dict[str, Any]]]]:
        """
        从响应块中提取正文内容、推理内容和工具调用

        Args:
            chunk: DeepSeek API响应块

        Returns:
            提取的正文内容、推理内容和工具调用的元组
        """
        try:
            content = None
            reasoning_content = None
            tool_calls = None

            # 从choices中提取内容
            if chunk.get("choices") and chunk["choices"]:
                delta = chunk["choices"][0].get("delta", {})
                content = delta.get("content")
                reasoning_content = delta.get("reasoning_content")
                tool_calls = delta.get("tool_calls")

            # 检查是否存在完整的工具调用信息
            if "complete_tool_calls" in chunk:
                tool_calls = chunk["complete_tool_calls"]

            return content, reasoning_content, tool_calls
        except Exception as e:
            logger.error(f"提取内容时出错: {str(e)}")
            return None, None, None

    @staticmethod
    def extract_usage(chunk: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        从响应块中提取token使用信息

        Args:
            chunk: DeepSeek API响应块

        Returns:
            token使用信息或None
        """
        try:
            return chunk.get("usage")
        except Exception as e:
            logger.error(f"提取token使用信息时出错: {str(e)}")
            return None
