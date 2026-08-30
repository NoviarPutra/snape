# 3. Supabase Cloud Integration and Database Schema

Date: 2026-08-30

## Status
Accepted

## Context
The storage layer for user profiles, conversation threads, chat message logs, and long-term vector memories will be hosted on Supabase Cloud.

## Decision
1. **Connection Strategy**:
   - The FastAPI backend connects directly to Supabase Cloud on Port 5432 using `asyncpg` / `SQLAlchemy` with SSL (`ssl=require`).
   - Connection string format:
     `postgresql+asyncpg://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres?ssl=require`
2. **Schema & Indexing**:
   - Enable `pgvector` extension in the `public` schema.
   - Use HNSW (`vector_cosine_ops`) index for approximate nearest neighbor search on the `user_memories` table:
     `CREATE INDEX ix_user_memories_embedding_hnsw ON public.user_memories USING hnsw (embedding vector_cosine_ops);`
   - Store 768-dimensional vectors corresponding to Gemini's `text-embedding-004` model.
3. **Database Migration Management**:
   - Maintain SQL migrations in `snape_be/supabase/migrations/` to allow seamless deployment via Supabase CLI or SQL Runner.
4. **Pedagogical and Memory Integrity**:
   - User memories are categorized as `fact`, `preference`, `goal`, or `experience`.
   - Cosine similarity matching retrieves top relevant memories prior to LLM turn assembly.

## Consequences
- Clean separation of compute (FastAPI + Pocket-TTS) and data persistence (Supabase Cloud).
- Automatic database high availability and backups managed by Supabase.
