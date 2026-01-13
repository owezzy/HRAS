from src.app.repositories.conversation import ConversationRepository


class TestConversationRepository:
    async def test_create_conversation(self, db_session):
        repo = ConversationRepository(db_session)

        conversation = await repo.create(title="Test Conversation")

        assert conversation is not None
        assert conversation.id is not None
        assert conversation.title == "Test Conversation"
        assert conversation.created_at is not None
        assert conversation.updated_at is not None

    async def test_create_conversation_with_default_title(self, db_session):
        repo = ConversationRepository(db_session)

        conversation = await repo.create()

        assert conversation.title == "New Conversation"

    async def test_get_by_id_returns_conversation(self, db_session):
        repo = ConversationRepository(db_session)
        created = await repo.create(title="Findable")

        found = await repo.get_by_id(created.id)

        assert found is not None
        assert found.id == created.id
        assert found.title == "Findable"

    async def test_get_by_id_returns_none_for_missing(self, db_session):
        repo = ConversationRepository(db_session)

        found = await repo.get_by_id("nonexistent-id")

        assert found is None

    async def test_list_all_returns_conversations(self, db_session):
        repo = ConversationRepository(db_session)
        await repo.create(title="First")
        await repo.create(title="Second")
        await repo.create(title="Third")

        conversations = await repo.list_all()

        assert len(conversations) == 3

    async def test_list_all_respects_limit(self, db_session):
        repo = ConversationRepository(db_session)
        for i in range(5):
            await repo.create(title=f"Conv {i}")

        conversations = await repo.list_all(limit=2)

        assert len(conversations) == 2

    async def test_list_all_respects_offset(self, db_session):
        repo = ConversationRepository(db_session)
        for i in range(5):
            await repo.create(title=f"Conv {i}")

        conversations = await repo.list_all(offset=3)

        assert len(conversations) == 2

    async def test_delete_removes_conversation(self, db_session):
        repo = ConversationRepository(db_session)
        created = await repo.create(title="To Delete")

        deleted = await repo.delete(created.id)

        assert deleted is True
        assert await repo.get_by_id(created.id) is None

    async def test_delete_returns_false_for_missing(self, db_session):
        repo = ConversationRepository(db_session)

        deleted = await repo.delete("nonexistent-id")

        assert deleted is False

    async def test_add_message_creates_message(self, db_session):
        repo = ConversationRepository(db_session)
        conversation = await repo.create(title="With Messages")

        message = await repo.add_message(
            conversation_id=conversation.id,
            role="user",
            content="Hello, world!",
        )

        assert message is not None
        assert message.role == "user"
        assert message.content == "Hello, world!"

    async def test_add_message_with_sources(self, db_session):
        repo = ConversationRepository(db_session)
        conversation = await repo.create(title="With Sources")
        conv_id = conversation.id

        sources = [
            {
                "country": "Kenya",
                "mechanism": "UPR",
                "year": "2021",
                "theme": "Education",
                "status": "Pending",
                "snippet": "Test snippet",
            },
        ]
        message = await repo.add_message(
            conversation_id=conv_id,
            role="assistant",
            content="Response with sources",
            sources=sources,
        )

        assert message is not None
        db_session.expire_all()
        refreshed = await repo.get_by_id(conv_id)
        assert len(refreshed.messages) == 1
        assert len(refreshed.messages[0].sources) == 1
        assert refreshed.messages[0].sources[0].country == "Kenya"

    async def test_add_message_returns_none_for_missing_conversation(self, db_session):
        repo = ConversationRepository(db_session)

        message = await repo.add_message(
            conversation_id="nonexistent",
            role="user",
            content="Hello",
        )

        assert message is None

    async def test_update_title(self, db_session):
        repo = ConversationRepository(db_session)
        conversation = await repo.create(title="Original Title")

        updated = await repo.update_title(conversation.id, "New Title")

        assert updated is not None
        assert updated.title == "New Title"

    async def test_update_title_returns_none_for_missing(self, db_session):
        repo = ConversationRepository(db_session)

        updated = await repo.update_title("nonexistent", "New Title")

        assert updated is None

    async def test_conversation_messages_loaded_with_sources(self, db_session):
        repo = ConversationRepository(db_session)
        conversation = await repo.create(title="Full Test")
        conv_id = conversation.id

        await repo.add_message(conv_id, "user", "Question 1")
        await repo.add_message(
            conv_id,
            "assistant",
            "Answer 1",
            sources=[
                {
                    "country": "Brazil",
                    "mechanism": "CAT",
                    "year": "2020",
                    "theme": "Torture",
                    "status": "Implemented",
                    "snippet": "Snippet",
                }
            ],
        )
        await repo.add_message(conv_id, "user", "Question 2")

        db_session.expire_all()
        loaded = await repo.get_by_id(conv_id)

        assert len(loaded.messages) == 3
        assert loaded.messages[0].role == "user"
        assert loaded.messages[1].role == "assistant"
        assert len(loaded.messages[1].sources) == 1
        assert loaded.messages[2].role == "user"
