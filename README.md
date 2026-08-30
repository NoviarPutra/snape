# Snape - AI English Learning Companion

Snape is a private, single-user AI English companion designed for seamless conversation practice with **implicit Soft Correction**, long-term semantic vector memory on **Supabase Cloud (pgvector)**, and real-time Kyutai **Pocket-TTS** audio streaming.

## System Architecture

```design
                       ┌──────────────────────────────────────────────┐
                       │          Flutter Mobile Client               │
                       │  (Riverpod + Audio Queue + WebSocket Stream) │
                       └──────────────────────┬───────────────────────┘
                                              │  WebSocket (/ws/chat)
                                              ▼
                       ┌──────────────────────────────────────────────┐
                       │             FastAPI Backend                  │
                       │                                              │
                       │  - Dynamic Prompt Assembly                   │
                       │  - Soft Correction Injection                 │
                       │  - Sentence Boundary Chunker                 │
                       │  - Async Background Memory Extractor         │
                       └───────────┬──────────────────┬───────────────┘
                                   │                  │
               Vector Search & Mem │                  │ Token Stream
                                   ▼                  ▼
                    ┌─────────────────────────┐   ┌─────────────────────────┐
                    │ Supabase Cloud Postgres │   │ Google Gemini API       │
                    │ - pgvector (HNSW Index) │   │ (gemini-2.0-flash       │
                    │ - Chat Sessions         │   │  + text-embedding-004)  │
                    │ - Short-term Buffer (5) │   └─────────────────────────┘
                    │ - Semantic User Memory  │                │
                    └─────────────────────────┘                ▼
                                                  ┌─────────────────────────┐
                                                  │ Kyutai Pocket-TTS       │
                                                  │ - Sentence Audio Stream │
                                                  └─────────────────────────┘
```

## Core Features

1. **Implicit Soft Correction**: Snape never lectures or interrupts with pedantic grammar breakdowns. Slips in grammar, preposition, or word choice are smoothly reflected back with natural, correct phrasing.
2. **Long-Term Vector Memory (Supabase pgvector)**: Episodic details and user background facts are automatically extracted and embedded using `text-embedding-004` (768 dimensions), indexed with HNSW for fast cosine similarity search.
3. **Real-Time Streaming Audio (Pocket-TTS)**: Tokens stream over WebSocket while sentences are synthesized asynchronously using Kyutai Pocket-TTS for near-instant speech playback.
4. **Cloud Database / Lightweight Server**: Offloading storage to Supabase Cloud keeps the local/VPS footprint under ~1.0 GB RAM.

---

## Database Setup (Supabase Cloud)

The database schema and pgvector index are located at `snape_be/supabase/migrations/20260830000001_create_snape_schema.sql`.

To apply the schema:

- **Option 1**: Copy and paste the contents of `snape_be/supabase/migrations/20260830000001_create_snape_schema.sql` into the Supabase SQL Editor in your dashboard.
- **Option 2**: Configure `snape_be/.env` and run the migration script:

  ```bash
  python3 snape_be/scripts/apply_supabase_migration.py
  ```
