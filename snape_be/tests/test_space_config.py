import pytest
from httpx import AsyncClient

from app.core.space_config import SPACE_REGISTRY, get_space_config


def test_get_space_config_returns_correct_config() -> None:
    config = get_space_config("english_b2")
    assert config.slug == "english_b2"
    assert config.language == "en"
    assert config.tts_enabled is True
    assert config.voice_call_enabled is True
    assert config.cefr_level == "b2"
    assert config.tts_voice is not None
    assert config.obsidian_materials_path == "English/B2"
    assert len(config.system_prompt) > 0


def test_get_space_config_raises_for_unknown_slug() -> None:
    with pytest.raises(ValueError, match="Unknown space slug: 'nonexistent'"):
        get_space_config("nonexistent")


def test_all_nine_slugs_registered() -> None:
    expected_slugs = {
        "english_a1",
        "english_a2",
        "english_b1",
        "english_b2",
        "english_c1",
        "english_c2",
        "tech",
        "psychology",
        "productivity",
    }
    assert set(SPACE_REGISTRY.keys()) == expected_slugs


def test_non_english_spaces_no_voice() -> None:
    for slug in ("tech", "psychology", "productivity"):
        config = get_space_config(slug)
        assert config.tts_enabled is False
        assert config.voice_call_enabled is False
        assert config.tts_voice is None
        assert config.obsidian_materials_path is None


def test_english_spaces_have_tts_and_voice_call() -> None:
    for level in ("a1", "a2", "b1", "b2", "c1", "c2"):
        slug = f"english_{level}"
        config = get_space_config(slug)
        assert config.tts_enabled is True
        assert config.voice_call_enabled is True
        assert config.language == "en"
        assert config.cefr_level == level
        assert config.tts_voice is not None
        assert config.obsidian_materials_path == f"English/{level.upper()}"


def test_non_english_spaces_language_id() -> None:
    for slug in ("tech", "psychology", "productivity"):
        config = get_space_config(slug)
        assert config.language == "id"
        assert config.cefr_level is None


@pytest.mark.asyncio
async def test_get_spaces_api(client: AsyncClient) -> None:
    response = await client.get("/api/v1/spaces")
    assert response.status_code == 200
    spaces = response.json()
    assert len(spaces) == 9

    slugs = [s["slug"] for s in spaces]
    assert "english_a1" in slugs
    assert "english_b2" in slugs
    assert "tech" in slugs

    for item in spaces:
        assert "slug" in item
        assert "display_name" in item
        assert "cefr_level" in item
        assert "tts_enabled" in item
        assert "voice_call_enabled" in item
        assert "system_prompt" not in item
        assert "tts_voice" not in item
        assert "obsidian_materials_path" not in item
