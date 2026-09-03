#!/usr/bin/env python3
"""Hermes Materials Curator (Agent 1) — Autonomous CEFR Study Module Generator.

Researches, structures, and writes standardized 5-section CEFR-graded study markdown
modules into Obsidian vault subfolders (Snape/English/A1 through Snape/English/C2).
"""

import argparse
import asyncio
import logging
import re
import sys
import unicodedata
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

# Ensure backend root is on sys.path when executed directly
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.config import settings  # noqa: E402
from app.services.llm_service import BaseLLMService, OmniRouteLLMService  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger("hermes_materials_curator")

VALID_CEFR_LEVELS: tuple[str, ...] = ("A1", "A2", "B1", "B2", "C1", "C2")

CEFR_LEVEL_GUIDELINES: dict[str, dict[str, str]] = {
    "A1": {
        "name": "Beginner / Breakthrough",
        "sentence_length": "5–8 words",
        "lexicon": "Top 500–1,000 basic words",
        "grammar": (
            "Present Simple (to be, common verbs), basic pronouns, "
            "simple question words (who, what, where)"
        ),
        "passage_type": "Simple dialogue (80–120 words) around concrete daily situations",
        "tone": "Warm, encouraging, simple, zero pressure",
    },
    "A2": {
        "name": "Elementary / Waystage",
        "sentence_length": "8–12 words",
        "lexicon": "1,000–2,000 high-frequency words",
        "grammar": (
            "Past Simple, going to future, modal can/could, "
            "basic conjunctions (and, but, because)"
        ),
        "passage_type": "Short dialogue or narrative (120–180 words) on routines, hobbies, travel",
        "tone": "Casual, clear, supportive",
    },
    "B1": {
        "name": "Intermediate / Threshold",
        "sentence_length": "12–18 words",
        "lexicon": "2,000–3,500 words, common phrasal verbs",
        "grammar": (
            "Present Perfect, 1st/2nd Conditionals, simple passive voice, relative clauses"
        ),
        "passage_type": (
            "Conversational dialogue or short article (200–300 words) "
            "discussing experiences or plans"
        ),
        "tone": "Engaging, conversational, expressive",
    },
    "B2": {
        "name": "Upper Intermediate / Vantage",
        "sentence_length": "15–25 words",
        "lexicon": "3,500–5,000 words, idioms, collocations",
        "grammar": (
            "3rd/mixed conditionals, passive reporting, past perfect continuous, complex modals"
        ),
        "passage_type": (
            "Authentic reading passage or debate (300–450 words) analyzing viewpoints"
        ),
        "tone": "Articulate, analytical, natural",
    },
    "C1": {
        "name": "Advanced / Effective Operational Proficiency",
        "sentence_length": "18–35+ words",
        "lexicon": "5,000–8,000 words, sophisticated idioms, figurative language",
        "grammar": (
            "Inversion, cleft sentences, participle clauses, subjunctive mood, advanced hedging"
        ),
        "passage_type": "Nuanced essay or in-depth analytical passage (450–600 words)",
        "tone": "Sophisticated, professional, articulate",
    },
    "C2": {
        "name": "Mastery / Proficiency",
        "sentence_length": "Richly varied and stylistically flexible",
        "lexicon": "8,000+ words, rare idioms, stylistic nuances",
        "grammar": (
            "Full command of rare syntactic structures, inverted conditionals, rhetorical fronting"
        ),
        "passage_type": (
            "Deeply nuanced essay, philosophical critique, or literary excerpt (550–750 words)"
        ),
        "tone": "Masterful, eloquent, stylistically versatile",
    },
}


def slugify_topic(topic: str) -> str:
    """Normalize and convert topic string into a clean lowercase hyphenated slug."""
    normalized = unicodedata.normalize("NFKD", topic).encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^\w\s-]", "", normalized.lower())
    slug = re.sub(r"[-\s]+", "-", slug).strip("-")
    return slug or "untitled-topic"


