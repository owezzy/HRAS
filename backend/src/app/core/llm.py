from functools import lru_cache

from langchain_core.language_models import BaseChatModel
from langchain_ollama import ChatOllama

from src.app.core.config import get_settings


@lru_cache
def get_llm(temperature: float = 0.1) -> BaseChatModel:
    settings = get_settings()
    return ChatOllama(
        base_url=settings.ollama_base_url,
        model=settings.ollama_model,
        temperature=temperature,
    )


def get_deterministic_llm() -> BaseChatModel:
    return get_llm(temperature=0.0)


def get_creative_llm() -> BaseChatModel:
    return get_llm(temperature=0.7)
