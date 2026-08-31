import json
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.websocket import (
    WSAudioOutput,
    WSChatInput,
    WSDoneOutput,
    WSErrorOutput,
    WSPongOutput,
    WSTokenOutput,
)
from app.services.chat_pipeline import (
    ChatPipeline,
    StreamAudioEvent,
    StreamDoneEvent,
    StreamTokenEvent,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["WebSocket"])


def get_chat_pipeline() -> ChatPipeline:
    """Dependency provider returning ChatPipeline instance."""
    return ChatPipeline()


@router.websocket("/ws/chat/{session_id}")
async def chat_websocket_endpoint(
    websocket: WebSocket,
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    pipeline: ChatPipeline = Depends(get_chat_pipeline),
) -> None:
    """WebSocket endpoint handling real-time bi-directional chat streaming."""
    await websocket.accept()

    try:
        while True:
            raw_text = await websocket.receive_text()

            # Parse JSON message
            try:
                data = json.loads(raw_text)
            except json.JSONDecodeError:
                await websocket.send_json(
                    WSErrorOutput(
                        message="Invalid JSON format",
                        code="INVALID_JSON",
                    ).model_dump()
                )
                continue

            msg_type = data.get("type")

            # Handle Ping
            if msg_type == "ping":
                await websocket.send_json(WSPongOutput().model_dump())
                continue

            # Handle Chat
            if msg_type == "chat":
                try:
                    chat_in = WSChatInput.model_validate(data)
                except ValidationError as val_err:
                    await websocket.send_json(
                        WSErrorOutput(
                            message=f"Validation error: {val_err.errors()}",
                            code="VALIDATION_ERROR",
                        ).model_dump()
                    )
                    continue

                try:
                    async for event in pipeline.stream_turn(
                        db=db,
                        session_id=session_id,
                        user_content=chat_in.content,
                    ):
                        if isinstance(event, StreamTokenEvent):
                            token_msg = WSTokenOutput(content=event.content)
                            await websocket.send_json(token_msg.model_dump())
                        elif isinstance(event, StreamAudioEvent):
                            audio_msg = WSAudioOutput(
                                sentence=event.sentence,
                                audio_base64=event.audio_base64,
                                format=event.format,
                                sample_rate=event.sample_rate,
                            )
                            await websocket.send_json(audio_msg.model_dump())
                        elif isinstance(event, StreamDoneEvent):
                            done_msg = WSDoneOutput(
                                session_id=event.session_id,
                                user_message_id=event.user_message_id,
                                assistant_message_id=event.assistant_message_id,
                                full_text=event.full_text,
                                extracted_memories=event.extracted_memories,
                            )
                            await websocket.send_json(done_msg.model_dump(mode="json"))
                except ValueError as err:
                    await websocket.send_json(
                        WSErrorOutput(
                            message=str(err),
                            code="NOT_FOUND",
                        ).model_dump()
                    )
                except Exception as err:
                    logger.exception("Error during chat streaming turn: %s", err)
                    await websocket.send_json(
                        WSErrorOutput(
                            message=f"Streaming error: {err}",
                            code="STREAMING_ERROR",
                        ).model_dump()
                    )
                continue

            # Unknown message type
            await websocket.send_json(
                WSErrorOutput(
                    message=f"Unsupported message type '{msg_type}'",
                    code="UNSUPPORTED_TYPE",
                ).model_dump()
            )

    except WebSocketDisconnect:
        logger.info("WebSocket client disconnected: session_id=%s", session_id)
    except Exception as exc:
        logger.exception("Unexpected error in WebSocket connection: %s", exc)
