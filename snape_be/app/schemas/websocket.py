from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


# Inbound WebSocket Messages (Client -> Server)
class WSChatInput(BaseModel):
    type: Literal["chat"] = "chat"
    content: str = Field(..., min_length=1, description="Chat content from user")


class WSPingInput(BaseModel):
    type: Literal["ping"] = "ping"


WSInboundMessage = WSChatInput | WSPingInput


# Outbound WebSocket Messages (Server -> Client)
class WSTokenOutput(BaseModel):
    type: Literal["token"] = "token"
    content: str = Field(..., description="Token text chunk")


class WSAudioOutput(BaseModel):
    type: Literal["audio"] = "audio"
    sentence: str = Field(..., description="Synthesized sentence text")
    audio_base64: str = Field(..., description="Base64-encoded WAV audio data")
    format: str = Field(default="wav", description="Audio format")
    sample_rate: int = Field(default=24000, description="Audio sample rate in Hz")


class WSDoneOutput(BaseModel):
    type: Literal["done"] = "done"
    session_id: UUID = Field(..., description="Session identifier")
    user_message_id: UUID | None = Field(default=None, description="Persisted user message ID")
    assistant_message_id: UUID | None = Field(
        default=None, description="Persisted assistant message ID"
    )
    full_text: str = Field(..., description="Complete generated response text")
    extracted_memories: list[str] = Field(
        default_factory=list, description="Extracted episodic memories"
    )


class WSErrorOutput(BaseModel):
    type: Literal["error"] = "error"
    message: str = Field(..., description="Error message description")
    code: str | None = Field(default=None, description="Optional error code")


class WSPongOutput(BaseModel):
    type: Literal["pong"] = "pong"


WSOutboundMessage = WSTokenOutput | WSAudioOutput | WSDoneOutput | WSErrorOutput | WSPongOutput
