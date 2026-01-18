"""Document loader for UHRI data.

Converts UHRI JSON records into LangChain Documents for embedding and retrieval.
"""

from langchain_core.documents import Document

from src.app.ai.tools.uhri_client import SAMPLE_UHRI_DATA, UHRIClient


class UHRIDocumentLoader:
    """Loads UHRI data and converts to LangChain Documents."""

    def __init__(self, use_sample: bool = True) -> None:
        """Initialize the document loader.

        Args:
            use_sample: If True, use sample data instead of fetching from API.
                       Set to False in production to fetch real data.
        """
        self.use_sample = use_sample
        self.client = UHRIClient()

    async def load(self) -> list[Document]:
        """Load UHRI data and convert to Documents.

        Returns:
            List of LangChain Document objects.
        """
        if self.use_sample:
            raw_data = SAMPLE_UHRI_DATA
        else:
            raw_data = await self.client.fetch_full_dataset()

        return self._convert_to_documents(raw_data)

    async def load_sample(self, limit: int = 100) -> list[Document]:
        """Load a sample of UHRI data.

        Args:
            limit: Maximum number of records to load.

        Returns:
            List of LangChain Document objects.
        """
        if self.use_sample:
            raw_data = SAMPLE_UHRI_DATA[:limit]
        else:
            raw_data = await self.client.fetch_sample_data(limit)

        return self._convert_to_documents(raw_data)

    def _convert_to_documents(self, records: list[dict]) -> list[Document]:
        """Convert UHRI records to LangChain Documents.

        Args:
            records: Raw UHRI JSON records.

        Returns:
            List of Document objects with content and metadata.
        """
        documents = []

        for record in records:
            # Build document content - the text that will be embedded
            content = self._build_document_content(record)

            # Extract metadata for filtering
            metadata = self._extract_metadata(record)

            doc = Document(page_content=content, metadata=metadata)
            documents.append(doc)

        return documents

    def _build_document_content(self, record: dict) -> str:
        """Build searchable text content from a UHRI record.

        Args:
            record: Single UHRI record.

        Returns:
            Formatted text content for embedding.
        """
        parts = []

        # Country context
        country = record.get("country", "Unknown")
        parts.append(f"Country: {country}")

        # Mechanism (UPR, Treaty Body, etc.)
        mechanism = record.get("mechanism", "")
        cycle = record.get("cycle", "")
        year = record.get("year", "")
        if mechanism:
            mechanism_info = f"Mechanism: {mechanism}"
            if cycle:
                mechanism_info += f" ({cycle})"
            if year:
                mechanism_info += f", Year: {year}"
            parts.append(mechanism_info)

        # Recommending state (for UPR)
        recommending_state = record.get("recommending_state")
        if recommending_state:
            parts.append(f"Recommending State: {recommending_state}")

        # Theme/topic
        theme = record.get("theme", "")
        if theme:
            parts.append(f"Theme: {theme}")

        # The actual recommendation text (most important)
        recommendation = record.get("recommendation", "")
        if recommendation:
            parts.append(f"Recommendation: {recommendation}")

        # Status
        status = record.get("status", "")
        if status:
            parts.append(f"Status: {status}")

        return "\n".join(parts)

    def _extract_metadata(self, record: dict) -> dict:
        """Extract metadata for filtering from a UHRI record.

        Args:
            record: Single UHRI record.

        Returns:
            Metadata dictionary for the Document.
        """
        return {
            "id": str(record.get("id", "")),
            "country": record.get("country", "Unknown"),
            "mechanism": record.get("mechanism", ""),
            "cycle": record.get("cycle", ""),
            "year": str(record.get("year", "")),
            "theme": record.get("theme", ""),
            "status": record.get("status", ""),
            "recommending_state": record.get("recommending_state", ""),
            "source": "UHRI",
        }


def create_document_loader(use_sample: bool = True) -> UHRIDocumentLoader:
    """Factory function to create a document loader.

    Args:
        use_sample: Whether to use sample data.

    Returns:
        Configured UHRIDocumentLoader instance.
    """
    return UHRIDocumentLoader(use_sample=use_sample)
