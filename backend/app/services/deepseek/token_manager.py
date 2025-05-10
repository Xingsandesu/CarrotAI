"""
Token使用量管理模块，负责处理和更新用户的token使用情况
"""

import logging
import traceback
from typing import Dict, Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.token_usage import TokenUsage
from app.crud.user import user as user_crud
from app.utils.datetime_utils import get_now_naive

logger = logging.getLogger(__name__)


class TokenManager:
    """Token使用量管理器，负责处理和更新用户的token使用情况"""

    @staticmethod
    async def update_token_usage(
        db: AsyncSession,
        user_id: int,
        usage: Dict[str, Any],
        request_type: str = "chat",
    ) -> None:
        """
        更新用户的token使用情况

        Args:
            db: 异步数据库会话
            user_id: 用户ID
            usage: DeepSeek API返回的token使用信息
            request_type: 请求类型
        """
        # 检查usage是否为None
        if usage is None:
            logger.error("更新token使用量失败: usage参数为None")
            return

        try:
            # 获取token使用信息
            token_info = TokenManager._extract_token_info(usage)

            # 获取并更新用户信息
            user = await TokenManager._update_user_token_usage(db, user_id, token_info)
            if not user:
                return

            # 创建token使用记录
            await TokenManager._create_token_usage_record(
                db, user_id, token_info, request_type
            )

            # 记录更新结果
            logger.info(
                f"用户 {user_id} token使用量已更新，总使用量: {user.token_used}，"
                f"缓存命中: {token_info['prompt_cache_hit_tokens']}，"
                f"缓存未命中: {token_info['prompt_cache_miss_tokens']}"
                f"输入Token: {token_info['prompt_tokens']}"
                f"输出Token: {token_info['completion_tokens']}"
                f"总Token: {token_info['total_tokens']}"
            )
        except Exception as e:
            logger.error(f"更新token使用量时发生错误: {str(e)}")
            # 记录详细错误信息
            logger.error(f"错误详情: {traceback.format_exc()}")

    @staticmethod
    def _extract_token_info(usage: Dict[str, Any]) -> Dict[str, int]:
        """从API响应中提取token使用信息"""
        return {
            "prompt_tokens": usage.get("prompt_tokens", 0),
            "completion_tokens": usage.get("completion_tokens", 0),
            "total_tokens": usage.get("total_tokens", 0),
            "prompt_cache_hit_tokens": usage.get("prompt_cache_hit_tokens", 0),
            "prompt_cache_miss_tokens": usage.get("prompt_cache_miss_tokens", 0),
        }

    @staticmethod
    async def _update_user_token_usage(
        db: AsyncSession, user_id: int, token_info: Dict[str, int]
    ) -> Optional[Any]:
        """更新用户的token使用量"""
        # 获取用户
        user = await user_crud.get(db, id=user_id)
        if not user:
            logger.error(f"更新token使用量失败: 找不到用户 ID {user_id}")
            return None

        # 更新用户token使用量
        user.token_used += token_info["total_tokens"]
        user.prompt_tokens_used += token_info["prompt_tokens"]
        user.completion_tokens_used += token_info["completion_tokens"]

        # 更新上下文缓存相关的token使用量
        user.prompt_cache_hit_tokens_used += token_info["prompt_cache_hit_tokens"]
        user.prompt_cache_miss_tokens_used += token_info["prompt_cache_miss_tokens"]

        # 保存到数据库
        db.add(user)
        return user

    @staticmethod
    async def _create_token_usage_record(
        db: AsyncSession, user_id: int, token_info: Dict[str, int], request_type: str
    ) -> None:
        """创建token使用记录"""
        # 创建token使用记录 - 使用不带时区的时间
        token_usage = TokenUsage(
            user_id=user_id,
            prompt_tokens=token_info["prompt_tokens"],
            completion_tokens=token_info["completion_tokens"],
            total_tokens=token_info["total_tokens"],
            prompt_cache_hit_tokens=token_info["prompt_cache_hit_tokens"],
            prompt_cache_miss_tokens=token_info["prompt_cache_miss_tokens"],
            request_type=request_type,
            created_at=get_now_naive(),
        )

        # 保存到数据库
        db.add(token_usage)
        await db.commit()
