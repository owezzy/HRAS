from functools import lru_cache

from langchain_core.language_models import BaseChatModel
from langchain_openai import ChatOpenAI

from src.app.core.config import get_settings


@lru_cache
def get_llm(temperature: float = 0.1) -> BaseChatModel:
    settings = get_settings()
    return ChatOpenAI(
        base_url=settings.resolved_llm_base_url,
        api_key=settings.resolved_llm_api_key,
        model=settings.resolved_llm_model,
        temperature=temperature,
        timeout=settings.llm_timeout,
        max_retries=settings.llm_max_retries,
    )


def get_deterministic_llm() -> BaseChatModel:
    return get_llm(temperature=0.0)


def get_creative_llm() -> BaseChatModel:
    return get_llm(temperature=0.7)
