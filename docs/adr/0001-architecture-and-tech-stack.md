# 1. Architecture and Tech Stack for Snape AI Companion

Date: 2026-08-30

## Status

Accepted (Updated with Supabase Cloud)

## Context

We are designing a private, single-user AI English learning companion ("Snape") running on a budget VPS (2 vCPU, 2 GB RAM, Ubuntu) paired with a Flutter cross-platform mobile client and a managed Supabase Cloud backend.

Key requirements:

1. Offload database maintenance, backups, and storage to Supabase Cloud PostgreSQL.
2. Minimal VPS memory footprint (< 1.0 GB total active RAM on server).
3. Sub-second initial response latency.
4. Long-term semantic memory retrieval and non-blocking background memory extraction via `pgvector`.
5. Implicit "Soft Correction" teaching style (conversational reflection without pedantic lectures).
6. Real-time text and audio streaming over WebSockets.

## Decision

- **Database**: Managed **Supabase Cloud PostgreSQL 16** with native `pgvector` extension for combined relational chat storage and cosine vector similarity search (using HNSW index).
- **Backend**: Python 3.11+ with FastAPI, AsyncIO, and SQLAlchemy Async (`asyncpg`).
- **LLM & Provider**: OmniRoute Gateway (`http://localhost:20128/v1`, model `antigravity/gemini-3.7-flash-high`) via OpenAI-compatible SDK/client for low-latency chat token streaming and structured memory extraction.
- **Embeddings**: Sentence/Text embedding service for 768-dimensional semantic memory storage in `pgvector`.
- **TTS Engine**: Modular TTS service with native support for Kyutai `pocket-tts` (lightweight CPU-friendly neural TTS) with sentence-level streaming.
- **Client Protocol**: Full-duplex WebSocket connection (`/ws/chat/{session_id}`) delivering structured JSON control frames (tokens, status, metadata) and binary/base64 audio chunks.
- **Mobile Frontend**: Flutter app with `flutter_riverpod` state management, supporting real-time streaming text rendering and audio playback.

## Consequences

- **Positive**:
  - Offloading PostgreSQL and `pgvector` to Supabase Cloud saves precious VPS RAM and CPU.
  - Supabase Dashboard Studio allows easy manual inspection and management of user memories and chat sessions.
  - Native Supabase SQL migrations ensure declarative schema management.
- **Trade-offs**:
  - Requires network round-trip between VPS backend and Supabase Cloud, optimized via connection pooling.
