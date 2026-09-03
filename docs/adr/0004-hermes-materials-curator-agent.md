# 4. Hermes Materials Curator Agent & Standardized CEFR Module Architecture

Date: 2026-09-03

## Status

Accepted

## Context

Snape provides language learning companions across six CEFR proficiency levels (A1 through C2). Learners and the AI companion require structured, level-appropriate study materials, vocabulary decks, grammar explanations, reading passages, and conversation prompts stored in the Obsidian knowledge vault.

Previously, learning materials lacked automated generation, strict pedagogical grading, and structural consistency.

## Decision

1. **Autonomous Agent Architecture**:
   - Establish **Hermes Materials Curator (Agent 1)** governed by the formal specification in `docs/agents/hermes-materials-curator.soul.md`.
   - The agent operates independently via CLI runner `snape_be/scripts/hermes_materials_curator.py` or programmatic service calls.

2. **Standard 5-Section Markdown Module**:
   - All generated learning modules adhere to a strict 5-section specification:
     1. YAML Frontmatter (`title`, `level`, `topic`, `tags`, `curated_at`).
     2. Core Vocabulary & Idiomatic Expressions (5–8 items with definitions, examples, and usage notes).
     3. Grammar & Sentence Pattern Focus (1–2 patterns with syntax, explanation, and examples).
     4. Reading Passage / Natural Dialogue (calibrated length and complexity).
     5. Discussion Prompts (3–5 conversational practice questions).

3. **Obsidian Vault Directory Layout**:
   - Modules are organized under the vault root: `Snape/English/<Level>/<topic-slug>.md` (e.g., `Snape/English/A1/daily-routines.md`, `Snape/English/B2/remote-work-culture.md`).

4. **CEFR Linguistic Complexity Rubric**:
   - Strict constraints on sentence length, lexical range, and grammar targets are applied across A1 (Beginner) to C2 (Mastery).

## Consequences

- Consistent pedagogical materials across all CEFR levels.
- Direct integration with `ObsidianService` and `SpaceConfig` materials paths (`English/A1` through `English/C2`).
- Modular CLI tooling enabling automated or scheduled batch curriculum curation.
