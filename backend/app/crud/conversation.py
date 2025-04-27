from typing import Any, Dict, List, Optional
from datetime import timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, and_, not_
import logging

from app.crud.base import CRUDBase
from app.models.conversation import Conversation
from app.schemas.conversation import ConversationCreate, ConversationUpdate
from app.utils.datetime_utils import safe_get_now, timestamp_ms

# 获取日志记录器
logger = logging.getLogger(__name__)


class CRUDConversation(CRUDBase[Conversation, ConversationCreate, ConversationUpdate]):
    """会话CRUD操作实现"""

    async def get_by_conversation_id(
        self, db: AsyncSession, *, conversation_id: str
    ) -> Optional[Conversation]:
        """根据会话ID获取会话"""
        result = await db.execute(
            select(self.model).where(self.model.conversation_id == conversation_id)
        )
        return result.scalars().first()

    async def get_user_conversations(
        self, db: AsyncSession, *, user_id: int, skip_deleted: bool = True
    ) -> List[Conversation]:
        """获取用户的所有会话

        Args:
            db: 数据库会话
            user_id: 用户ID
            skip_deleted: 是否跳过已删除的会话
        """
        try:
            # 构建查询
            stmt = select(self.model).where(self.model.user_id == user_id)

            if skip_deleted:
                stmt = stmt.where(not_(self.model.is_deleted))

            # 添加排序
            stmt = stmt.order_by(self.model.updated_at.desc())

            # 执行查询
            result = await db.execute(stmt)
            conversations = list(result.scalars().all())

            logger.info(f"获取用户 {user_id} 的会话，共 {len(conversations)} 个")
            return conversations
        except Exception as e:
            logger.error(f"获取用户会话失败: {str(e)}", exc_info=True)
            return []

    async def create_conversation(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        conversation_id: str,
        title: Optional[str] = None,
        messages: Optional[List[Dict[str, Any]]] = None,
        meta_data: Optional[Dict[str, Any]] = None,
    ) -> Conversation:
        """创建新会话"""
        logger.info(f"创建新会话: user_id={user_id}, conversation_id={conversation_id}")

        # 准备会话数据
        conversation_data = {
            "user_id": user_id,
            "conversation_id": conversation_id,
            "title": title,
            "messages": messages or [],
            "meta_data": meta_data,
            "last_synced_at": safe_get_now(),
            "is_deleted": False,
        }

        # 创建会话
        new_conversation = self.model(**conversation_data)
        db.add(new_conversation)

        try:
            await db.commit()
            await db.refresh(new_conversation)
            logger.info(f"成功创建会话: {conversation_id}")
            return new_conversation
        except Exception as e:
            logger.error(f"创建会话失败: {str(e)}", exc_info=True)
            await db.rollback()
            raise

    async def add_message(
        self, db: AsyncSession, *, conversation_id: str, message: Dict[str, Any]
    ) -> Optional[Conversation]:
        """向会话添加新消息"""
        conversation = await self.get_by_conversation_id(
            db, conversation_id=conversation_id
        )
        if not conversation:
            logger.warning(f"添加消息失败：找不到会话 {conversation_id}")
            return None

        # 确保消息有时间戳
        if "timestamp" not in message:
            message["timestamp"] = timestamp_ms()

        # 添加消息到会话
        conversation.messages.append(message)
        conversation.updated_at = safe_get_now()

        db.add(conversation)
        try:
            await db.commit()
            await db.refresh(conversation)
            logger.info(f"成功添加消息到会话 {conversation_id}")
            return conversation
        except Exception as e:
            logger.error(f"添加消息失败: {str(e)}", exc_info=True)
            await db.rollback()
            return None

    async def soft_delete(self, db: AsyncSession, *, conversation_id: str) -> bool:
        """软删除会话"""
        conversation = await self.get_by_conversation_id(
            db, conversation_id=conversation_id
        )
        if not conversation:
            logger.warning(f"软删除失败：找不到会话 {conversation_id}")
            return False

        conversation.is_deleted = True
        conversation.updated_at = safe_get_now()

        db.add(conversation)
        try:
            await db.commit()
            logger.info(f"成功软删除会话 {conversation_id}")
            return True
        except Exception as e:
            logger.error(f"软删除会话失败: {str(e)}", exc_info=True)
            await db.rollback()
            return False

    async def delete_user_conversations(
        self, db: AsyncSession, *, user_id: int
    ) -> bool:
        """删除用户的所有会话（软删除）"""
        try:
            await db.execute(
                update(self.model)
                .where(self.model.user_id == user_id)
                .values(is_deleted=True, updated_at=safe_get_now())
            )
            await db.commit()
            logger.info(f"成功删除用户 {user_id} 的所有会话")
            return True
        except Exception as e:
            logger.error(f"删除用户会话失败: {str(e)}", exc_info=True)
            await db.rollback()
            return False

    async def purge_deleted_conversations(
        self, db: AsyncSession, *, user_id: Optional[int] = None, days_old: int = 30
    ) -> int:
        """永久删除已标记为删除的会话"""
        cutoff_date = safe_get_now() - timedelta(days=days_old)
        query = delete(self.model).where(
            and_(self.model.is_deleted, self.model.updated_at < cutoff_date)
        )

        if user_id:
            query = query.where(self.model.user_id == user_id)

        try:
            result = await db.execute(query)
            await db.commit()
            deleted_count = result.rowcount
            logger.info(f"永久删除了 {deleted_count} 个会话")
            return deleted_count
        except Exception as e:
            logger.error(f"永久删除会话失败: {str(e)}", exc_info=True)
            await db.rollback()
            return 0


# 创建CRUD实例
conversation = CRUDConversation(Conversation)
