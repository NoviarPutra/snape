from app.core.prompt_builder import (
    DEFAULT_BUFFER_SIZE,
    build_conversation_messages,
    build_system_prompt,
)
from app.db.models import ChatMessage, User


def test_build_system_prompt_defaults() -> None:
    prompt = build_system_prompt()
    assert "Snape" in prompt
    assert "Soft Correction" in prompt or "soft correction" in prompt.lower()
    assert "Bilingual Bridge" in prompt or "bilingual" in prompt.lower()
    assert "Sandwich" in prompt or "sandwich" in prompt.lower()


def test_build_system_prompt_with_user_and_memories() -> None:
    user = User(
        username="learner",
        full_name="Budi Pratama",
        native_language="Indonesian",
        english_level="Upper-Intermediate",
    )
    memories = [
        "User is preparing for an IELTS speaking test next Tuesday.",
        "User works as a software engineer in Jakarta.",
    ]
    prompt = build_system_prompt(user=user, memories=memories)

    assert "Budi Pratama" in prompt
    assert "Upper-Intermediate" in prompt
    assert "IELTS speaking test next Tuesday" in prompt
    assert "software engineer in Jakarta" in prompt


def test_build_system_prompt_beginner_scaffolding() -> None:
    user = User(
        username="novice_learner",
        full_name="Siti Rahma",
        native_language="Indonesian",
        english_level="Beginner",
    )
    prompt = build_system_prompt(user=user)

    assert "Beginner" in prompt
    assert "beginner" in prompt.lower()
    assert (
        "scaffold" in prompt.lower()
        or "simple" in prompt.lower()
        or "clarification" in prompt.lower()
    )


def test_build_system_prompt_advanced_immersion() -> None:
    user = User(
        username="advanced_learner",
        full_name="Andi Wijaya",
        native_language="Indonesian",
        english_level="Advanced",
    )
    prompt = build_system_prompt(user=user)

    assert "Advanced" in prompt
    assert "immersion" in prompt.lower() or "advanced" in prompt.lower()


def test_build_conversation_messages_rolling_buffer() -> None:
    messages = [
        ChatMessage(role="user", content="Message 1"),
        ChatMessage(role="assistant", content="Message 2"),
        ChatMessage(role="user", content="Message 3"),
        ChatMessage(role="assistant", content="Message 4"),
        ChatMessage(role="user", content="Message 5"),
        ChatMessage(role="assistant", content="Message 6"),
        ChatMessage(role="user", content="Message 7"),
    ]

    contents = build_conversation_messages(
        history=messages,
        current_user_message="Message 8",
        buffer_size=DEFAULT_BUFFER_SIZE,
    )

    # Rolling buffer of 5 messages + current message = 6 items
    assert len(contents) == 6
    assert contents[0] == {"role": "user", "content": "Message 3"}
    assert contents[-1] == {"role": "user", "content": "Message 8"}