def build_curation_prompt(level: str, topic: str) -> tuple[str, str]:
    """Generate system and user prompts for curating a standardized CEFR learning module."""
    norm_level = level.upper()
    if norm_level not in VALID_CEFR_LEVELS:
        raise ValueError(
            f"Invalid CEFR level '{level}'. Must be one of {', '.join(VALID_CEFR_LEVELS)}"
        )

    guidelines = CEFR_LEVEL_GUIDELINES[norm_level]
    iso_now = datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    slug = slugify_topic(topic)

    system_prompt = f"""\
You are Hermes Materials Curator, an autonomous pedagogical intelligence agent.
Your mission is to curate a standardized CEFR {norm_level} ({guidelines['name']}) study \
module in clean Markdown format for the Snape learning companion Obsidian vault.

Linguistic Constraints for CEFR {norm_level}:
- Target Sentence Length: {guidelines['sentence_length']}
- Vocabulary Scope: {guidelines['lexicon']}
- Grammar Targets: {guidelines['grammar']}
- Passage Style: {guidelines['passage_type']}
- Tone: {guidelines['tone']}

Document Standards:
- Produce clean, valid Markdown without wrapping the entire output in extra backtick fences.
- Strictly adhere to the standard 5-section format with YAML frontmatter.
"""

    user_prompt = f"""\
Generate a comprehensive study module on the topic: "{topic}" for CEFR level {norm_level}.

Output format must follow this exact structure:

---
title: "{topic}"
level: "{norm_level}"
topic: "{topic}"
tags:
  - snape-material
  - cefr-{norm_level.lower()}
  - {slug}
curated_at: "{iso_now}"
---

# {topic}

## 1. Core Vocabulary & Idiomatic Expressions
- Provide 5–8 high-impact vocabulary items / phrases calibrated to CEFR {norm_level}.
- For each item, include phonetic/part-of-speech, definition, and a natural example sentence.

## 2. Grammar & Sentence Pattern Focus
- Select 1–2 target grammar patterns relevant to CEFR {norm_level}.
- Provide Structure, Explanation, and 2–3 clear Example sentences.

## 3. Reading Passage & Dialogue
- Provide an engaging {guidelines['passage_type']} illustrating the vocabulary and grammar focus.

## 4. Comprehension & Usage Check
- Provide 3 targeted comprehension/application questions.

## 5. Discussion Prompts
- Provide 3–5 open-ended conversational questions for practice with Snape AI companion.
"""
    return system_prompt, user_prompt


def validate_curated_markdown(
    content: str, expected_level: str | None = None
) -> tuple[bool, str]:
    """Validate that curated markdown adheres to the 5-section standard and frontmatter schema."""
    if not content or not content.strip():
        return False, "Content is empty"

    text = content.strip()
    # Check frontmatter
    fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not fm_match:
        return False, "Missing YAML frontmatter block enclosed in ---"

    fm_text = fm_match.group(1)
    required_keys = ("title", "level", "topic", "tags", "curated_at")
    for key in required_keys:
        if not re.search(rf"^{key}:", fm_text, re.MULTILINE):
            return False, f"Missing required frontmatter key: '{key}'"

    # Verify level if expected
    if expected_level:
        level_match = re.search(r"^level:\s*[\"']?([a-zA-Z0-9]+)[\"']?", fm_text, re.MULTILINE)
        if not level_match:
            return False, "Could not parse 'level' from frontmatter"
        parsed_level = level_match.group(1).upper()
        if parsed_level != expected_level.upper():
            return (
                False,
                f"Level mismatch: expected '{expected_level.upper()}', got '{parsed_level}'",
            )

    body = text[fm_match.end() :]

    # Required section patterns
    required_sections = [
        (r"##\s*1\.\s*Core Vocabulary", "Section 1: Core Vocabulary"),
        (r"##\s*2\.\s*Grammar", "Section 2: Grammar & Sentence Pattern Focus"),
        (r"##\s*3\.\s*(Reading|Dialogue)", "Section 3: Reading Passage & Dialogue"),
        (r"##\s*4\.\s*Comprehension", "Section 4: Comprehension & Usage Check"),
        (r"##\s*5\.\s*Discussion Prompts", "Section 5: Discussion Prompts"),
    ]

    for pattern, name in required_sections:
        if not re.search(pattern, body, re.IGNORECASE):
            return False, f"Missing required section: '{name}'"

    return True, "Valid"


def parse_curated_markdown(content: str) -> dict[str, Any]:
    """Parse curated markdown into structured metadata and sections."""
    text = content.strip()
    fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    frontmatter: dict[str, Any] = {}

    if fm_match:
        fm_text = fm_match.group(1)
        for line in fm_text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                key, val = line.split(":", 1)
                key = key.strip()
                val = val.strip().strip("\"'")
                if key == "tags":
                    frontmatter[key] = []
                elif line.startswith("-") and "tags" in frontmatter:
                    frontmatter["tags"].append(line.lstrip("- ").strip("\"'"))
                else:
                    frontmatter[key] = val
            elif line.startswith("-") and "tags" in frontmatter:
                frontmatter["tags"].append(line.lstrip("- ").strip("\"'"))

    body = text[fm_match.end() :] if fm_match else text

    # Extract sections by markdown H2
    sections: list[dict[str, str]] = []
    splits = re.split(r"(^##\s+.*?$)", body, flags=re.MULTILINE)
    current_title = ""
    for chunk in splits:
        if chunk.startswith("##"):
            current_title = chunk.strip().lstrip("# ").strip()
        elif current_title and chunk.strip():
            sections.append({"title": current_title, "content": chunk.strip()})

    return {
        "frontmatter": frontmatter,
        "sections": sections,
        "raw": content,
    }


