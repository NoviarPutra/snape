# Project Guidelines & Agent Instructions

This repository houses **Snape**, a private AI English learning companion with Soft Correction, pgvector memory, Kyutai Pocket-TTS audio streaming, and Flutter mobile client.

## Agent skills

### Issue tracker

Issues and specifications live locally as Markdown files in `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical triage roles mapped to standard labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/` at repo root). See `docs/agents/domain.md`.

---

## 1. Project Architecture (Clean Architecture)

Maintain clear separation of concerns across both backend and frontend subprojects without overengineering:

### Backend (`snape_be/`)

- **`app/core/`**: Config (`pydantic-settings`), security, prompt builders, constants.
- **`app/db/`**: Database engine (`asyncpg`), Base declarative, SQLAlchemy 2.0 models.
- **`app/schemas/`**: Pydantic v2 data contracts, DTOs, and WebSocket payload schemas.
- **`app/services/`**: Pure business logic (LLM streaming, memory extraction, vector search, Pocket-TTS synthesis).
- **`app/api/`**: HTTP routes and WebSocket handlers (thin controller layer).

### Frontend (`snape_ui/`)

- **`lib/core/`**: Design tokens, theme, constants, network/websocket clients, error handlers.
- **`lib/data/`**: Models (JSON serialization), repositories, remote data sources.
- **`lib/domain/`**: Pure entities and value objects (if separated from models).
- **`lib/presentation/`**: Screens, reusable widgets, Riverpod state notifiers/controllers.

---

## 2. Naming Conventions & Type Safety

### Naming Standards

- **Folders & Files**: `snake_case` in both Python and Dart (e.g., `chat_pipeline.py`, `audio_queue_service.dart`).
- **Classes & Types**: `PascalCase` (e.g., `ChatMessageModel`, `PocketTTSProvider`).
- **Variables & Functions**: `snake_case` in Python (e.g., `user_turn_handler`), `camelCase` in Dart (e.g., `sendMessage`).
- **Constants**: `SCREAMING_SNAKE_CASE` in Python, `camelCase` / `kCamelCase` in Dart.
- **Clarity**: Avoid ambiguous abbreviations (`msg` -> `message`, `sess` -> `session`, `mem` -> `memory`).

### Type Safety Rules

- **Python**: Strict type annotations on all function signatures, parameters, and return types. Use Pydantic v2 schemas for all payloads and DTOs.
- **Dart**: Strict typing enabled. Forbid `dynamic` or raw `Map<String, dynamic>` in UI widgets; always parse into immutable typed models with `freezed` or standard immutable data classes.

---

## 3. UI/UX, Design Tokens & Responsiveness (`flutter_screenutil_plus`)

### Responsiveness with `flutter_screenutil_plus`

- Wrap the root app in `ScreenUtilInit` in `main.dart` with modern configuration:

  ```dart
  ScreenUtilInit(
    designSize: const Size(390, 844), // Standard mobile base
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => child!,
  )

  ```

- Use responsive extension getters for all visual dimensions: `.w` (width), `.h` (height), `.r` (radius), `.sp` (typography).

### Authentic Design Tokens (Non-Generic AI UI)

- Establish explicit design tokens in `lib/core/theme/` (colors, typography, elevation, spacing, radii).
- Avoid stereotypical "AI chat" styling (excessive cyan/purple neon gradients, floating glowing blobs).
- Use a calm, refined editorial palette (e.g., warm slate, subtle indigo, parchment neutrals) designed for focused daily language practice.

### Explicit State Feedback (Loading, Empty, Error)

- Every asynchronous UI component must explicitly handle and display distinct states:
  - **Loading**: Discrete shimmer / typing wave animation (no generic blocking full-screen spinners).
  - **Empty**: Contextual warm illustration/copy inviting interaction.
  - **Error**: Actionable banner/toast with retry capability.

---

## 4. Engineering Standards & Anti-Patterns

- **No Spaghetti Code / God Classes**: Keep controllers and widgets focused (< 250 lines per file). Extract sub-widgets and dedicated services.
- **No Direct Business Logic in Widgets**: UI widgets only render state and trigger events on Riverpod notifiers.
- **Zero Hardcoded Secrets**: Sensitive credentials (`OMNIROUTE_API_KEY`, Supabase DB password) strictly live in `snape_be/.env` and must never appear in frontend code or Git commits.
- **Non-blocking Concurrency**: Heavy CPU tasks (e.g. Pocket-TTS neural synthesis) must be dispatched to thread/process executors (`loop.run_in_executor`), never blocking the async event loop.
