from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr


# 用户的共享属性
class UserBase(BaseModel):
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    is_active: Optional[bool] = True
    token_limit: Optional[int] = None


# 创建用户时的请求
class UserCreate(UserBase):
    email: EmailStr
    username: str
    password: str
    verification_code: str


# 更新用户时的请求
class UserUpdate(UserBase):
    password: Optional[str] = None


# --- 重新添加密码修改和重置相关的 Schema ---
# 修改密码请求
class PasswordUpdate(BaseModel):
    current_password: str
    new_password: str


# 忘记密码 - 请求重置
class PasswordResetRequest(BaseModel):
    email: EmailStr


# 忘记密码 - 确认重置
class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str


# --- 添加结束 ---


# 数据库中完整的用户信息
class UserInDBBase(UserBase):
    id: int
    email: EmailStr
    username: str
    token_limit: int
    token_used: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True  # 允许从ORM模型创建


# 返回给API的用户信息
class User(UserInDBBase):
    pass


# 存储在数据库中的用户，包含密码
class UserInDB(UserInDBBase):
    hashed_password: str


# 登录请求
class UserLogin(BaseModel):
    email: str
    password: str


# Token响应
class Token(BaseModel):
    success: bool = True
    data: dict


# Token有效载荷
class TokenPayload(BaseModel):
    sub: Optional[int] = None


# 发送验证码请求
class SendCodeRequest(BaseModel):
    email: EmailStr
