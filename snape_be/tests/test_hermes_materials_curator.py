import sys
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

# Ensure scripts directory is in sys.path
SCRIPT_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from hermes_materials_curator import (  # noqa: E402
    VALID_CEFR_LEVELS,
    build_curation_prompt,
    parse_cli_args,
    parse_curated_markdown,
    run_curator,
    slugify_topic,
    validate_curated_markdown,
)

SAMPLE_VALID_MARKDOWN_B2 = """---
title: "Remote Work & Digital Nomadism"
level: "B2"
topic: "Remote Work"
tags:
  - snape-material
  - cefr-b2
  - remote-work
curated_at: "2026-09-03T04:00:00Z"
---

# Remote Work & Digital Nomadism

## 1. Core Vocabulary & Idiomatic Expressions
- **Asynchronous communication** `/əˌsɪŋkrənəs kəˌmjuːnɪˈkeɪʃn/`: Work across different time zones.
  - *Example*: "Our global engineering team relies heavily on asynchronous communication."
  - *Context/Tip*: Essential vocabulary for modern distributed tech companies.
- **Burnout** /ˈbɜːrnaʊt/: State of emotional and physical exhaustion caused by prolonged stress.
  - *Example*: "Setting strict boundaries after work hours helps prevent professional burnout."

## 2. Grammar & Sentence Pattern Focus
### Pattern: Mixed Conditionals (Past Cause, Present Result)
- **Structure**: `If + Past Perfect, would/could + Base Verb`
- **Explanation**: Used to express how a past condition or decision affects a present reality.
- **Examples**:
  1. "If I had accepted the remote job in London last year, I would live in Europe now."
  2. "If they had invested in cloud tools earlier, remote collaboration would be seamless today."

## 3. Reading Passage & Dialogue
### The Shifting Dynamics of the Modern Workplace
Over the past decade, cloud computing has transformed remote work into a pillar of industry.
While distributed teams have talent flexibility, they must navigate timezone friction.
Forward-thinking companies cultivate asynchronous workflows to maintain employee autonomy.

## 4. Comprehension & Usage Check
1. **Vocabulary Check**: What is the primary advantage of asynchronous communication?
2. **Grammar Application**: Formulate a mixed conditional sentence explaining a past choice.
3. **Inference**: Why is team isolation a challenge for distributed companies?

## 5. Discussion Prompts
1. "How do you maintain a healthy boundary between work and personal life when working remotely?"
2. "What do you consider the biggest advantage and biggest drawback of working from home?"
3. "Do you believe fully remote companies can maintain strong cultural cohesion over time?"
"""


def test_valid_cefr_levels_constant() -> None:
    assert VALID_CEFR_LEVELS == ("A1", "A2", "B1", "B2", "C1", "C2")


def test_slugify_topic() -> None:
    assert slugify_topic("Remote Work & Digital Nomadism") == "remote-work-digital-nomadism"
    assert slugify_topic("Daily Routines, 101!") == "daily-routines-101"
    assert slugify_topic("  Technology   in   2026  ") == "technology-in-2026"
    assert slugify_topic("Café & Food Ordering") == "cafe-food-ordering"


def test_build_curation_prompt_valid_levels() -> None:
    for level in VALID_CEFR_LEVELS:
        sys_prompt, user_prompt = build_curation_prompt(level=level, topic="Daily Routines")
        assert "Hermes Materials Curator" in sys_prompt
        assert level in sys_prompt
        assert "YAML frontmatter" in sys_prompt
        assert "Daily Routines" in user_prompt
        assert "---" in user_prompt
        assert "Core Vocabulary" in user_prompt
        assert "Grammar & Sentence Pattern Focus" in user_prompt
        assert "Discussion Prompts" in user_prompt


def test_build_curation_prompt_invalid_level_raises() -> None:
    with pytest.raises(ValueError, match="Invalid CEFR level"):
        build_curation_prompt(level="Z9", topic="Invalid")


def test_validate_curated_markdown_success() -> None:
    is_valid, reason = validate_curated_markdown(SAMPLE_VALID_MARKDOWN_B2, expected_level="B2")
    assert is_valid is True
    assert reason == "Valid"


def test_validate_curated_markdown_case_insensitive_level() -> None:
    is_valid, _ = validate_curated_markdown(SAMPLE_VALID_MARKDOWN_B2, expected_level="b2")
    assert is_valid is True


def test_validate_curated_markdown_missing_frontmatter() -> None:
    no_frontmatter = "# Just Header\n\nSome text"
    is_valid, reason = validate_curated_markdown(no_frontmatter)
    assert is_valid is False
    assert "frontmatter" in reason.lower()


def test_validate_curated_markdown_missing_required_key() -> None:
    incomplete_frontmatter = """---
title: "Sample"
topic: "Sample Topic"
---
# Sample
## 1. Core Vocabulary
## 2. Grammar Focus
## 3. Reading Passage
## 4. Comprehension Check
## 5. Discussion Prompts
"""
    is_valid, reason = validate_curated_markdown(incomplete_frontmatter)
    assert is_valid is False
    assert "missing" in reason.lower()


