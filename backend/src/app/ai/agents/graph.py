"""LangGraph workflow for the multi-agent HR advisory system.

Implements the supervisor pattern with routing to specialized agents.
"""

import json
import re
import time

from langchain_core.messages import HumanMessage
from langgraph.graph import END, StateGraph

from src.app.ai.agents.nodes import advisory_agent, compare_agent, research_agent
from src.app.ai.agents.state import AgentState
from src.app.core.instrumentation import instrumented_llm_invoke
from src.app.core.llm import get_deterministic_llm
from src.app.core.logging import ai_logger, get_logger
from src.app.core.metrics import (
    AGENT_EXECUTION_DURATION_SECONDS,
    AGENT_EXECUTIONS_TOTAL,
    AGENT_STEPS_TOTAL,
    ERRORS_TOTAL,
)

logger = get_logger(__name__)

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


def _extract_json_from_response(content: str | list) -> dict | None:
    """Extract JSON object from LLM response content."""
    if isinstance(content, list):
        content = " ".join(str(item) for item in content)

    text = str(content)

    match = re.search(r"\{[^{}]*\}", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


async def supervisor_node(state: AgentState) -> AgentState:
    """Supervisor node: classifies the query and routes to appropriate agent."""
    llm = get_deterministic_llm()

    prompt = f"""{SUPERVISOR_SYSTEM_PROMPT}

User Question: {state.question}

Classify this query:"""

    response = await instrumented_llm_invoke(llm, [HumanMessage(content=prompt)])

    classification = _extract_json_from_response(response.content)

    if classification:
        state.query_type = classification.get("query_type", "research")
        state.countries = classification.get("countries", [])
        state.themes = classification.get("themes", [])

        if classification.get("requires_comparison") or state.query_type == "compare":
            state.next_agent = "compare"
        elif state.query_type == "advisory":
            state.next_agent = "advisory"
        else:
            state.next_agent = "research"
    else:
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
    initial_state = AgentState(question=question)

    start_time = time.perf_counter()
    steps_count = 0

    try:
        final_state = await graph.ainvoke(initial_state)

        steps_count = _count_workflow_steps(final_state)
        agent_name = final_state.get("query_type", "workflow")
        duration = time.perf_counter() - start_time

        AGENT_EXECUTIONS_TOTAL.labels(agent_name=agent_name, status="success").inc()
        AGENT_EXECUTION_DURATION_SECONDS.labels(agent_name=agent_name).observe(duration)
        AGENT_STEPS_TOTAL.labels(agent_name=agent_name, step_type="completed").inc(steps_count)

        ai_logger.log_agent_execution(
            agent_name=agent_name,
            execution_time_ms=duration * 1000,
            steps_count=steps_count,
            success=True,
        )

        return {
            "answer": final_state.get("final_response", ""),
            "sources": [s.model_dump() for s in final_state.get("sources", [])],
            "query_type": final_state.get("query_type", "general"),
            "research_summary": final_state.get("research_summary", ""),
        }
    except Exception as e:
        duration = time.perf_counter() - start_time

        AGENT_EXECUTIONS_TOTAL.labels(agent_name="workflow", status="error").inc()
        AGENT_EXECUTION_DURATION_SECONDS.labels(agent_name="workflow").observe(duration)
        ERRORS_TOTAL.labels(error_type="agent_workflow", component="agents.graph").inc()

        ai_logger.log_agent_execution(
            agent_name="workflow",
            execution_time_ms=duration * 1000,
            steps_count=steps_count,
            success=False,
            error=str(e),
        )
        logger.error("agent_workflow_failed", error=str(e), duration_s=duration)
        raise


def _count_workflow_steps(state: dict) -> int:
    steps = 1
    if state.get("research_summary"):
        steps += 1
    if state.get("final_response"):
        steps += 1
    return steps
