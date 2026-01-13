"""Chat-related schemas."""

from datetime import datetime
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    """A single chat message."""

    id: UUID = Field(default_factory=uuid4)
    role: str = Field(..., description="Message role: 'user' or 'assistant'")
    content: str = Field(..., description="Message content")
    created_at: datetime = Field(default_factory=datetime.now)


class ChatRequest(BaseModel):
    """Chat request from client."""

    message: str = Field(..., min_length=1, max_length=4000, description="User message")
    conversation_id: UUID | None = Field(default=None, description="Existing conversation ID to continue")


class ChatResponse(BaseModel):
    """Chat response to client."""

    conversation_id: UUID
    message: ChatMessage
    sources: list[dict[str, Any]] = Field(default_factory=list, description="Source documents used for response")


class SourceResponse(BaseModel):
    country: str = ""
    mechanism: str = ""
    year: str = ""
    theme: str = ""
    status: str = ""
    snippet: str = ""


class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    created_at: datetime
    sources: list[SourceResponse] = Field(default_factory=list)


class ConversationResponse(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    messages: list[MessageResponse] = Field(default_factory=list)


class ConversationListItem(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int = 0


class ConversationListResponse(BaseModel):
    conversations: list[ConversationListItem]
    total: int
