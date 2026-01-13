import time
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.app.core.logging import get_logger
from src.app.core.metrics import (
    CONVERSATIONS_TOTAL,
    DB_OPERATION_DURATION_SECONDS,
    DB_OPERATIONS_TOTAL,
    ERRORS_TOTAL,
)
from src.app.models.conversation import Conversation, Message, MessageSource

logger = get_logger(__name__)


class ConversationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, title: str = "New Conversation") -> Conversation:
        start_time = time.perf_counter()
        try:
            conversation = Conversation(title=title)
            self._session.add(conversation)
            await self._session.flush()

            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="create", table="conversations", status="success").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="create", table="conversations").observe(duration)
            CONVERSATIONS_TOTAL.inc()
            logger.info("conversation_created", conversation_id=conversation.id, duration_s=duration)
            return conversation
        except Exception as e:
            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="create", table="conversations", status="error").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="create", table="conversations").observe(duration)
            ERRORS_TOTAL.labels(error_type="db_create", component="conversation_repository").inc()
            logger.error("conversation_create_failed", error=str(e), duration_s=duration)
            raise

    async def get_by_id(self, conversation_id: str) -> Conversation | None:
        start_time = time.perf_counter()
        try:
            stmt = (
                select(Conversation)
                .where(Conversation.id == conversation_id)
                .options(selectinload(Conversation.messages).selectinload(Message.sources))
            )
            result = await self._session.execute(stmt)
            conversation = result.scalar_one_or_none()

            duration = time.perf_counter() - start_time
            status = "success" if conversation else "not_found"
            DB_OPERATIONS_TOTAL.labels(operation="get", table="conversations", status=status).inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="get", table="conversations").observe(duration)
            return conversation
        except Exception as e:
            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="get", table="conversations", status="error").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="get", table="conversations").observe(duration)
            ERRORS_TOTAL.labels(error_type="db_get", component="conversation_repository").inc()
            logger.error("conversation_get_failed", conversation_id=conversation_id, error=str(e))
            raise

    async def list_all(self, limit: int = 50, offset: int = 0) -> list[Conversation]:
        start_time = time.perf_counter()
        try:
            stmt = select(Conversation).order_by(Conversation.updated_at.desc()).limit(limit).offset(offset)
            result = await self._session.execute(stmt)
            conversations = list(result.scalars().all())

            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="list", table="conversations", status="success").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="list", table="conversations").observe(duration)
            return conversations
        except Exception as e:
            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="list", table="conversations", status="error").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="list", table="conversations").observe(duration)
            ERRORS_TOTAL.labels(error_type="db_list", component="conversation_repository").inc()
            logger.error("conversation_list_failed", error=str(e))
            raise

    async def delete(self, conversation_id: str) -> bool:
        start_time = time.perf_counter()
        try:
            conversation = await self.get_by_id(conversation_id)
            if conversation is None:
                duration = time.perf_counter() - start_time
                DB_OPERATIONS_TOTAL.labels(operation="delete", table="conversations", status="not_found").inc()
                DB_OPERATION_DURATION_SECONDS.labels(operation="delete", table="conversations").observe(duration)
                return False

            await self._session.delete(conversation)
            await self._session.flush()

            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="delete", table="conversations", status="success").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="delete", table="conversations").observe(duration)
            CONVERSATIONS_TOTAL.dec()
            logger.info("conversation_deleted", conversation_id=conversation_id, duration_s=duration)
            return True
        except Exception as e:
            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="delete", table="conversations", status="error").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="delete", table="conversations").observe(duration)
            ERRORS_TOTAL.labels(error_type="db_delete", component="conversation_repository").inc()
            logger.error("conversation_delete_failed", conversation_id=conversation_id, error=str(e))
            raise

    async def add_message(
        self,
        conversation_id: str,
        role: str,
        content: str,
        sources: list[dict[str, Any]] | None = None,
    ) -> Message | None:
        start_time = time.perf_counter()
        try:
            conversation = await self.get_by_id(conversation_id)
            if conversation is None:
                duration = time.perf_counter() - start_time
                DB_OPERATIONS_TOTAL.labels(operation="create", table="messages", status="not_found").inc()
                DB_OPERATION_DURATION_SECONDS.labels(operation="create", table="messages").observe(duration)
                return None

            message = Message(
                conversation_id=conversation_id,
                role=role,
                content=content,
            )
            self._session.add(message)
            await self._session.flush()

            if sources:
                for source_data in sources:
                    source = MessageSource(
                        message_id=message.id,
                        country=source_data.get("country", ""),
                        mechanism=source_data.get("mechanism", ""),
                        year=source_data.get("year", ""),
                        theme=source_data.get("theme", ""),
                        status=source_data.get("status", ""),
                        snippet=source_data.get("snippet", ""),
                    )
                    self._session.add(source)
                await self._session.flush()

            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="create", table="messages", status="success").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="create", table="messages").observe(duration)
            return message
        except Exception as e:
            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="create", table="messages", status="error").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="create", table="messages").observe(duration)
            ERRORS_TOTAL.labels(error_type="db_create_message", component="conversation_repository").inc()
            logger.error("message_create_failed", conversation_id=conversation_id, error=str(e))
            raise

    async def update_title(self, conversation_id: str, title: str) -> Conversation | None:
        start_time = time.perf_counter()
        try:
            conversation = await self.get_by_id(conversation_id)
            if conversation is None:
                duration = time.perf_counter() - start_time
                DB_OPERATIONS_TOTAL.labels(operation="update", table="conversations", status="not_found").inc()
                DB_OPERATION_DURATION_SECONDS.labels(operation="update", table="conversations").observe(duration)
                return None

            conversation.title = title
            await self._session.flush()

            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="update", table="conversations", status="success").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="update", table="conversations").observe(duration)
            logger.info("conversation_title_updated", conversation_id=conversation_id, duration_s=duration)
            return conversation
        except Exception as e:
            duration = time.perf_counter() - start_time
            DB_OPERATIONS_TOTAL.labels(operation="update", table="conversations", status="error").inc()
            DB_OPERATION_DURATION_SECONDS.labels(operation="update", table="conversations").observe(duration)
            ERRORS_TOTAL.labels(error_type="db_update", component="conversation_repository").inc()
            logger.error("conversation_update_failed", conversation_id=conversation_id, error=str(e))
            raise
