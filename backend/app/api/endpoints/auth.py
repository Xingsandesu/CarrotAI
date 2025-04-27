from datetime import timedelta

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_async_db
from app.core.config import settings
from app.core.security import create_access_token
from app.crud.user import user


from app.utils.response_formatter import create_standard_response

router = APIRouter()


@router.post("/login")
async def login_access_token(
    db: AsyncSession = Depends(get_async_db),
    form_data: OAuth2PasswordRequestForm = Depends(),
) -> JSONResponse:
    """
    OAuth2兼容的token登录，获取访问令牌
    """
    user_obj = await user.authenticate(
        db, username=form_data.username, password=form_data.password
    )
    if not user_obj:
        return create_standard_response(
            message="邮箱或密码不正确", actual_status_code=status.HTTP_401_UNAUTHORIZED
        )
    elif not user_obj.is_active:
        return create_standard_response(
            message="用户未激活", actual_status_code=status.HTTP_400_BAD_REQUEST
        )

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        subject=str(user_obj.id), expires_delta=access_token_expires
    )

    # 返回用户信息和 token
    user_data = {
        "id": user_obj.id,
        "email": user_obj.email,
        "name": user_obj.username,
    }
    return create_standard_response(
        result={"user": user_data, "token": access_token},
        message="登录成功",
        actual_status_code=status.HTTP_200_OK,
    )
