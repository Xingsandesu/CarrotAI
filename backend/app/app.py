from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.api.api import api_router
from app.core.config import settings
from app.utils.datetime_utils import get_now_naive, timestamp_ms

# 导入我们的自定义日志模块
from app.utils.logger import get_logger

# 获取logger实例
logger = get_logger("app.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时执行
    logger.info(f"应用启动,当前时间: {get_now_naive()}, 当前时间戳: {timestamp_ms()}")
    yield
    # 关闭时执行
    logger.info(f"应用关闭,当前时间: {get_now_naive()}, 当前时间戳: {timestamp_ms()}")


# 创建应用
app = FastAPI(
    title=settings.APP_NAME,
    description="CarrotAI backend",
    version="1.0.0",
    lifespan=lifespan,
)

# 设置CORS
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # 默认允许所有跨域请求（开发环境）
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# 添加API路由
app.include_router(api_router, prefix="")


@app.get("/health")
async def health_check():
    """健康检查接口"""
    logger.debug("健康检查接口被调用")
    return {"status": "OK"}


@app.get("/")
async def root():
    """根路径返回欢迎信息"""
    logger.debug("根路径被访问")
    return {"message": "欢迎使用AI聊天API"}