def test_validate_curated_markdown_mismatched_level() -> None:
    is_valid, reason = validate_curated_markdown(SAMPLE_VALID_MARKDOWN_B2, expected_level="A1")
    assert is_valid is False
    assert "level mismatch" in reason.lower()


def test_validate_curated_markdown_missing_sections() -> None:
    missing_sections = """---
title: "Incomplete"
level: "B2"
topic: "Incomplete Topic"
tags:
  - snape-material
curated_at: "2026-09-03T04:00:00Z"
---
# Incomplete Module
Only text without the 5 required sections.
"""
    is_valid, reason = validate_curated_markdown(missing_sections)
    assert is_valid is False
    assert "section" in reason.lower()


def test_parse_curated_markdown() -> None:
    parsed = parse_curated_markdown(SAMPLE_VALID_MARKDOWN_B2)
    assert parsed["frontmatter"]["title"] == "Remote Work & Digital Nomadism"
    assert parsed["frontmatter"]["level"] == "B2"
    assert parsed["frontmatter"]["topic"] == "Remote Work"
    assert "snape-material" in parsed["frontmatter"]["tags"]
    assert len(parsed["sections"]) >= 5


@pytest.mark.asyncio
async def test_run_curator_overwrite_false_raises_on_existing_file(tmp_path: Path) -> None:
    mock_llm = AsyncMock()
    mock_llm.generate_chat.return_value = SAMPLE_VALID_MARKDOWN_B2

    # First run creates the file
    paths = await run_curator(
        level="B2",
        topic="Remote Work",
        vault_path=str(tmp_path),
        dry_run=False,
        overwrite=True,
        llm_service=mock_llm,
    )
    assert paths[0].exists()

    # Second run with overwrite=False must raise since the file already exists
    with pytest.raises(FileExistsError):
        await run_curator(
            level="B2",
            topic="Remote Work",
            vault_path=str(tmp_path),
            dry_run=False,
            overwrite=False,
            llm_service=mock_llm,
        )


@pytest.mark.asyncio
async def test_run_curator_single_level(tmp_path: Path) -> None:
    mock_llm = AsyncMock()
    mock_llm.generate_chat.return_value = SAMPLE_VALID_MARKDOWN_B2

    paths = await run_curator(
        level="B2",
        topic="Remote Work",
        vault_path=str(tmp_path),
        dry_run=False,
        overwrite=True,
        llm_service=mock_llm,
    )

    assert len(paths) == 1
    assert paths[0].exists()
    assert paths[0].name == "remote-work.md"
    mock_llm.generate_chat.assert_called_once()


@pytest.mark.asyncio
async def test_run_curator_all_levels(tmp_path: Path) -> None:
    def create_level_markdown(lvl: str) -> str:
        return SAMPLE_VALID_MARKDOWN_B2.replace('level: "B2"', f'level: "{lvl}"').replace(
            "cefr-b2", f"cefr-{lvl.lower()}"
        )

    mock_llm = AsyncMock()
    mock_llm.generate_chat.side_effect = [create_level_markdown(lvl) for lvl in VALID_CEFR_LEVELS]

    paths = await run_curator(
        level="all",
        topic="Remote Work",
        vault_path=str(tmp_path),
        dry_run=False,
        overwrite=True,
        llm_service=mock_llm,
    )

    assert len(paths) == 6
    for idx, lvl in enumerate(VALID_CEFR_LEVELS):
        expected_file = tmp_path / "Snape" / "English" / lvl / "remote-work.md"
        assert expected_file.exists()


@pytest.mark.asyncio
async def test_run_curator_dry_run(tmp_path: Path) -> None:
    mock_llm = AsyncMock()
    mock_llm.generate_chat.return_value = SAMPLE_VALID_MARKDOWN_B2

    with patch("builtins.print") as mock_print:
        paths = await run_curator(
            level="B2",
            topic="Remote Work",
            vault_path=str(tmp_path),
            dry_run=True,
            overwrite=True,
            llm_service=mock_llm,
        )

    assert len(paths) == 0
    # Verified that no file was created on disk
    target_file = tmp_path / "Snape" / "English" / "B2" / "remote-work.md"
    assert not target_file.exists()
    mock_print.assert_called()


def test_parse_cli_args() -> None:
    args = parse_cli_args(["--level", "B2", "--topic", "Artificial Intelligence", "--dry-run"])
    assert args.level == "B2"
    assert args.topic == "Artificial Intelligence"
    assert args.dry_run is True
    assert args.overwrite is True

    args_all = parse_cli_args(["-l", "all", "-t", "Travel", "--no-overwrite"])
    assert args_all.level == "all"
    assert args_all.topic == "Travel"
    assert args_all.overwrite is False

    args_default = parse_cli_args([])
    assert args_default.level == "all"
    assert args_default.topic == "Daily Life & Practical Communication"
    assert args_default.overwrite is True
