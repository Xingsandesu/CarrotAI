from typing import Optional, Union, Dict, Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import get_password_hash, verify_password
from app.crud.base import CRUDBase
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


class CRUDUser(CRUDBase[User, UserCreate, UserUpdate]):
    """
    用户CRUD操作类
    继承自CRUDBase，添加用户特定的操作
    """

    async def get_by_email(self, db: AsyncSession, *, email: str) -> Optional[User]:
        """
        通过邮箱获取用户

        Args:
            db: 异步数据库会话
            email: 用户邮箱

        Returns:
            查询到的用户或None
        """
        stmt = select(self.model).where(self.model.email == email)
        result = await db.execute(stmt)
        return result.scalars().first()

    async def get_by_username(
        self, db: AsyncSession, *, username: str
    ) -> Optional[User]:
        """
        通过用户名获取用户

        Args:
            db: 异步数据库会话
            username: 用户名

        Returns:
            查询到的用户或None
        """
        stmt = select(self.model).where(self.model.username == username)
        result = await db.execute(stmt)
        return result.scalars().first()

    async def create(self, db: AsyncSession, *, obj_in: UserCreate) -> User:
        """
        创建新用户 (移除 admin 角色和特殊 token 限制逻辑)
        """
        # 设置默认 token 限制 (不再区分 admin)
        token_limit = (
            obj_in.token_limit
            if obj_in.token_limit is not None
            else settings.USER_TOKEN_LIMIT
        )

        db_obj = User(
            email=obj_in.email,
            username=obj_in.username,
            hashed_password=get_password_hash(obj_in.password),
            is_active=obj_in.is_active if obj_in.is_active is not None else True,
            token_limit=token_limit,
            token_used=0,
        )
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def authenticate(
        self, db: AsyncSession, *, username: str, password: str
    ) -> Optional[User]:
        """
        认证用户

        Args:
            db: 异步数据库会话
            username: 邮箱（表单字段仍为username，但实际使用邮箱）
            password: 密码

        Returns:
            认证成功的用户或None
        """
        user = await self.get_by_email(db, email=username)
        if not user:
            return None
        if not verify_password(password, user.hashed_password):
            return None
        return user

    async def check_token_available(
        self, db: AsyncSession, user_id: int, tokens_needed: int = 1
    ) -> bool:
        """
        检查用户是否有足够的token可用 (移除 admin 特权)
        """
        user = await self.get(db, id=user_id)
        if not user:
            return False

        # 移除管理员不受限制的逻辑
        # if user.role == "admin":
        #     return True

        # 检查总token使用量是否超出限制
        return user.token_used + tokens_needed <= user.token_limit

    async def reset_token_usage(self, db: AsyncSession, *, user_id: int) -> User:
        """
        重置用户的token使用量

        Args:
            db: 异步数据库会话
            user_id: 用户ID

        Returns:
            更新后的用户
        """
        user = await self.get(db, id=user_id)
        if not user:
            return None

        # 重置所有token使用量字段
        user.token_used = 0
        user.prompt_tokens_used = 0
        user.completion_tokens_used = 0

        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user

    # 以下是同步版本的方法，仅用于脚本和工具

    def get_by_email_sync(self, db: Session, *, email: str) -> Optional[User]:
        """同步版本的get_by_email，仅用于特殊情况"""
        stmt = select(self.model).where(self.model.email == email)
        result = db.execute(stmt)
        return result.scalars().first()

    def get_by_username_sync(self, db: Session, *, username: str) -> Optional[User]:
        """同步版本的get_by_username，仅用于特殊情况"""
        stmt = select(self.model).where(self.model.username == username)
        result = db.execute(stmt)
        return result.scalars().first()

    def create_sync(self, db: Session, *, obj_in: UserCreate) -> User:
        """
        同步版本的 create (移除 admin 角色和特殊 token 限制逻辑)
        """
        # 设置默认token限制 (不再区分 admin)
        token_limit = (
            obj_in.token_limit
            if obj_in.token_limit is not None
            else settings.USER_TOKEN_LIMIT
        )

        db_obj = User(
            email=obj_in.email,
            username=obj_in.username,
            hashed_password=get_password_hash(obj_in.password),
            is_active=obj_in.is_active if obj_in.is_active is not None else True,
            token_limit=token_limit,
            token_used=0,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def update_sync(
        self, db: Session, *, db_obj: User, obj_in: Union[UserUpdate, Dict[str, Any]]
    ) -> User:
        """同步版本的update，仅用于特殊情况"""
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.dict(exclude_unset=True)

        # 如果密码在更新数据中，对其进行哈希处理
        if "password" in update_data and update_data["password"]:
            update_data["hashed_password"] = get_password_hash(update_data["password"])
            del update_data["password"]

        # 更新用户对象的属性
        for field in update_data:
            if hasattr(db_obj, field):
                setattr(db_obj, field, update_data[field])

        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    def reset_token_usage_sync(self, db: Session, *, user_id: int) -> Optional[User]:
        """同步版本的 reset_token_usage"""
        user = db.get(User, user_id)
        if not user:
            return None

        # 重置所有token使用量字段
        user.token_used = 0
        user.prompt_tokens_used = 0
        user.completion_tokens_used = 0

        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    def remove_sync(
        self, db: Session, *, id: int
    ) -> Optional[User]:  # 添加 remove_sync
        """同步版本的 remove"""
        obj = db.get(self.model, id)
        if obj:
            db.delete(obj)
            db.commit()
        return obj


# 创建CRUD操作单例
user = CRUDUser(User)
