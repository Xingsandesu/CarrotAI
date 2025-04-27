from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.crud.user import user
from app.db.session import get_async_db
from app.models.user import User
from app.schemas.user import TokenPayload

# 令牌URL
reusable_oauth2 = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


async def get_current_user(
    db: AsyncSession = Depends(get_async_db), token: str = Depends(reusable_oauth2)
) -> User:
    """
    获取当前用户

    Args:
        db: 异步数据库会话
        token: JWT token

    Returns:
        当前用户

    Raises:
        HTTPException: Token无效或用户不存在
    """
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        token_data = TokenPayload(**payload)
    except (jwt.JWTError, ValidationError):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="无法验证凭据",
        )

    user_obj = await user.get(db, id=token_data.sub)
    if not user_obj:
        raise HTTPException(status_code=404, detail="用户不存在")
    return user_obj


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """
    获取当前活跃用户

    Args:
        current_user: 当前用户

    Returns:
        当前活跃用户

    Raises:
        HTTPException: 用户不活跃
    """
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="用户未激活")
    return current_user
