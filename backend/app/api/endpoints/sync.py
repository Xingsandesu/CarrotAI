from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi.responses import JSONResponse
import logging

from app.api.deps import get_async_db, get_current_active_user
from app.crud.conversation import conversation
from app.models.user import User as UserModel
from app.models.conversation import Conversation
from app.schemas.conversation import SyncRequest, DeleteAllConversationsRequest
from app.utils.response_formatter import create_standard_response
from app.utils.datetime_utils import (
    safe_get_now,
    timestamp_ms,
    datetime_to_timestamp_ms,
)

# 获取日志记录器
logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/conversations")
async def sync_conversations(
    sync_data: SyncRequest,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserModel = Depends(get_current_active_user),
) -> JSONResponse:
    """
    增量同步用户会话数据

    客户端发送自上次同步后的会话，服务器处理并返回更新后的数据
    """
    # 获取当前时间戳作为同步时间点
    current_timestamp = timestamp_ms()

    # 日志记录，记录同步开始
    logger.info(
        f"用户 {current_user.id} 开始同步会话，收到 {len(sync_data.conversations)} 个会话"
    )

    # 获取用户现有的对话（包括已删除的）
    existing_conversations = await conversation.get_user_conversations(
        db, user_id=current_user.id, skip_deleted=False
    )
    logger.info(
        f"用户 {current_user.id} 在数据库中已有 {len(existing_conversations)} 个会话"
    )

    # 建立现有对话映射 {conversation_id: conversation}
    existing_conv_map = {conv.conversation_id: conv for conv in existing_conversations}

    # 找出已删除的对话ID列表（仅用于返回给客户端）
    deleted_conversation_ids = [
        conv.conversation_id for conv in existing_conversations if conv.is_deleted
    ]

    # 记录客户端请求的会话ID
    client_conv_ids = []

    # 记录已处理的会话ID
    processed_conv_ids = []

    # 处理客户端发送的会话数据
    for client_conv in sync_data.conversations:
        conv_id = client_conv.get("conversation_id")
        if not conv_id:
            # 跳过无效会话
            logger.warning("收到无效会话ID，已跳过")
            continue

        client_conv_ids.append(conv_id)

        if conv_id in existing_conv_map:
            # 更新现有会话
            existing_conv = existing_conv_map[conv_id]
            logger.info(f"更新现有会话: {conv_id}")

            # 如果会话已被标记为删除，则跳过更新
            if existing_conv.is_deleted:
                logger.info(f"会话 {conv_id} 已被删除，跳过更新")
                continue

            # 更新会话标题
            if "title" in client_conv and client_conv["title"]:
                existing_conv.title = client_conv["title"]

            # 更新会话元数据
            if "meta_data" in client_conv and client_conv["meta_data"]:
                existing_conv.meta_data = client_conv["meta_data"]

            # 处理会话消息更新
            if "messages" in client_conv and isinstance(client_conv["messages"], list):
                # 如果客户端提供的消息比服务器上存储的更多，则更新
                if len(client_conv["messages"]) > len(existing_conv.messages):
                    logger.info(
                        f"会话 {conv_id} 更新消息: {len(existing_conv.messages)} -> {len(client_conv['messages'])}"
                    )
                    existing_conv.messages = client_conv["messages"]

            # 更新同步时间 - 使用不带时区的时间
            existing_conv.last_synced_at = safe_get_now()
            existing_conv.updated_at = safe_get_now()

            # 保存更新
            db.add(existing_conv)
            processed_conv_ids.append(conv_id)
        else:
            # 创建新会话
            logger.info(f"创建新会话: {conv_id}")

            # 准备会话数据
            conversation_data = {
                "user_id": current_user.id,
                "conversation_id": conv_id,
                "title": client_conv.get("title"),
                "messages": client_conv.get("messages", []),
                "meta_data": client_conv.get("meta_data"),
                "last_synced_at": safe_get_now(),
                "is_deleted": False,
            }

            # 创建新会话对象
            new_conversation = Conversation(**conversation_data)
            db.add(new_conversation)
            logger.info(f"会话 {conv_id} 已添加到会话中")
            processed_conv_ids.append(conv_id)

    # 提交所有更改
    try:
        logger.info("提交所有会话更改")
        await db.commit()
        logger.info("会话更改提交成功")
    except Exception as e:
        logger.error(f"同步会话失败: {str(e)}", exc_info=True)
        await db.rollback()
        return create_standard_response(
            message=f"同步会话失败: {e}",
            actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    # 重新获取已处理的会话
    processed_conversations = []
    for conv_id in processed_conv_ids:
        # 获取单个会话
        conv = await conversation.get_by_conversation_id(db, conversation_id=conv_id)
        if conv and not conv.is_deleted:
            processed_conversations.append(conv)

    logger.info(f"成功获取已处理的会话，共 {len(processed_conversations)} 个")

    # 转换为API响应格式
    conv_response_list = []
    for conv in processed_conversations:
        # 使用工具函数统一处理时间戳转换
        updated_at_ms = (
            datetime_to_timestamp_ms(conv.updated_at) if conv.updated_at else None
        )
        created_at_ms = (
            datetime_to_timestamp_ms(conv.created_at) if conv.created_at else None
        )

        # 确保时间戳是整数类型
        if updated_at_ms is not None:
            updated_at_ms = int(updated_at_ms)
        if created_at_ms is not None:
            created_at_ms = int(created_at_ms)

        conv_dict = {
            "conversation_id": conv.conversation_id,
            "title": conv.title,
            "messages": conv.messages,
            "meta_data": conv.meta_data,
            "updated_at": updated_at_ms,
            "created_at": created_at_ms,
        }
        conv_response_list.append(conv_dict)

    # 记录已处理的会话ID
    processed_conv_ids_log = [conv.conversation_id for conv in processed_conversations]
    logger.info(f"已处理的会话ID: {processed_conv_ids_log}")
    logger.info(f"客户端提交的会话ID: {client_conv_ids}")

    # 返回同步结果
    sync_result = {
        "conversations": conv_response_list,
        "deleted_conversation_ids": deleted_conversation_ids,
        "synced_at": int(current_timestamp),
    }
    logger.info(f"同步完成，返回 {len(conv_response_list)} 个会话")
    return create_standard_response(
        result=sync_result,
        message="会话同步成功",
        actual_status_code=status.HTTP_200_OK,
    )


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserModel = Depends(get_current_active_user),
) -> JSONResponse:
    """
    删除指定会话（软删除）
    """
    # 获取会话
    conv = await conversation.get_by_conversation_id(
        db, conversation_id=conversation_id
    )

    # 验证会话存在且属于当前用户
    if not conv or conv.user_id != current_user.id:
        return create_standard_response(
            message="会话不存在或无权操作", actual_status_code=status.HTTP_404_NOT_FOUND
        )

    # 软删除会话
    try:
        success = await conversation.soft_delete(db, conversation_id=conversation_id)
        if not success:
            return create_standard_response(
                message="尝试删除会话时发生未知错误",
                actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        await db.commit()
    except Exception as e:
        await db.rollback()
        return create_standard_response(
            message=f"删除会话失败: {e}",
            actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return create_standard_response(
        message="会话已成功删除", actual_status_code=status.HTTP_200_OK
    )


@router.get("/conversations")
async def get_user_conversations(
    db: AsyncSession = Depends(get_async_db),
    current_user: UserModel = Depends(get_current_active_user),
) -> JSONResponse:
    """
    获取用户的所有会话

    用于客户端初始加载会话数据，不需要提供任何会话数据
    """
    # 获取当前时间戳作为同步时间点
    current_timestamp = timestamp_ms()

    # 获取用户的所有有效会话
    user_conversations = await conversation.get_user_conversations(
        db, user_id=current_user.id, skip_deleted=True
    )
    logger.info(f"获取用户 {current_user.id} 的会话，共 {len(user_conversations)} 个")

    # 转换为API响应格式
    conv_response_list = []
    for conv in user_conversations:
        # 使用工具函数统一处理时间戳转换
        updated_at_ms = (
            datetime_to_timestamp_ms(conv.updated_at) if conv.updated_at else None
        )
        created_at_ms = (
            datetime_to_timestamp_ms(conv.created_at) if conv.created_at else None
        )

        # 确保时间戳是整数类型
        if updated_at_ms is not None:
            updated_at_ms = int(updated_at_ms)
        if created_at_ms is not None:
            created_at_ms = int(created_at_ms)

        conv_dict = {
            "conversation_id": conv.conversation_id,
            "title": conv.title,
            "messages": conv.messages,
            "meta_data": conv.meta_data,
            "updated_at": updated_at_ms,
            "created_at": created_at_ms,
        }
        conv_response_list.append(conv_dict)

    # 返回结果
    sync_result = {
        "conversations": conv_response_list,
        "deleted_conversation_ids": [],  # 初始加载不需要删除的会话ID
        "synced_at": int(current_timestamp),
    }

    logger.info(f"获取会话完成，返回 {len(conv_response_list)} 个会话")
    return create_standard_response(
        result=sync_result,
        message="获取会话成功",
        actual_status_code=status.HTTP_200_OK,
    )


@router.delete("/conversations")
async def delete_all_conversations(
    request: DeleteAllConversationsRequest,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserModel = Depends(get_current_active_user),
) -> JSONResponse:
    """
    删除用户的所有会话（软删除）

    需要确认标志以防止意外删除
    """
    if not request.confirm:
        return create_standard_response(
            message="需要确认删除所有会话，请设置 'confirm': true",
            actual_status_code=status.HTTP_400_BAD_REQUEST,
        )

    # 删除用户的所有会话
    try:
        success = await conversation.delete_user_conversations(
            db, user_id=current_user.id
        )
        if not success:
            return create_standard_response(
                message="尝试删除所有会话时发生未知错误",
                actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        await db.commit()
    except Exception as e:
        await db.rollback()
        return create_standard_response(
            message=f"删除所有会话失败: {e}",
            actual_status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return create_standard_response(
        message="所有会话已成功删除", actual_status_code=status.HTTP_200_OK
    )
