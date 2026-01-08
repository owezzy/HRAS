"""Individual agent node implementations.

Each agent is a specialized node in the LangGraph workflow.
"""

from langchain_core.messages import AIMessage, HumanMessage
from langchain_ollama import ChatOllama

from agents.state import AgentState, Source
from src.app.core.config import get_settings
from tools.agent_tools import compare_countries, get_country_recommendations, search_recommendations


def get_llm() -> ChatOllama:
    """Get the configured LLM instance."""
    settings = get_settings()
    return ChatOllama(
        base_url=settings.ollama_base_url,
        model=settings.ollama_model,
        temperature=0.1,
    )


# ============================================================================
# RESEARCH AGENT
# ============================================================================

RESEARCH_SYSTEM_PROMPT = """You are a Research Agent specializing in UN human rights documentation.

Your role is to:
1. Search the UHRI database for relevant recommendations
2. Identify key patterns and themes in the data
3. Summarize findings clearly and accurately

Guidelines:
- Always cite your sources with country, mechanism, and year
- Be thorough but concise
- Highlight the most relevant recommendations
- Note any gaps or limitations in the available data

Based on the search results provided, create a research summary."""


async def research_agent(state: AgentState) -> AgentState:
    """Research agent: searches and summarizes UHRI data.

    This agent is called when the user needs factual information
    about human rights recommendations.
    """
    llm = get_llm()

    # Use tools to search for relevant data
    search_results = []

    # Search based on the question
    results = search_recommendations.invoke({
        "query": state.question,
        "k": 8,
    })
    search_results.extend(results)

    # If specific countries mentioned, search those too
    for country in state.countries[:3]:  # Limit to 3 countries
        country_results = get_country_recommendations.invoke({
            "country": country,
            "limit": 5,
        })
        search_results.extend(country_results)

    # Store retrieved docs in state
    state.retrieved_docs = search_results

    # Format sources
    sources = []
    for result in search_results[:10]:  # Limit sources
        sources.append(Source(
            country=result.get("country", ""),
            mechanism=result.get("mechanism", ""),
            year=result.get("year", ""),
            theme=result.get("theme", ""),
            status=result.get("status", ""),
            snippet=result.get("content", "")[:200],
            relevance_score=result.get("relevance_score", 0.0),
        ))
    state.sources = sources

    # Generate research summary
    context = "\n\n".join([
        f"[{r.get('country', 'N/A')} - {r.get('mechanism', 'N/A')} ({r.get('year', 'N/A')})]\n{r.get('content', '')}"
        for r in search_results[:8]
    ])

    prompt = f"""{RESEARCH_SYSTEM_PROMPT}

User Question: {state.question}

Search Results:
{context}

Provide a research summary of the relevant findings:"""

    response = await llm.ainvoke([HumanMessage(content=prompt)])
    state.research_summary = response.content
    state.messages.append(AIMessage(content=f"[Research Agent] {response.content}"))

    # Route to advisory for final response
    state.next_agent = "advisory"
    return state


# ============================================================================
# ADVISORY AGENT
# ============================================================================

ADVISORY_SYSTEM_PROMPT = """You are an Advisory Agent for UN human rights officers.

Your role is to:
1. Provide clear, actionable advice based on research findings
2. Cite specific recommendations with proper attribution
3. Present information in a professional, diplomatic manner
4. Suggest next steps or areas requiring attention

Guidelines:
- Use formal UN-style language
- Always reference the source mechanism (UPR, Treaty Body, etc.)
- Present balanced, objective assessments
- Acknowledge limitations in available information"""


async def advisory_agent(state: AgentState) -> AgentState:
    """Advisory agent: generates professional recommendations.

    This agent synthesizes research findings into actionable advice.
    """
    llm = get_llm()

    # Build context from research
    sources_context = "\n".join([
        f"- {s.country} ({s.mechanism}, {s.year}): {s.snippet}..."
        for s in state.sources[:5]
    ])

    prompt = f"""{ADVISORY_SYSTEM_PROMPT}

User Question: {state.question}

Research Summary:
{state.research_summary}

Available Sources:
{sources_context}

Provide a comprehensive advisory response that:
1. Directly answers the user's question
2. Cites relevant recommendations
3. Offers professional guidance
4. Notes any important caveats or limitations"""

    response = await llm.ainvoke([HumanMessage(content=prompt)])
    state.advisory_response = response.content
    state.messages.append(AIMessage(content=f"[Advisory Agent] {response.content}"))

    # This is typically the final agent
    state.final_response = response.content
    state.next_agent = "end"
    return state


# ============================================================================
# COMPARE AGENT
# ============================================================================

COMPARE_SYSTEM_PROMPT = """You are a Compare Agent specializing in cross-country human rights analysis.

Your role is to:
1. Compare human rights situations across multiple countries
2. Identify similarities and differences in recommendations
3. Highlight regional patterns or trends
4. Provide objective, balanced comparisons

Guidelines:
- Present comparisons in a structured format
- Use tables or bullet points for clarity
- Note the mechanisms and years of each recommendation
- Avoid value judgments - present the data objectively"""


async def compare_agent(state: AgentState) -> AgentState:
    """Compare agent: performs cross-country analysis.

    This agent is called when the user wants to compare
    multiple countries or analyze patterns.
    """
    llm = get_llm()

    # If we have countries to compare, use the compare tool
    comparison_data = {}
    if len(state.countries) >= 2:
        comparison_data = compare_countries.invoke({
            "countries": state.countries[:4],  # Limit to 4 countries
            "theme": state.themes[0] if state.themes else None,
        })
    else:
        # Search for comparison-relevant data
        results = search_recommendations.invoke({
            "query": state.question,
            "k": 10,
        })
        # Group by country
        for r in results:
            country = r.get("country", "Unknown")
            if country not in comparison_data:
                comparison_data[country] = []
            comparison_data[country].append(r)

    # Format comparison context
    comparison_context = ""
    for country, recs in comparison_data.items():
        comparison_context += f"\n## {country}\n"
        for rec in recs[:3]:
            if isinstance(rec, dict):
                comparison_context += f"- [{rec.get('mechanism', 'N/A')}, {rec.get('year', 'N/A')}] {rec.get('recommendation', rec.get('content', ''))[:150]}...\n"

    prompt = f"""{COMPARE_SYSTEM_PROMPT}

User Question: {state.question}

Comparison Data:
{comparison_context}

Provide a structured comparison analysis:"""

    response = await llm.ainvoke([HumanMessage(content=prompt)])
    state.comparison_result = response.content
    state.messages.append(AIMessage(content=f"[Compare Agent] {response.content}"))

    # Route to advisory for final synthesis
    state.next_agent = "advisory"
    return state
