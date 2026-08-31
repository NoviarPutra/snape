import base64
from collections.abc import AsyncGenerator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.chat_ws import get_chat_pipeline
from app.core.config import settings
from app.db.session import get_db
from app.main import create_app
from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import ChatPipeline
from app.services.llm_service import MockLLMService


@pytest.fixture
def ws_app(db_session: AsyncSession) -> TestClient:
    app = create_app()

    # Override get_db to use db_session
    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_chat_pipeline] = lambda: ChatPipeline(
        llm_service=MockLLMService()
    )
    return TestClient(app)


@pytest.mark.asyncio
async def test_websocket_chat_turn(ws_app: TestClient, db_session: AsyncSession) -> None:
    # 1. Prepare user and session in db
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="WebSocket Chat Test"),
    )
    await db_session.commit()

    # 2. Connect to WebSocket
    with ws_app.websocket_connect(f"/ws/chat/{session.id}") as websocket:
        # Ping - Pong test
        websocket.send_json({"type": "ping"})
        pong_response = websocket.receive_json()
        assert pong_response["type"] == "pong"

        # Chat message turn
        websocket.send_json({"type": "chat", "content": "Yesterday I go to market"})

        tokens = []
        audio_events = []
        done_payload = None

        while True:
            msg = websocket.receive_json()
            if msg["type"] == "token":
                tokens.append(msg["content"])
            elif msg["type"] == "audio":
                audio_events.append(msg)
            elif msg["type"] == "done":
                done_payload = msg
                break
            elif msg["type"] == "error":
                pytest.fail(f"Received unexpected error frame: {msg}")

        assert len(tokens) > 0
        assert done_payload is not None
        assert done_payload["session_id"] == str(session.id)
        assert done_payload["full_text"] == "".join(tokens)
        assert done_payload["user_message_id"] is not None
        assert done_payload["assistant_message_id"] is not None

        if settings.ENABLE_TTS:
            assert len(audio_events) >= 1
            audio_frame = audio_events[0]
            assert "sentence" in audio_frame
            assert "audio_base64" in audio_frame
            assert audio_frame["sample_rate"] == 24000
            decoded_audio = base64.b64decode(audio_frame["audio_base64"])
            assert len(decoded_audio) > 0


@pytest.mark.asyncio
async def test_websocket_invalid_session(ws_app: TestClient) -> None:
    random_session_id = uuid4()
    with ws_app.websocket_connect(f"/ws/chat/{random_session_id}") as websocket:
        websocket.send_json({"type": "chat", "content": "Hello"})
        msg = websocket.receive_json()
        assert msg["type"] == "error"
        assert "Session not found" in msg["message"]


@pytest.mark.asyncio
async def test_websocket_invalid_format(ws_app: TestClient, db_session: AsyncSession) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Format Test"),
    )
    await db_session.commit()

    with ws_app.websocket_connect(f"/ws/chat/{session.id}") as websocket:
        websocket.send_text("not a valid json")
        msg = websocket.receive_json()
        assert msg["type"] == "error"
        assert msg["code"] == "INVALID_JSON"
