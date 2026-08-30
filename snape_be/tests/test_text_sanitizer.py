
from app.core.text_sanitizer import sanitize_text_for_tts


def test_sanitize_empty_and_whitespace() -> None:
    assert sanitize_text_for_tts("") == ""
    assert sanitize_text_for_tts("   \n\t  ") == ""


def test_sanitize_markdown_emphasis() -> None:
    text = "You said **yesterday I go**, but you should say *yesterday I went*."
    expected = "You said yesterday I go, but you should say yesterday I went."
    assert sanitize_text_for_tts(text) == expected

    text_underscores = "That is __very good__ and _awesome_!"
    assert sanitize_text_for_tts(text_underscores) == "That is very good and awesome!"

    text_strikethrough = "Don't say ~~goed~~, say went."
    assert sanitize_text_for_tts(text_strikethrough) == "Don't say goed, say went."


def test_sanitize_code_blocks_and_inline_code() -> None:
    text = "Here is an example: ```python\nprint('hello')\n``` Practice saying `I am here` daily."
    expected = "Here is an example: Practice saying I am here daily."
    assert sanitize_text_for_tts(text) == expected


def test_sanitize_links_and_headers() -> None:
    text = "# Lesson 1\n## Soft Correction\nCheck this [dictionary](https://oxford.com) link."
    expected = "Lesson 1 Soft Correction Check this dictionary link."
    assert sanitize_text_for_tts(text) == expected


def test_sanitize_bullet_points_and_quotes() -> None:
    text = """
    > Practice makes perfect.
    * First point
    - Second point
    + Third point
    1. Fourth point
    """
    cleaned = sanitize_text_for_tts(text)
    assert "Practice makes perfect." in cleaned
    assert "First point" in cleaned
    assert "Second point" in cleaned
    assert "*" not in cleaned
    assert "-" not in cleaned
    assert ">" not in cleaned


def test_sanitize_emojis() -> None:
    text = "Hello! 👋 Great job on your pronunciation 😊🚀 Keep it up! 👍"
    expected = "Hello! Great job on your pronunciation Keep it up!"
    assert sanitize_text_for_tts(text) == expected
