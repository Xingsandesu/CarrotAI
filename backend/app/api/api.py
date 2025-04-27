from fastapi import APIRouter

from app.api.endpoints import auth, chat, user, sync, config

# API路由
api_router = APIRouter()

# 认证路由
api_router.include_router(auth.router, prefix="/auth", tags=["认证"])

# 聊天路由
api_router.include_router(chat.router, prefix="/chat", tags=["聊天"])

# 用户路由
api_router.include_router(user.router, prefix="/users", tags=["用户"])

# 同步路由
api_router.include_router(sync.router, prefix="/sync", tags=["会话同步"])

# 配置路由
api_router.include_router(config.router, prefix="/config", tags=["配置"])
