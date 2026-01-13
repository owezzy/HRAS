from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from src.app.core.config import get_settings
from src.app.core.database import get_db
from src.app.repositories.conversation import ConversationRepository
from src.app.schemas.chat import (
    ConversationListItem,
    ConversationListResponse,
    ConversationResponse,
    MessageResponse,
    SourceResponse,
)

router = APIRouter(prefix="/conversations", tags=["Conversations"])
settings = get_settings()


def _require_postgres() -> None:
    if not settings.use_postgres:
        raise HTTPException(
            status_code=503,
            detail="Conversation persistence is disabled. Enable use_postgres feature flag.",
        )


@router.get("", response_model=ConversationListResponse)
async def list_conversations(
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = 50,
    offset: int = 0,
) -> ConversationListResponse:
    _require_postgres()
    repo = ConversationRepository(db)
    conversations = await repo.list_all(limit=limit, offset=offset)
    return ConversationListResponse(
        conversations=[
            ConversationListItem(
                id=c.id,
                title=c.title,
                created_at=c.created_at,
                updated_at=c.updated_at,
                message_count=len(c.messages) if hasattr(c, "messages") else 0,
            )
            for c in conversations
        ],
        total=len(conversations),
    )


@router.get("/{conversation_id}", response_model=ConversationResponse)
async def get_conversation(
    conversation_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ConversationResponse:
    _require_postgres()
    repo = ConversationRepository(db)
    conversation = await repo.get_by_id(conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return ConversationResponse(
        id=conversation.id,
        title=conversation.title,
        created_at=conversation.created_at,
        updated_at=conversation.updated_at,
        messages=[
            MessageResponse(
                id=m.id,
                role=m.role,
                content=m.content,
                created_at=m.created_at,
                sources=[
                    SourceResponse(
                        country=s.country,
                        mechanism=s.mechanism,
                        year=s.year,
                        theme=s.theme,
                        status=s.status,
                        snippet=s.snippet,
                    )
                    for s in m.sources
                ],
            )
            for m in conversation.messages
        ],
    )


@router.delete("/{conversation_id}", status_code=204)
async def delete_conversation(
    conversation_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> None:
    _require_postgres()
    repo = ConversationRepository(db)
    deleted = await repo.delete(conversation_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Conversation not found")
