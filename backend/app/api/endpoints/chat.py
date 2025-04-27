from typing import Union
import logging
from fastapi import APIRouter, Depends, status
from fastapi.responses import StreamingResponse, JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_async_db, get_current_active_user
from app.models.user import User
from app.schemas.chat import ChatRequest
from app.services.chat_service import post_chat_service
from app.utils.response_formatter import create_standard_response

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/stream", response_model=None)
async def create_chat(
    request: ChatRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_async_db),
) -> Union[StreamingResponse, JSONResponse]:
    """
    创建新的聊天对话，以SSE流的形式返回响应

    Args:
        request: 聊天请求，包含当前消息、上下文消息、模型信息等
        current_user: 当前登录用户
        db: 数据库会话

    Returns:
        StreamingResponse: 以SSE格式流式返回聊天响应
        或
        JSONResponse: 发生错误时的标准化响应
    """
    try:
        # 调用聊天服务处理请求
        return StreamingResponse(
            post_chat_service(request, db, current_user.id),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "X-Accel-Buffering": "no",
                "Connection": "keep-alive",
                "Content-Encoding": "identity",
            },
        )
    except Exception as e:
        logger.error(f"聊天处理异常: {str(e)}", exc_info=True)
        return create_standard_response(
            message=f"聊天处理失败: {str(e)}",
            actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
