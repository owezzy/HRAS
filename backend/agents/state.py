"""Agent state definitions for the multi-agent system.

Defines the shared state that flows through the LangGraph workflow.
"""

from typing import Annotated, Literal

from langchain_core.messages import BaseMessage
from langgraph.graph.message import add_messages
from pydantic import BaseModel, Field


class Source(BaseModel):
    """A source document reference."""

    country: str = ""
    mechanism: str = ""
    year: str = ""
    theme: str = ""
    status: str = ""
    snippet: str = ""
    relevance_score: float = 0.0


class AgentState(BaseModel):
    """Shared state for the multi-agent workflow.

    This state flows through all agents in the LangGraph.
    """

    # The user's original question
    question: str = Field(default="", description="The user's question")

    # Conversation history (LangGraph message accumulation)
    messages: Annotated[list[BaseMessage], add_messages] = Field(
        default_factory=list,
        description="Conversation message history",
    )

    # Retrieved documents and sources
    retrieved_docs: list[dict] = Field(
        default_factory=list,
        description="Documents retrieved from vector store",
    )
    sources: list[Source] = Field(
        default_factory=list,
        description="Formatted source citations",
    )

    # Agent routing
    next_agent: Literal["research", "advisory", "compare", "supervisor", "end"] = Field(
        default="supervisor",
        description="Next agent to route to",
    )
    query_type: Literal["research", "advisory", "compare", "general"] = Field(
        default="general",
        description="Classified type of user query",
    )

    # Context for specific agent tasks
    countries: list[str] = Field(
        default_factory=list,
        description="Countries mentioned in the query",
    )
    themes: list[str] = Field(
        default_factory=list,
        description="Human rights themes identified",
    )
    time_range: tuple[str, str] | None = Field(
        default=None,
        description="Time range for analysis (start_year, end_year)",
    )

    # Generated outputs
    research_summary: str = Field(
        default="",
        description="Summary from research agent",
    )
    advisory_response: str = Field(
        default="",
        description="Response from advisory agent",
    )
    comparison_result: str = Field(
        default="",
        description="Result from compare agent",
    )
    final_response: str = Field(
        default="",
        description="Final synthesized response to user",
    )

    # Error handling
    error: str | None = Field(
        default=None,
        description="Error message if something went wrong",
    )


class QueryClassification(BaseModel):
    """Result of classifying a user query."""

    query_type: Literal["research", "advisory", "compare", "general"]
    countries: list[str] = Field(default_factory=list)
    themes: list[str] = Field(default_factory=list)
    requires_comparison: bool = False
    reasoning: str = ""
