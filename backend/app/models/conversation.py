from datetime import datetime
from sqlalchemy import Boolean, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import JSON, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base
from app.utils.datetime_utils import get_now_naive, safe_get_now


class Conversation(Base):
    """
    会话模型
    存储用户与AI的会话信息
    """

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # 外键关联用户
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("user.id", ondelete="CASCADE"), index=True
    )
    user = relationship("User", back_populates="conversations")

    # 会话信息
    conversation_id: Mapped[str] = mapped_column(
        String, unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String, nullable=True)

    # 会话状态
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)

    # 会话内容 - 使用JSONB以支持更高效的查询
    messages: Mapped[list] = mapped_column(JSONB, default=list)

    # 关联消息列表
    messages_rel = relationship(
        "Message", back_populates="conversation", cascade="all, delete-orphan"
    )

    # 元数据
    meta_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # 同步状态
    last_synced_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)

    # 时间戳
    created_at: Mapped[datetime] = mapped_column(DateTime, default=get_now_naive)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=get_now_naive, onupdate=get_now_naive
    )


class Message(Base):
    """
    消息模型
    存储会话中的单条消息
    """

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # 外键关联会话
    conversation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("conversation.id", ondelete="CASCADE"), index=True
    )
    conversation = relationship("Conversation", back_populates="messages_rel")

    # 消息内容
    role: Mapped[str] = mapped_column(String, nullable=False)  # user, assistant, system
    content: Mapped[str] = mapped_column(Text, nullable=False)

    # 消息元数据
    message_meta: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    # 消息标识
    message_id: Mapped[str] = mapped_column(
        String, unique=True, index=True, nullable=False
    )

    # 时间戳 - 使用不带时区的时间函数替代datetime.utcnow
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=safe_get_now)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=safe_get_now)
