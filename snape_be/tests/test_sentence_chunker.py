
from app.services.sentence_chunker import SentenceChunker


def test_sentence_chunker_basic_stream() -> None:
    chunker = SentenceChunker()
    tokens = [
        "Hello ",
        "there! ",
        "How ",
        "are ",
        "you ",
        "today? ",
        "I ",
        "hope ",
        "you ",
        "are ",
        "fine.",
    ]

    collected: list[str] = []
    for token in tokens:
        sentences = chunker.feed(token)
        collected.extend(sentences)
    collected.extend(chunker.flush())

    assert collected == [
        "Hello there!",
        "How are you today?",
        "I hope you are fine.",
    ]


def test_sentence_chunker_trailing_fragment() -> None:
    chunker = SentenceChunker()
    tokens = ["This ", "is ", "a ", "sentence ", "without ", "period"]

    collected: list[str] = []
    for token in tokens:
        collected.extend(chunker.feed(token))

    assert collected == []

    flushed = chunker.flush()
    assert flushed == ["This is a sentence without period"]


def test_sentence_chunker_multiple_sentences_in_single_token() -> None:
    chunker = SentenceChunker()
    tokens = ["First sentence. Second sentence! Third sentence? Fourth sentence."]

    collected: list[str] = []
    for token in tokens:
        collected.extend(chunker.feed(token))
    collected.extend(chunker.flush())

    assert collected == [
        "First sentence.",
        "Second sentence!",
        "Third sentence?",
        "Fourth sentence.",
    ]


def test_sentence_chunker_with_quotes_and_newlines() -> None:
    chunker = SentenceChunker()
    tokens = ['She said, "Good morning!"\n', "Then she ", "smiled.\n\n", "What's next?"]

    collected: list[str] = []
    for token in tokens:
        collected.extend(chunker.feed(token))
    collected.extend(chunker.flush())

    assert collected == [
        'She said, "Good morning!"',
        "Then she smiled.",
        "What's next?",
    ]


def test_sentence_chunker_empty_tokens() -> None:
    chunker = SentenceChunker()
    assert chunker.feed("") == []
    assert chunker.feed("   ") == []
    assert chunker.flush() == []
