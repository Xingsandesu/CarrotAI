from typing import List, Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from uuid import uuid4

from app.utils.datetime_utils import timestamp_ms


class MessageBase(BaseModel):
    """消息基础模型"""

    role: str
    content: str
    timestamp: Optional[float] = None


class MessageCreate(MessageBase):
    """创建消息模型"""

    message_id: Optional[str] = None

    @field_validator("message_id", mode="before")
    def set_message_id(cls, v):
        return v or str(uuid4())

    @field_validator("timestamp", mode="before")
    def set_timestamp(cls, v):
        return v or timestamp_ms()


class Message(MessageBase):
    """消息模型"""

    message_id: str
    message_meta: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


class ConversationBase(BaseModel):
    """会话基础模型"""

    title: Optional[str] = None
    meta_data: Optional[Dict[str, Any]] = None


class ConversationCreate(ConversationBase):
    """创建会话模型"""

    conversation_id: Optional[str] = None
    messages: Optional[List[MessageCreate]] = Field(default_factory=list)

    @field_validator("conversation_id", mode="before")
    def set_conversation_id(cls, v):
        return v or str(uuid4())


class ConversationUpdate(ConversationBase):
    """更新会话模型"""

    is_deleted: Optional[bool] = None
    messages: Optional[List[Dict[str, Any]]] = None


class ConversationInDBBase(ConversationBase):
    """数据库中的会话模型"""

    id: int
    user_id: int
    conversation_id: str
    title: Optional[str]
    is_deleted: bool
    messages: List[Dict[str, Any]] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class Conversation(ConversationInDBBase):
    """API返回的会话模型"""

    pass


class ConversationList(BaseModel):
    """会话列表模型"""

    conversations: List[Conversation]
    count: int


class SyncRequest(BaseModel):
    """同步请求模型"""

    conversations: List[Dict[str, Any]]
    last_synced_at: Optional[float] = None


class SyncResponse(BaseModel):
    """同步响应模型"""

    success: bool
    conversations: List[Dict[str, Any]]
    deleted_conversations: List[str] = Field(default_factory=list)
    last_synced_at: float


class DeleteConversationRequest(BaseModel):
    """删除会话请求模型"""

    conversation_id: str


class DeleteAllConversationsRequest(BaseModel):
    """删除所有会话请求模型"""

    confirm: bool = False
