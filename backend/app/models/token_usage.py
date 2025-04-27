from datetime import datetime
from sqlalchemy import Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base
from app.utils.datetime_utils import get_now_naive


class TokenUsage(Base):
    """
    Token使用记录模型
    记录用户的token使用情况
    """

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # 用户ID
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("user.id"), index=True)
    user = relationship("User", back_populates="token_usages")

    # Token使用量
    prompt_tokens: Mapped[int] = mapped_column(Integer, default=0)
    completion_tokens: Mapped[int] = mapped_column(Integer, default=0)
    total_tokens: Mapped[int] = mapped_column(Integer, default=0)

    # 缓存命中Token量 (来自DeepSeek API)
    prompt_cache_hit_tokens: Mapped[int] = mapped_column(
        Integer, default=0, comment="本次请求的输入中，缓存命中的 tokens 数"
    )
    prompt_cache_miss_tokens: Mapped[int] = mapped_column(
        Integer, default=0, comment="本次请求的输入中，缓存未命中的 tokens 数"
    )

    # 时间戳 - 使用不带时区的时间函数
    created_at: Mapped[datetime] = mapped_column(DateTime, default=get_now_naive)

    # 请求类型
    request_type: Mapped[str] = mapped_column(String(20), index=True)  # simple
