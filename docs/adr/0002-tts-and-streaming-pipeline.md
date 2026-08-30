# 2. Pocket-TTS Integration and Streaming Pipeline

Date: 2026-08-30

## Status
Accepted

## Context
The companion needs to speak responses aloud to reinforce English listening and pronunciation comprehension. The user requested integration of Kyutai Labs' `pocket-tts` (https://github.com/kyutai-labs/pocket-tts) running on a resource-constrained 2 vCPU / 2 GB RAM server.

## Decision
1. **Sentence Boundary Chunking**: As Gemini streams tokens, the backend accumulates tokens into sentence boundaries (punctuations: `.`, `!`, `?`, `\n`).
2. **Asynchronous Synthesis**: When a complete sentence is parsed, it is queued for TTS synthesis in a dedicated process/thread pool executor, preventing FastAPI event loop blocking.
3. **Pluggable TTS Architecture**: Implement a modular `BaseTTSProvider` interface. Default implementation utilizes `PocketTTSProvider` (invoking `pocket-tts` with selectable voice weights like `kyutai/pocket-tts` or lightweight models), with fallback to edge/mock provider if dependencies are not built on minimal environments.
4. **WebSocket Frame Protocol**:
   - `{"type": "token", "content": "..."}`: Real-time text token stream for instant UI rendering.
   - `{"type": "audio", "sentence": "...", "audio_base64": "...", "format": "wav"}`: Audio chunk for immediate playback in Flutter audio queue.
   - `{"type": "done", "session_id": "...", "extracted_memories": [...]}`: Notification when generation and background memory extraction conclude.

## Consequences
- Audio generation overlaps with LLM generation; user hears the first sentence within 1-2 seconds of speaking.
- CPU usage is bounded to one active synthesis worker at a time.
