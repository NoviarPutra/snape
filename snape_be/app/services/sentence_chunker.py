import re


class SentenceChunker:
    """Buffers streaming LLM tokens and yields complete sentences on boundary detection."""

    # Matches a sentence up to ., !, ?, or \n followed by whitespace
    BOUNDARY_REGEX = re.compile(
        r"^(.*?[\.\!\?\n]+[\"'\u2019\u201d\)]*)\s+(.*)$",
        flags=re.DOTALL,
    )

    def __init__(self) -> None:
        self._buffer: str = ""

    def feed(self, token: str) -> list[str]:
        """Feed a token into the chunker and return any complete sentences."""
        if not token:
            return []

        self._buffer += token
        completed_sentences: list[str] = []

        while True:
            match = self.BOUNDARY_REGEX.match(self._buffer)
            if match:
                sentence, remainder = match.groups()
                trimmed = sentence.strip()
                self._buffer = remainder
                if trimmed:
                    completed_sentences.append(trimmed)
            else:
                break

        return completed_sentences

    def flush(self) -> list[str]:
        """Flushes and returns any remaining text in the buffer as a final sentence."""
        remaining = self._buffer.strip()
        self._buffer = ""
        if remaining:
            return [remaining]
        return []
