-- Create trending_articles table for Hermes News Orchestrator
CREATE TABLE IF NOT EXISTS public.trending_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(32) NOT NULL CHECK (category IN ('politics', 'general', 'music', 'creator_trends')),
    title VARCHAR(255) NOT NULL,
    summary TEXT NOT NULL,
    source_url VARCHAR(512) NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Add indexes for efficient category filtering and chronological sorting
CREATE INDEX IF NOT EXISTS ix_trending_articles_category ON public.trending_articles (category);
CREATE INDEX IF NOT EXISTS ix_trending_articles_published_at ON public.trending_articles (published_at DESC);
CREATE INDEX IF NOT EXISTS ix_trending_articles_category_published ON public.trending_articles (category, published_at DESC);