def save_material_to_vault(
    vault_path: Path | str,
    level: str,
    topic: str,
    content: str,
    overwrite: bool = True,
) -> Path:
    """Save curated markdown file into Obsidian vault subfolder Snape/English/<LEVEL>/."""
    norm_level = level.upper()
    slug = slugify_topic(topic)
    target_dir = Path(vault_path) / "Snape" / "English" / norm_level
    target_dir.mkdir(parents=True, exist_ok=True)

    file_path = target_dir / f"{slug}.md"
    if file_path.exists() and not overwrite:
        raise FileExistsError(f"Material file already exists at {file_path}")

    file_path.write_text(content, encoding="utf-8")
    logger.info("Saved curated module to %s", file_path)
    return file_path


async def run_curator(
    level: str,
    topic: str,
    vault_path: str | None = None,
    dry_run: bool = False,
    overwrite: bool = True,
    llm_service: BaseLLMService | None = None,
    model: str | None = None,
) -> list[Path]:
    """Orchestrate curation across one or all CEFR levels."""
    resolved_vault = Path(vault_path or settings.OBSIDIAN_VAULT_PATH)
    llm = llm_service or OmniRouteLLMService(model=model)

    if level.lower() == "all":
        target_levels = list(VALID_CEFR_LEVELS)
    else:
        norm_level = level.upper()
        if norm_level not in VALID_CEFR_LEVELS:
            raise ValueError(f"Invalid level '{level}'. Must be in {VALID_CEFR_LEVELS} or 'all'")
        target_levels = [norm_level]

    saved_paths: list[Path] = []

    for lvl in target_levels:
        logger.info("Curating CEFR %s study module for topic '%s'...", lvl, topic)
        sys_prompt, user_prompt = build_curation_prompt(level=lvl, topic=topic)

        generated_raw = await llm.generate_chat(
            system_instruction=sys_prompt,
            contents=[{"role": "user", "content": user_prompt}],
            temperature=0.3,
        )

        # Strip surrounding markdown code fences if output by LLM
        cleaned = re.sub(r"^```(?:markdown)?\s*\n", "", generated_raw.strip(), flags=re.IGNORECASE)
        cleaned = re.sub(r"\n```$", "", cleaned.strip())

        is_valid, reason = validate_curated_markdown(cleaned, expected_level=lvl)
        if not is_valid:
            logger.warning("Generated module failed validation: %s", reason)

        if dry_run:
            print(f"\n==================== [CEFR {lvl}: {topic}] ====================")
            print(cleaned)
            print("================================================================\n")
        else:
            path = save_material_to_vault(
                vault_path=resolved_vault,
                level=lvl,
                topic=topic,
                content=cleaned,
                overwrite=overwrite,
            )
            saved_paths.append(path)

    return saved_paths


def parse_cli_args(args: list[str] | None = None) -> argparse.Namespace:
    """Configure and parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Hermes Materials Curator — Generate CEFR-graded study modules for Obsidian vault."
        )
    )
    parser.add_argument(
        "-l",
        "--level",
        type=str,
        required=True,
        help=f"Target CEFR level ({', '.join(VALID_CEFR_LEVELS)}) or 'all'",
    )
    parser.add_argument(
        "-t",
        "--topic",
        type=str,
        required=True,
        help="Thematic topic for the curated study module (e.g. 'Remote Work & Digital Nomadism')",
    )
    parser.add_argument(
        "--vault-path",
        type=str,
        default=None,
        help=f"Obsidian vault directory path (defaults to {settings.OBSIDIAN_VAULT_PATH})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print curated markdown to stdout without writing to vault disk",
    )
    parser.add_argument(
        "--overwrite",
        dest="overwrite",
        action="store_true",
        default=True,
        help="Overwrite existing markdown file if slug already exists (default: True)",
    )
    parser.add_argument(
        "--no-overwrite",
        dest="overwrite",
        action="store_false",
        help="Do not overwrite existing file",
    )
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Optional OmniRoute model override",
    )
    return parser.parse_args(args)


async def main() -> None:
    """CLI execution entrypoint."""
    args = parse_cli_args()
    try:
        paths = await run_curator(
            level=args.level,
            topic=args.topic,
            vault_path=args.vault_path,
            dry_run=args.dry_run,
            overwrite=args.overwrite,
            model=args.model,
        )
        if not args.dry_run:
            print(f"Successfully curated {len(paths)} module(s):")
            for p in paths:
                print(f"  - {p}")
    except Exception as exc:
        logger.error("Curation failed: %s", exc)
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
