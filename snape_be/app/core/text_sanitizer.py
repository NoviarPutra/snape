import re

# Comprehensive Unicode pattern for emojis and miscellaneous symbols
EMOJI_PATTERN = re.compile(
    "["
    "\U0001F600-\U0001F64F"  # Emoticons
    "\U0001F300-\U0001F5FF"  # Miscellaneous symbols & pictographs
    "\U0001F680-\U0001F6FF"  # Transport and map symbols
    "\U0001F1E0-\U0001F1FF"  # Regional indicator symbols (Flags)
    "\U00002702-\U000027B0"  # Dingbats
    "\U000024C2-\U0001F251"  # Enclosed characters
    "\U0001F900-\U0001F9FF"  # Supplemental symbols and pictographs
    "\U0001FA00-\U0001FA6F"  # Chess symbols
    "\U0001FA70-\U0001FAFF"  # Symbols and pictographs extended-a
    "\U00002600-\U000026FF"  # Miscellaneous symbols
    "\U0000FE00-\U0000FE0F"  # Variation selectors
    "\U0001F000-\U0001F02F"  # Mahjong tiles
    "\U0001F0A0-\U0001F0FF"  # Playing cards
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
