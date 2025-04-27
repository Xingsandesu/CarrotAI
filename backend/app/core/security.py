from datetime import timedelta
from typing import Any, Optional, Union
import bcrypt
from jose import jwt


from app.core.config import settings
from app.utils.datetime_utils import get_now


def create_access_token(
    subject: Union[str, Any], expires_delta: Optional[timedelta] = None
) -> str:
    """
    创建JWT访问令牌

    Args:
        subject: 令牌主题(通常是用户ID)
        expires_delta: 过期时间增量

    Returns:
        编码后的JWT令牌
    """
    if expires_delta:
        expire = get_now() + expires_delta
    else:
        expire = get_now() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    # 创建JWT载荷
    to_encode = {"exp": expire, "sub": str(subject)}

    # 使用密钥进行编码
    encoded_jwt = jwt.encode(
        to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM
    )
    return encoded_jwt


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    验证密码

    Args:
        plain_password: 明文密码
        hashed_password: 密码哈希值

    Returns:
        密码是否匹配
    """
    return bcrypt.checkpw(
        bytes(plain_password, encoding="utf-8"),
        bytes(hashed_password, encoding="utf-8"),
    )


def get_password_hash(password: str) -> str:
    """
    生成密码哈希值

    Args:
        password: 明文密码

    Returns:
        密码哈希值
    """
    hash_bytes = bcrypt.hashpw(
        bytes(password, encoding="utf-8"),
        bcrypt.gensalt(),
    )
    return hash_bytes.decode("utf-8")  # 将bytes转换为字符串
