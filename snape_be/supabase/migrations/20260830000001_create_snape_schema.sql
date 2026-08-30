-- Enable vector and uuid extensions
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- Users table (Single-learner profile)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(64) UNIQUE NOT NULL,
    full_name VARCHAR(128),
    native_language VARCHAR(64) DEFAULT 'Indonesian',
    english_level VARCHAR(32) DEFAULT 'Intermediate',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Chat Sessions
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL DEFAULT 'Casual English Chat',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Chat Messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    role VARCHAR(16) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    audio_path VARCHAR(512),
    meta_info JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- User Long-term Memories
CREATE TABLE IF NOT EXISTS public.user_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category VARCHAR(64) NOT NULL DEFAULT 'fact',
    content TEXT NOT NULL,
    embedding vector(768) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS ix_chat_sessions_user_id ON public.chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS ix_chat_messages_session_id_created ON public.chat_messages(session_id, created_at ASC);
CREATE INDEX IF NOT EXISTS ix_user_memories_user_id ON public.user_memories(user_id);

-- HNSW Vector Cosine Index for pgvector
CREATE INDEX IF NOT EXISTS ix_user_memories_embedding_hnsw 
ON public.user_memories 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- RPC function for semantic memory retrieval
CREATE OR REPLACE FUNCTION match_memories (
    query_embedding vector(768),
    match_threshold float,
    match_count int,
    p_user_id uuid
)
RETURNS TABLE (
    id uuid,
    category varchar,
    content text,
    similarity float,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        um.id,
        um.category,
        um.content,
        (1 - (um.embedding <=> query_embedding))::float AS similarity,
        um.created_at
    FROM public.user_memories um
    WHERE um.user_id = p_user_id
      AND (1 - (um.embedding <=> query_embedding)) >= match_threshold
    ORDER BY um.embedding <=> query_embedding ASC
    LIMIT match_count;
END;
$$;
