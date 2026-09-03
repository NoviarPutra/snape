# CONTEXT.md

## Domain Vocabulary

- **User**: The single private individual learning English.
- **Companion**: The AI persona acting as a warm, casual, native English-speaking friend.
- **Space (Discussion Room)**: Themed container above Session defining AI persona configuration, response language, TTS availability, and Voice Call availability. Every Session is permanently bound to a single Space. MVP includes 4 Spaces: English Learning, Teknologi, Psikologi, and Produktivitas.
- **Level Sub-Room**: Sub-space within the English Learning Space determining AI linguistic complexity across 6 CEFR levels (A1, A2, B1, B2, C1, C2), represented as a `space_slug` with the `english_{level}` format (e.g. `english_b2`).
- **SpaceConfig**: Hardcoded per-Space configuration acting as the single source of truth for persona prompt, response language, TTS voice, and Obsidian materials path, defined in the backend as a static registry.
- **Space Slug**: Unique string identifier per Space or Level Sub-Room stored in `chat_sessions.space_slug` and used to resolve `SpaceConfig`.
- **Session**: A continuous interaction window or conversation thread.
- **Short-Term History**: The rolling buffer of recent messages (default: 5 messages) sent directly in context to the LLM.
- **Memory Item (Fact/Preference)**: Extracted atomic piece of long-term knowledge about the user (e.g., interests, goals, background), stored with semantic vector embeddings.
- **Soft Correction**: The implicit pedagogical technique where the Companion does not explicitly point out grammatical errors but naturally reflects the grammatically correct phrasing in conversational responses.
- **Bilingual Bridge (Adaptive Code-Switching)**: The Companion seamlessly understands input in English, Indonesian, or mixed code-switching without manual mode toggles, providing natural English bridges when the user is stuck and keeping the conversation predominantly in English.
- **Database / Memory Store**: PostgreSQL hosted on **Supabase Cloud** with `pgvector` extension enabled for both relational chat entities and HNSW vector similarity search.
- **LLM Provider (OmniRoute Gateway)**: OpenAI-compatible local AI gateway endpoint (`http://localhost:20128/v1`) running `antigravity/gemini-3.7-flash-high` for low-latency chat streaming and memory extraction.
- **Streaming Pipeline**: Low-latency token-by-token and audio chunk stream over WebSocket between FastAPI and the Flutter client.
- **TTS Synthesis**: Audio stream generation using Pocket-TTS (Kyutai) or modular voice providers from streamed text tokens.
- **Memory Extractor**: Asynchronous worker extracting episodic/semantic facts from user interactions without blocking live conversation.
