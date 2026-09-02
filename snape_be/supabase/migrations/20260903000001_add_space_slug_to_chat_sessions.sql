-- Add space_slug column to chat_sessions table
ALTER TABLE public.chat_sessions
ADD COLUMN IF NOT EXISTS space_slug VARCHAR(32) NOT NULL DEFAULT 'english_b2';

-- Add index on space_slug for efficient filtering
CREATE INDEX IF NOT EXISTS ix_chat_sessions_space_slug ON public.chat_sessions (space_slug);
