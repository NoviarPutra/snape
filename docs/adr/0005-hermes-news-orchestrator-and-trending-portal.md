# 5. Hermes News Orchestrator Agent & Trending Articles Schema

Date: 2026-09-03

## Status

Accepted

## Context

Snape aims to provide realistic, engaging conversational practice for language learners. Beyond static pedagogical modules, learners are highly motivated by discussing breaking world news, viral pop culture moments, technological shifts, and internet trends.

Previously, there was no autonomous pipeline to discover, summarize, and categorize trending news topics into structured conversation prompts, nor any database schema or REST API to serve trending articles to the mobile client.

## Decision

1. **Autonomous Agent Architecture**:
   - Establish **Hermes News Orchestrator (Agent 2)** governed by the formal specification in `docs/agents/hermes-news-orchestrator.soul.md`.
   - Implement CLI runner `snape_be/scripts/hermes_news_orchestrator.py` capable of querying web search gateways, extracting trending phenomena, generating structured summaries with LLM synthesis, and persisting entries into Supabase PostgreSQL.

2. **Categorization Taxonomy**:
   - Enforce 4 core domain categories:
     - `politics`: Policy, geopolitics, elections, global affairs.
     - `general`: Science, technology breakthroughs, world events, environment.
     - `music`: New releases, charts, artist movements, album drops, tours.
     - `creator_trends`: Viral phenomena, social media culture, streamer/creator news.

3. **Database Schema (`public.trending_articles`)**:
   - Create a dedicated PostgreSQL table with:
     - `id`: UUID Primary Key.
     - `category`: `VARCHAR(32)` constrained to valid categories.
     - `title`: `VARCHAR(255)`.
     - `summary`: `TEXT` (bulleted digest + "Why It's Trending" rationale).
     - `source_url`: `VARCHAR(512)`.
     - `published_at`: `TIMESTAMPTZ`.
     - `tags`: `JSONB` array of strings.
     - `metadata`: `JSONB` object (source name, viral metrics, discussion hooks).
     - `created_at`: `TIMESTAMPTZ`.
   - Add single and composite indexes on `category` and `published_at` for high-performance sorting and filtering.

4. **REST API Surface**:
   - Expose `GET /api/v1/trending` for paginated, category-filtered article queries.
   - Expose `POST /api/v1/trending/sync` to trigger background trend discovery and aggregation.

5. **Discussion Bridge**:
   - Enable direct transition from any trending article into a chat session:
     - English discussion: default `english_b2` with article summary preloaded.
     - Indonesian discussion: thematic room with article summary preloaded.

## Consequences

- Real-time cultural and news relevance is seamlessly integrated into the Snape ecosystem.
- Users can choose between discussing news in English immersion or conversational Indonesian.
- Database queries for trending content remain fast and decoupled from external search latency.
