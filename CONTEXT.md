# CONTEXT.md

## Domain Vocabulary

- **User**: The single private individual learning English.
- **Companion**: The AI persona acting as a warm, casual, native English-speaking friend.
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
