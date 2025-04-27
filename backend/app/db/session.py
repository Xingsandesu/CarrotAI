from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.engine import create_engine
from sqlalchemy.exc import SQLAlchemyError
from contextlib import asynccontextmanager, contextmanager
from typing import AsyncGenerator, Generator
import logging

from app.core.config import settings

# 配置日志
logger = logging.getLogger(__name__)

# 创建异步SQLAlchemy引擎，优化连接池设置
async_engine = create_async_engine(
    str(settings.DATABASE_URL).replace("postgresql://", "postgresql+asyncpg://"),
    echo=False,
    pool_pre_ping=True,  # 连接前检查
    pool_recycle=1800,  # 30分钟回收连接
    pool_size=5,  # 连接池大小
    max_overflow=10,  # 最大溢出连接数
    pool_timeout=30,  # 获取连接超时时间
)

# 创建异步会话工厂
AsyncSessionLocal = sessionmaker(
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    bind=async_engine,
    expire_on_commit=False,  # 提交后不过期对象，减少后续查询
)


async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """
    获取异步数据库会话的依赖函数
    用于FastAPI的Depends，每次调用创建新会话
    """
    session = AsyncSessionLocal()
    try:
        yield session
    except SQLAlchemyError as e:
        await session.rollback()
        logger.error(f"数据库会话错误: {str(e)}")
        raise
    finally:
        await session.close()


@asynccontextmanager
async def get_async_db_context() -> AsyncGenerator[AsyncSession, None]:
    """
    异步上下文管理器版本的会话获取函数
    用于非依赖注入场景，如脚本、工具等

    用法:
    async with get_async_db_context() as session:
        result = await session.execute(...)
    """
    session = AsyncSessionLocal()
    try:
        yield session
    except SQLAlchemyError as e:
        await session.rollback()
        logger.error(f"数据库会话错误: {str(e)}")
        raise
    finally:
        await session.close()


# 创建同步SQLAlchemy引擎 (用于脚本和工具)，优化连接池设置
engine = create_engine(
    str(settings.DATABASE_URL),
    pool_pre_ping=True,
    pool_recycle=1800,
    pool_size=5,
    max_overflow=10,
    pool_timeout=30,
)

# 创建同步会话工厂 (用于脚本和工具)
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def get_db() -> Generator[Session, None, None]:
    """
    获取同步数据库会话的函数
    用于同步环境，每次调用创建新会话
    """
    session = SessionLocal()
    try:
        yield session
    except SQLAlchemyError as e:
        session.rollback()
        logger.error(f"数据库会话错误: {str(e)}")
        raise
    finally:
        session.close()


@contextmanager
def get_db_context() -> Generator[Session, None, None]:
    """
    同步上下文管理器版本的会话获取函数

    用法:
    with get_db_context() as session:
        result = session.query(...)
    """
    session = SessionLocal()
    try:
        yield session
    except SQLAlchemyError as e:
        session.rollback()
        logger.error(f"数据库会话错误: {str(e)}")
        raise
    finally:
        session.close()
