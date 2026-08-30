import re

# Comprehensive Unicode pattern for emojis and miscellaneous symbols
EMOJI_PATTERN = re.compile(
    "["
    "\U0001f600-\U0001f64f"  # Emoticons
    "\U0001f300-\U0001f5ff"  # Miscellaneous symbols & pictographs
    "\U0001f680-\U0001f6ff"  # Transport and map symbols
    "\U0001f1e0-\U0001f1ff"  # Regional indicator symbols (Flags)
    "\U00002702-\U000027b0"  # Dingbats
    "\U000024c2-\U0001f251"  # Enclosed characters
    "\U0001f900-\U0001f9ff"  # Supplemental symbols and pictographs
    "\U0001fa00-\U0001fa6f"  # Chess symbols
    "\U0001fa70-\U0001faff"  # Symbols and pictographs extended-a
    "\U00002600-\U000026ff"  # Miscellaneous symbols
    "\U0000fe00-\U0000fe0f"  # Variation selectors
    "\U0001f000-\U0001f02f"  # Mahjong tiles
    "\U0001f0a0-\U0001f0ff"  # Playing cards
    "]+",
    flags=re.UNICODE,
)


def sanitize_text_for_tts(text: str) -> str:
    """Sanitizes generated LLM text for natural speech synthesis.

    Strips Markdown formatting, code blocks, bullet points, headers, emojis,
    and trailing artifacts to prevent vocalizing punctuation or markup artifacts.
    """
    if not text or not text.strip():
        return ""

    # 1. Remove multi-line code blocks entirely
    cleaned = re.sub(r"```[\s\S]*?```", "", text)

    # 2. Extract content from inline code `word` -> word
    cleaned = re.sub(r"`([^`]+)`", r"\1", cleaned)

    # 3. Extract text from markdown links [text](url) -> text
    cleaned = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", cleaned)

    # 4. Strip markdown formatting syntax (*, **, _, __, ~~)
    cleaned = re.sub(r"\*\*([^*]+)\*\*", r"\1", cleaned)
    cleaned = re.sub(r"\*([^*]+)\*", r"\1", cleaned)
    cleaned = re.sub(r"__([^_]+)__", r"\1", cleaned)
    cleaned = re.sub(r"_([^_]+)_", r"\1", cleaned)
    cleaned = re.sub(r"~~([^~]+)~~", r"\1", cleaned)

    # 5. Remove line-start markers: headers (#), bullets (- * +), numbered lists (1.), quotes (>)
    cleaned = re.sub(r"^[ \t]*[#]+[ \t]*", "", cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r"^[ \t]*[-*+][ \t]+", "", cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r"^[ \t]*\d+\.[ \t]+", "", cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r"^[ \t]*>[ \t]*", "", cleaned, flags=re.MULTILINE)

    # 6. Remove emojis and pictographs
    cleaned = EMOJI_PATTERN.sub("", cleaned)

    # 7. Strip leftover markdown marker symbols
    cleaned = re.sub(r"[*_~#`]", "", cleaned)

    # 8. Collapse whitespace and fix spacing before punctuation
    cleaned = re.sub(r"[ \t]+", " ", cleaned)
    cleaned = re.sub(r"\s+([.,!?:;])", r"\1", cleaned)
    cleaned = re.sub(r"\n+", " ", cleaned)

    return cleaned.strip()
