"""LangGraph workflow for the multi-agent HR advisory system.

Implements the supervisor pattern with routing to specialized agents.
"""

from langchain_core.language_models import BaseChatModel
from langchain_core.messages import HumanMessage
from langgraph.graph import END, StateGraph

from agents.nodes import advisory_agent, compare_agent, research_agent
from agents.state import AgentState
from src.app.core.config import get_settings

SUPERVISOR_SYSTEM_PROMPT = """You are a supervisor agent that routes human rights queries to specialized agents.

Analyze the user's question and classify it:

1. **research** - Factual questions about recommendations, documents, or situations
   - "What recommendations exist for Kenya?"
   - "Tell me about UPR recommendations on torture"
   - "What did CERD say about discrimination?"

2. **compare** - Questions comparing countries or analyzing patterns
   - "Compare human rights in Kenya and Tanzania"
   - "How do recommendations differ between Brazil and Mexico?"
   - "What are the common themes across African countries?"

3. **advisory** - Questions seeking guidance or synthesis (DIRECT TO ADVISORY)
   - "What should we focus on for the upcoming review?"
   - "Summarize the key concerns"
   - Simple greetings or general questions

Also extract:
- Countries mentioned (if any)
- Themes mentioned (e.g., torture, discrimination, freedom of expression)

Respond in JSON format:
{
  "query_type": "research" | "compare" | "advisory",
  "countries": ["country1", "country2"],
  "themes": ["theme1", "theme2"],
  "requires_comparison": true | false,
  "reasoning": "Brief explanation of classification"
}"""


def get_llm() -> BaseChatModel:
    """Get the configured Ollama LLM instance."""
    settings = get_settings()
    from langchain_ollama import ChatOllama

    return ChatOllama(
        base_url=settings.ollama_base_url,
        model=settings.ollama_model,
        temperature=0,
    )


async def supervisor_node(state: AgentState) -> AgentState:
    """Supervisor node: classifies the query and routes to appropriate agent."""
    llm = get_llm()

    prompt = f"""{SUPERVISOR_SYSTEM_PROMPT}

User Question: {state.question}

Classify this query:"""

    response = await llm.ainvoke([HumanMessage(content=prompt)])

    # Parse the response
    try:
        import json
        # Extract JSON from response
        content = response.content
        # Find JSON in the response
        start = content.find("{")
        end = content.rfind("}") + 1
        if start != -1 and end > start:
            json_str = content[start:end]
            classification = json.loads(json_str)

            state.query_type = classification.get("query_type", "research")
            state.countries = classification.get("countries", [])
            state.themes = classification.get("themes", [])

            # Route based on classification
            if classification.get("requires_comparison") or state.query_type == "compare":
                state.next_agent = "compare"
            elif state.query_type == "advisory":
                state.next_agent = "advisory"
            else:
                state.next_agent = "research"
        else:
            # Default to research if parsing fails
            state.next_agent = "research"

    except (json.JSONDecodeError, KeyError):
        # Default to research on parse error
        state.next_agent = "research"

    return state


def route_to_agent(state: AgentState) -> str:
    """Routing function based on supervisor's decision."""
    return state.next_agent


def build_graph() -> StateGraph:
    """Build the multi-agent LangGraph workflow."""
    # Create the graph
    workflow = StateGraph(AgentState)

    # Add nodes
    workflow.add_node("supervisor", supervisor_node)
    workflow.add_node("research", research_agent)
    workflow.add_node("advisory", advisory_agent)
    workflow.add_node("compare", compare_agent)

    # Set entry point
    workflow.set_entry_point("supervisor")

    # Add conditional edges from supervisor
    workflow.add_conditional_edges(
        "supervisor",
        route_to_agent,
        {
            "research": "research",
            "advisory": "advisory",
            "compare": "compare",
        },
    )

    # Research agent routes to advisory
    workflow.add_conditional_edges(
        "research",
        route_to_agent,
        {
            "advisory": "advisory",
            "end": END,
        },
    )

    # Compare agent routes to advisory
    workflow.add_conditional_edges(
        "compare",
        route_to_agent,
        {
            "advisory": "advisory",
            "end": END,
        },
    )

    # Advisory agent ends the workflow
    workflow.add_conditional_edges(
        "advisory",
        route_to_agent,
        {
            "end": END,
        },
    )

    return workflow


# Compile the graph
_compiled_graph = None


def get_agent_graph():
    """Get the compiled agent graph (singleton)."""
    global _compiled_graph
    if _compiled_graph is None:
        workflow = build_graph()
        _compiled_graph = workflow.compile()
    return _compiled_graph


async def run_agent_workflow(question: str) -> dict:
    """Run the multi-agent workflow for a question.

    Args:
        question: The user's question.

    Returns:
        Dictionary with response and sources.
    """
    graph = get_agent_graph()

    # Initialize state
    initial_state = AgentState(question=question)

    # Run the graph
    final_state = await graph.ainvoke(initial_state)

    # Format response
    return {
        "answer": final_state.get("final_response", ""),
        "sources": [s.model_dump() for s in final_state.get("sources", [])],
        "query_type": final_state.get("query_type", "general"),
        "research_summary": final_state.get("research_summary", ""),
    }
