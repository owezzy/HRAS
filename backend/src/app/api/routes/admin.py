"""Admin routes for data ingestion and management."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.app.services.chat_service import get_ingestion_service

router = APIRouter(prefix="/admin", tags=["Admin"])


class IngestRequest(BaseModel):
    """Request for data ingestion."""

    clear_existing: bool = False
    use_sample: bool = True


class IngestResponse(BaseModel):
    """Response from data ingestion."""

    documents_added: int
    total_documents: int
    collection: str
    message: str


class StatsResponse(BaseModel):
    """Vector store statistics response."""

    name: str
    count: int


@router.post("/ingest", response_model=IngestResponse)
async def ingest_data(request: IngestRequest = IngestRequest()) -> IngestResponse:
    """Ingest UHRI data into the vector store.

    This endpoint loads human rights recommendations from UHRI
    and stores them in the vector database for retrieval.

    Args:
        request: Ingestion options (clear_existing, use_sample).

    Returns:
        Ingestion statistics.
    """
    try:
        service = get_ingestion_service(use_sample=request.use_sample)
        result = await service.ingest(clear_existing=request.clear_existing)

        return IngestResponse(
            documents_added=result["documents_added"],
            total_documents=result["total_documents"],
            collection=result["collection"],
            message="Data ingestion completed successfully",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during ingestion: {e!s}") from e


@router.get("/stats", response_model=StatsResponse)
async def get_stats() -> StatsResponse:
    """Get vector store statistics.

    Returns:
        Collection name and document count.
    """
    try:
        service = get_ingestion_service()
        stats = await service.get_stats()
        return StatsResponse(name=stats["name"], count=stats["count"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting stats: {e!s}") from e
