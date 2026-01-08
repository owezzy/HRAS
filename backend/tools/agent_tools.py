"""Agent tools for interacting with the UHRI data.

These tools are used by agents to search, retrieve, and analyze human rights data.
"""

from langchain_core.tools import tool

from vectorstore.store import get_vector_store


@tool
def search_recommendations(
    query: str,
    country: str | None = None,
    mechanism: str | None = None,
    theme: str | None = None,
    k: int = 5,
) -> list[dict]:
    """Search for human rights recommendations in the UHRI database.

    Use this tool to find relevant recommendations based on a query.
    You can optionally filter by country, mechanism, or theme.

    Args:
        query: Search query describing what recommendations to find.
        country: Optional country name to filter by (e.g., "Kenya", "Brazil").
        mechanism: Optional mechanism to filter by (e.g., "UPR", "CERD", "CAT").
        theme: Optional theme to filter by (e.g., "Torture", "Freedom of expression").
        k: Number of results to return (default 5).

    Returns:
        List of matching recommendations with metadata.
    """
    vector_store = get_vector_store()

    # Build filter
    filter_dict = {}
    if country:
        filter_dict["country"] = country
    if mechanism:
        filter_dict["mechanism"] = mechanism
    if theme:
        filter_dict["theme"] = theme

    # Search
    results = vector_store.similarity_search_with_score(
        query,
        k=k,
        filter=filter_dict if filter_dict else None,
    )

    # Format results
    formatted = []
    for doc, score in results:
        formatted.append({
            "content": doc.page_content,
            "country": doc.metadata.get("country", ""),
            "mechanism": doc.metadata.get("mechanism", ""),
            "year": doc.metadata.get("year", ""),
            "theme": doc.metadata.get("theme", ""),
            "status": doc.metadata.get("status", ""),
            "relevance_score": float(score),
        })

    return formatted


@tool
def get_country_recommendations(country: str, limit: int = 10) -> list[dict]:
    """Get all recommendations for a specific country.

    Use this tool when the user asks about a specific country's human rights situation.

    Args:
        country: Country name (e.g., "Kenya", "Brazil", "China").
        limit: Maximum number of recommendations to return.

    Returns:
        List of recommendations for the specified country.
    """
    vector_store = get_vector_store()

    # Search with country filter
    results = vector_store.similarity_search(
        f"human rights recommendations for {country}",
        k=limit,
        filter={"country": country},
    )

    formatted = []
    for doc in results:
        formatted.append({
            "content": doc.page_content,
            "mechanism": doc.metadata.get("mechanism", ""),
            "year": doc.metadata.get("year", ""),
            "theme": doc.metadata.get("theme", ""),
            "status": doc.metadata.get("status", ""),
        })

    return formatted


@tool
def compare_countries(countries: list[str], theme: str | None = None) -> dict:
    """Compare human rights situations across multiple countries.

    Use this tool when the user wants to compare recommendations or situations
    between two or more countries.

    Args:
        countries: List of country names to compare (e.g., ["Kenya", "Tanzania"]).
        theme: Optional theme to focus the comparison on.

    Returns:
        Dictionary with recommendations organized by country.
    """
    vector_store = get_vector_store()
    comparison = {}

    for country in countries:
        query = f"human rights {theme or 'recommendations'} for {country}"
        filter_dict = {"country": country}
        if theme:
            filter_dict["theme"] = theme

        results = vector_store.similarity_search(query, k=5, filter={"country": country})

        comparison[country] = []
        for doc in results:
            comparison[country].append({
                "mechanism": doc.metadata.get("mechanism", ""),
                "year": doc.metadata.get("year", ""),
                "theme": doc.metadata.get("theme", ""),
                "recommendation": doc.page_content,
                "status": doc.metadata.get("status", ""),
            })

    return comparison


@tool
def get_mechanism_overview(mechanism: str, limit: int = 10) -> list[dict]:
    """Get recommendations from a specific UN mechanism.

    Use this tool when the user asks about specific treaty bodies or mechanisms.

    Args:
        mechanism: The UN mechanism (e.g., "UPR", "CERD", "CAT", "CCPR", "CEDAW").
        limit: Maximum number of recommendations to return.

    Returns:
        List of recommendations from the specified mechanism.
    """
    vector_store = get_vector_store()

    results = vector_store.similarity_search(
        f"recommendations from {mechanism}",
        k=limit,
        filter={"mechanism": mechanism},
    )

    formatted = []
    for doc in results:
        formatted.append({
            "content": doc.page_content,
            "country": doc.metadata.get("country", ""),
            "year": doc.metadata.get("year", ""),
            "theme": doc.metadata.get("theme", ""),
            "status": doc.metadata.get("status", ""),
        })

    return formatted


# Export all tools for agent use
RESEARCH_TOOLS = [
    search_recommendations,
    get_country_recommendations,
    get_mechanism_overview,
]

COMPARE_TOOLS = [
    compare_countries,
    search_recommendations,
]

ALL_TOOLS = [
    search_recommendations,
    get_country_recommendations,
    compare_countries,
    get_mechanism_overview,
]
