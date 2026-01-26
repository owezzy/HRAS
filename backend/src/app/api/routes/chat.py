"""Chat routes for the advisory system."""

import contextlib
from typing import TYPE_CHECKING, Any

from fastapi import APIRouter, HTTPException

from src.app.schemas.chat import ChatRequest, ChatResponse
from src.app.services.chat_service import get_chat_service

TRACING_AVAILABLE = False
should_trace = lambda: False  # noqa: E731


@contextlib.asynccontextmanager
async def _noop_trace_session(session_name: str, metadata: dict[str, Any] | None = None):  # noqa: ARG001
    yield None


langsmith_trace_session = _noop_trace_session

try:
    from src.app.core.tracing import langsmith_trace_session, should_trace  # type: ignore[assignment]

    TRACING_AVAILABLE = True
except ImportError:
    pass

if TYPE_CHECKING:
    from src.app.core.tracing import langsmith_trace_session, should_trace

router = APIRouter(prefix="/chat", tags=["Chat"])


@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    """Process a chat message and return AI-generated response.

    This endpoint will:
    1. Retrieve relevant human rights documents from UHRI
    2. Generate a response using the RAG pipeline
    3. Return response with source citations
    """
    try:
        service = get_chat_service()

        if TRACING_AVAILABLE and should_trace():
            session_name = f"chat_{request.conversation_id or 'new'}"
            metadata = {
                "conversation_id": str(request.conversation_id) if request.conversation_id else None,
                "message_length": len(request.message),
                "has_conversation_context": request.conversation_id is not None,
            }
            async with langsmith_trace_session(session_name, metadata):
                return await service.process_message(request)
        else:
            return await service.process_message(request)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing message: {e!s}") from e
