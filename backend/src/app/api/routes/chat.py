"""Chat routes for the advisory system."""

from fastapi import APIRouter, HTTPException

from src.app.schemas.chat import ChatRequest, ChatResponse
from src.app.services.chat_service import get_chat_service

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
        return await service.process_message(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing message: {e!s}") from e
