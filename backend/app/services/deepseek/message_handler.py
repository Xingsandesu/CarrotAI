"""
消息处理器模块，负责处理和验证聊天消息序列
"""

import logging
from typing import List, Dict, Any
from app.schemas.chat import ChatMessage

from .message_processor import MessageProcessor

logger = logging.getLogger(__name__)


class MessageHandler:
    """消息处理器，负责处理和验证聊天消息"""

    async def process_reasoner_messages(
        self, 
        context_messages: List[ChatMessage],
        current_message: ChatMessage
    ) -> List[ChatMessage]:
        """
        处理推理模型的消息序列
        
        Args:
            context_messages: 上下文消息列表
            current_message: 当前消息
            
        Returns:
            处理后的消息列表
        """
        # 处理消息序列，确保第一条是用户消息，并且用户和助手消息交替出现
        processed_messages = []

        # 查找第一条用户消息
        first_user_msg_index = -1
        for i, msg in enumerate(context_messages):
            if msg.role == "user":
                first_user_msg_index = i
                break

        if first_user_msg_index == -1:
            # 如果没有用户消息，使用当前消息（如果是用户消息）
            if current_message.role == "user":
                # 只添加当前用户消息，跳过所有上下文
                logger.warning(
                    "上下文中没有用户消息，且当前消息是用户消息，将跳过所有上下文消息"
                )
                return []
            else:
                # 如果当前消息也不是用户消息，则无法满足要求
                logger.error(
                    "无法为deepseek-reasoner模型准备有效的消息序列：没有用户消息"
                )
                raise ValueError("无法为深度思考模型准备有效的消息序列：没有用户消息")
        else:
            # 开始处理消息序列，确保用户和助手消息交替出现
            # 首先添加第一条用户消息
            processed_messages.append(context_messages[first_user_msg_index])

            # 然后交替添加用户和助手消息
            expected_role = "assistant"  # 第一条消息是用户消息，所以下一个期望是助手消息

            # 遍历剩余消息，按照交替顺序添加
            for i, msg in enumerate(context_messages):
                # 跳过已经添加的第一条用户消息
                if i == first_user_msg_index:
                    continue

                # 如果消息角色与期望的角色匹配，则添加并切换期望角色
                if msg.role == expected_role:
                    processed_messages.append(msg)
                    expected_role = "user" if expected_role == "assistant" else "assistant"

            # 记录处理结果
            logger.warning(
                "为deepseek-reasoner模型重新排序消息，确保用户和助手消息交替出现"
            )
            return processed_messages

    async def validate_reasoner_messages(self, messages: List[Dict[str, Any]]) -> None:
        """
        验证推理模型的消息序列
        
        Args:
            messages: 消息列表
            
        Raises:
            ValueError: 如果消息序列无效
        """
        # 检查第一条非系统消息是否为用户消息
        if len(messages) > 1 and messages[1]["role"] != "user":
            logger.error(
                "无法为deepseek-reasoner模型准备有效的消息序列：第一条非系统消息不是用户消息"
            )
            raise ValueError("无法为深度思考模型准备有效的消息序列：第一条非系统消息不是用户消息")

        # 检查是否有连续的相同角色消息
        for i in range(1, len(messages) - 1):
            if messages[i]["role"] == messages[i + 1]["role"]:
                logger.error(
                    f"无法为deepseek-reasoner模型准备有效的消息序列：消息{i + 1}和{i + 2}都是{messages[i]['role']}角色"
                )
                logger.warning(f"消息序列：{[msg['role'] for msg in messages]}")

                # 尝试修复消息序列，删除连续相同角色的消息
                fixed_messages = [messages[0]]  # 保留系统消息
                last_role = None

                # 重新构建消息序列，确保角色交替
                for j in range(1, len(messages)):
                    current_role = messages[j]["role"]
                    if current_role != last_role:  # 只添加与前一条消息角色不同的消息
                        fixed_messages.append(messages[j])
                        last_role = current_role

                # 检查修复后的消息序列是否有效
                if len(fixed_messages) > 1 and fixed_messages[1]["role"] != "user":
                    logger.error(
                        "修复后的消息序列仍然无效：第一条非系统消息不是用户消息"
                    )
                    raise ValueError("无法为深度思考模型准备有效的消息序列：修复后仍然无效")

                logger.warning(
                    f"修复后的消息序列：{[msg['role'] for msg in fixed_messages]}"
                )
                # 替换原始消息
                messages.clear()
                messages.extend(fixed_messages)
                break  # 修复完成后退出循环 