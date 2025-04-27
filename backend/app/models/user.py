from datetime import datetime
from sqlalchemy import Boolean, Integer, String, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base
from app.core.config import settings
from app.utils.datetime_utils import get_now_naive


class User(Base):
    """
    用户模型
    存储用户账户信息 (移除 role 和 is_superuser)
    """

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    username: Mapped[str] = mapped_column(
        String, unique=True, index=True, nullable=False
    )
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)

    # 用户状态
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Token限制
    token_limit: Mapped[int] = mapped_column(
        Integer, default=settings.USER_TOKEN_LIMIT
    )  # 用户token限制
    token_used: Mapped[int] = mapped_column(Integer, default=0)  # 用户token使用量

    # 单独记录输入和输出token使用量
    prompt_tokens_used: Mapped[int] = mapped_column(
        Integer, default=0
    )  # 输入token使用量
    completion_tokens_used: Mapped[int] = mapped_column(
        Integer, default=0
    )  # 输出token使用量

    # 缓存命中Token量 (来自DeepSeek API)
    prompt_cache_hit_tokens_used: Mapped[int] = mapped_column(
        Integer, default=0, comment="上下文缓存命中的tokens总数"
    )  # 缓存命中token使用量
    prompt_cache_miss_tokens_used: Mapped[int] = mapped_column(
        Integer, default=0, comment="上下文缓存未命中的tokens总数"
    )  # 缓存未命中token使用量

    # Token使用记录关联
    token_usages = relationship(
        "TokenUsage",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # 会话关联
    conversations = relationship(
        "Conversation",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # 时间戳 - 使用不带时区的时间函数，避免PostgreSQL时区处理冲突
    created_at: Mapped[datetime] = mapped_column(DateTime, default=get_now_naive)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=get_now_naive, onupdate=get_now_naive
    )

    @property
    def remaining_tokens(self) -> int:
        """
        获取用户剩余的token数量
        """
        return max(0, self.token_limit - self.token_used)

    @property
    def has_sufficient_tokens(self) -> bool:
        """
        检查用户是否有足够的token
        """
        return True
