from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_user
from app.db.session import get_async_db
from app.models.user import User
from app.schemas.user import PasswordUpdate
from app.core.security import get_password_hash, verify_password
from app.utils.response_formatter import create_standard_response
from app.utils.datetime_utils import datetime_to_timestamp_ms
from fastapi.responses import JSONResponse


router = APIRouter()


@router.get("/me")
async def read_user_me(
    current_user: User = Depends(get_current_active_user),
) -> JSONResponse:
    """
    获取当前用户信息，包含：
    1. 基本用户资料
    2. Token使用情况
    """
    # 基本用户资料
    user_data = {
        "id": current_user.id,
        "email": current_user.email,
        "username": current_user.username,
        "is_active": current_user.is_active,
        "created_at": datetime_to_timestamp_ms(current_user.created_at),
        "updated_at": datetime_to_timestamp_ms(current_user.updated_at),
    }

    # Token使用情况 - 直接从user对象构建
    token_stats = {
        "token_limit": current_user.token_limit,  # 总token限制
        "token_used": current_user.token_used,  # 总token使用量
        "prompt_tokens_used": current_user.prompt_tokens_used,  # 输入token使用量
        "completion_tokens_used": current_user.completion_tokens_used,  # 输出token使用量
        "prompt_cache_hit_tokens_used": current_user.prompt_cache_hit_tokens_used,  # 缓存命中token使用量
        "prompt_cache_miss_tokens_used": current_user.prompt_cache_miss_tokens_used,  # 缓存未命中token使用量
    }

    # 构建简化的响应
    response_data = {
        "user": user_data,
        "token_usage": token_stats,
    }

    # Use new formatter for success
    return create_standard_response(
        result=response_data,
        message="获取用户信息成功",
        actual_status_code=status.HTTP_200_OK,
    )


@router.put("/me/password")
async def update_password_me(
    *,
    db: AsyncSession = Depends(get_async_db),
    password_update: PasswordUpdate,
    current_user: User = Depends(get_current_active_user),
) -> JSONResponse:
    """更新当前用户的密码"""
    # 验证当前密码
    if not verify_password(
        password_update.current_password, current_user.hashed_password
    ):
        # Use new formatter for bad request instead of HTTPException
        return create_standard_response(
            message="当前密码不正确", actual_status_code=status.HTTP_400_BAD_REQUEST
        )

    # 更新密码
    hashed_password = get_password_hash(password_update.new_password)
    current_user.hashed_password = hashed_password
    db.add(current_user)
    await db.commit()

    # Use new formatter for success
    return create_standard_response(
        message="密码更新成功", actual_status_code=status.HTTP_200_OK
    )
