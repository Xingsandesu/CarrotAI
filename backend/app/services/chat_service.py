from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.schemas.chat import ChatRequest
from app.services.deepseek.message_processor import MessageProcessor
from app.services.deepseek.chat_handler import handle_deepseek_chat
import logging

logger = logging.getLogger(__name__)


async def post_chat_service(
    request: ChatRequest, db: AsyncSession, user_id: int
) -> AsyncGenerator[str, None]:
    """
    处理聊天请求并返回SSE格式的响应

    Args:
        request: 聊天请求对象
        db: 异步数据库会话
        user_id: 用户ID

    Yields:
        SSE格式的聊天响应内容
    """
    # 确定使用的模型
    model = determine_model(request)

    # 如果是DeepSeek模型，使用专门的处理函数
    if model.startswith("deepseek"):
        logger.info(f"使用DeepSeek处理函数处理模型: {model}")
        async for response in handle_deepseek_chat(request, db, user_id):
            yield response
        return

    # 如果是其他模型，可以在这里添加对应的处理逻辑
    # 例如：if model.startswith("other-model"):
    #          async for response in handle_other_model_chat(request, db, user_id):
    #              yield response
    #          return

    # 如果没有匹配的处理函数，返回错误信息
    logger.error(f"未找到模型 {model} 的处理函数")
    yield MessageProcessor.format_error_message(f"不支持的模型: {model}")


def determine_model(request: ChatRequest) -> str:
    """确定要使用的模型"""
    if not request.model or request.model == "deepseek":
        # 前端未传入模型名称或传入通用"deepseek"
        if request.use_deep_thinking:
            return "deepseek-reasoner"
        else:
            return "deepseek-chat"
    else:
        # 使用前端指定的模型
        return settings.DEFAULT_MODEL
