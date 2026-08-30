# Snape - AI English Learning Companion

Snape is a private, single-user AI English companion designed for seamless conversation practice with **implicit Soft Correction**, long-term semantic vector memory on **Supabase Cloud (pgvector)**, real-time Kyutai **Pocket-TTS** audio streaming, and a cross-platform **Flutter** client.

---

## System Architecture

```text
┌──────────────────────────────────────────────┐
│             Flutter Mobile Client            │
│  (Riverpod + Audio Queue + WebSocket Stream) │
└──────────────────────┬───────────────────────┘
                       │ WebSocket (/ws/chat/{session_id})
                       ▼
┌──────────────────────────────────────────────┐
│               FastAPI Backend                │
│                                              │
│  - Dynamic Prompt Assembly                   │
│  - Soft Correction & Bilingual Bridge        │
│  - Sentence Boundary Chunker                 │
│  - Async Background Memory Extractor         │
└───────────┬──────────────────┬───────────────┘
            │                  │
Vector Search & Recall         │ Token Stream
            ▼                  ▼
┌─────────────────────────┐  ┌─────────────────────────┐
│ Supabase Cloud Postgres │  │    Google Gemini API    │
│ - pgvector (HNSW Index) │  │   (gemini-2.0-flash     │
│ - Chat Sessions         │  │  + text-embedding-004)  │
│ - Short-term Buffer (5) │  └─────────────────────────┘
│ - Semantic User Memory  │                │
└─────────────────────────┘                ▼
                             ┌─────────────────────────┐
                             │    Kyutai Pocket-TTS    │
                             │ - Sentence Audio Stream │
                             └─────────────────────────┘
```

---

## Core Features

1. **Implicit Soft Correction**: Snape never interrupts or lectures on grammar rules. Slips in grammar, prepositions, or vocabulary are naturally mirrored with proper English phrasing.
2. **Adaptive Bilingual Bridge**: Understands Indonesian and mixed Indonesian/English code-switching without mode toggling, guiding the learner back into English naturally.
3. **Long-Term Vector Memory (Supabase pgvector)**: Asynchronous background worker extracts durable user facts, preferences, goals, and experiences, embeds them via `text-embedding-004` (768 dimensions), and recalls relevant memories into future conversations with HNSW cosine similarity search.
4. **Sentence-by-Sentence Audio Streaming (Kyutai Pocket-TTS)**: Synthesizes clean spoken audio chunked at natural sentence boundaries with sub-1.5s first-sentence latency.
5. **Interactive Flutter UI with Flavors**: Built with Riverpod, `flutter_screenutil_plus`, audio queue with barge-in / interrupt support, a slide-out Memory Drawer, and isolated flavors (`dev` & `prod`).

---

## Project Structure

```text
snape/
├── snape_be/                 # Backend (FastAPI, SQLAlchemy 2.0 Async, pgvector)
│   ├── app/
│   │   ├── api/v1/           # REST endpoints (health, user, sessions, memories) & WebSocket
│   │   ├── core/             # Config, prompt builder, text sanitizer
│   │   ├── db/               # Database session, base model, pgvector schema
│   │   ├── schemas/          # Pydantic v2 schemas and DTOs
│   │   └── services/         # LLM, Memory, Embedding, TTS, and Chat Pipeline
│   ├── scripts/              # Migration runners
│   ├── supabase/migrations/  # SQL migration files (pgvector + HNSW index)
│   └── tests/                # Pytest unit, integration, performance & E2E suite
├── snape_ui/                 # Frontend (Flutter, Riverpod)
│   ├── lib/
│   │   ├── core/             # Design tokens, theme, WebSocket client, audio queue, config
│   │   ├── data/             # Models and API repositories
│   │   ├── presentation/     # Screens, chat bubbles, audio status & memory drawer
│   │   ├── flavors.dart      # Flavor definitions (dev / prod)
│   │   ├── main_dev.dart     # Dev entrypoint (loads .env.dev)
│   │   └── main_prod.dart    # Prod entrypoint (loads .env.prod)
│   └── test/                 # Flutter unit & widget tests
└── scripts/                  # Development automation scripts
```

---

## Quick Start

### 1. Prerequisites

- Python 3.11+
- Flutter SDK (3.24+)
- Supabase Project (PostgreSQL with `pgvector` enabled)
- Google Gemini API key

### 2. Backend Setup (`snape_be`)

1. Copy `.env.example` to `.env` and fill in your Supabase DB URL and Gemini API Key:
   ```bash
   cp snape_be/.env.example snape_be/.env
   ```

2. Apply database migrations to Supabase:
   ```bash
   # Option A: Run migration script
   python3 snape_be/scripts/apply_supabase_migration.py

   # Option B: Run SQL via Supabase Dashboard SQL Editor
   # Copy snape_be/supabase/migrations/20260830000001_create_snape_schema.sql
   ```

3. Start the development server:
   ```bash
   npm run dev
   # or
   ./scripts/dev_be.sh
   ```
   API Docs available at: `http://localhost:8000/api/v1/docs`

---

## Running & Building the Flutter App (`snape_ui`)

### 1. Running the App (Development & Production)

```bash
# Development (loads .env.dev -> http://127.0.0.1:8000)
npm run ui:dev
# or: cd snape_ui && flutter run -t lib/main_dev.dart --flavor dev

# Production (loads .env.prod -> https://api.snape.app)
npm run ui:prod
# or: cd snape_ui && flutter run -t lib/main_prod.dart --flavor prod
```

### 2. Building Android (APK & App Bundle)

```bash
# Build Development APK (debug/testing)
npm run build:apk:dev
# Output: snape_ui/build/app/outputs/flutter-apk/app-dev-release.apk

# Build Production Release APK
npm run build:apk:prod
# Output: snape_ui/build/app/outputs/flutter-apk/app-prod-release.apk

# Build Production Google Play App Bundle (AAB)
npm run build:appbundle
# Output: snape_ui/build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

### 3. Building iOS

```bash
# Build Production iOS (no code-signing for CI/local inspection)
npm run build:ios:prod

# Build Production iOS IPA
npm run build:ipa:prod
```

---

## Testing & Quality Assurance

### Backend Tests (Pytest, Ruff, Mypy)

```bash
npm run test     # cd snape_be && .venv/bin/pytest -v
npm run lint     # cd snape_be && .venv/bin/ruff check . && .venv/bin/mypy app tests
npm run format   # cd snape_be && .venv/bin/ruff format .
```

### Frontend Tests (Flutter)

```bash
npm run ui:test      # cd snape_ui && flutter test
npm run ui:analyze   # cd snape_ui && flutter analyze
```
