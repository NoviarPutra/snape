from app.core.prompt_builder import (
    DEFAULT_BUFFER_SIZE,
    build_conversation_contents,
    build_conversation_messages,
    build_system_prompt,
)
from app.db.models import ChatMessage, User


def test_build_system_prompt_defaults() -> None:
    prompt = build_system_prompt()
    assert "Snape" in prompt
    assert "Soft Correction" in prompt or "soft correction" in prompt.lower()
    assert "Bilingual Bridge" in prompt or "indonesian" in prompt.lower()
    assert "NEVER lecture" in prompt or "do not explicitly lecture" in prompt.lower()


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


def test_build_conversation_contents_rolling_buffer() -> None:
    messages = [
        ChatMessage(role="user", content="Message 1"),
        ChatMessage(role="assistant", content="Message 2"),
        ChatMessage(role="user", content="Message 3"),
        ChatMessage(role="assistant", content="Message 4"),
        ChatMessage(role="user", content="Message 5"),
        ChatMessage(role="assistant", content="Message 6"),
        ChatMessage(role="user", content="Message 7"),
    ]

    contents = build_conversation_contents(
        history=messages,
        current_user_message="Message 8",
        buffer_size=DEFAULT_BUFFER_SIZE,
    )

    # Rolling buffer of 5 messages + current message = 6 items or 5 previous + current
    assert len(contents) == 6
    # Check that older messages (1, 2) were dropped
    roles_and_texts = [(item["role"], item["parts"][0]["text"]) for item in contents]
    assert roles_and_texts[0] == ("user", "Message 3")
    assert roles_and_texts[-1] == ("user", "Message 8")


def test_build_conversation_messages_openai_format() -> None:
    messages = [
        ChatMessage(role="user", content="Hello"),
        ChatMessage(role="assistant", content="Hi there!"),
        ChatMessage(role="user", content="How are you?"),
    ]

    conv_messages = build_conversation_messages(
        history=messages,
        current_user_message="I'm good, thanks.",
        buffer_size=2,
    )

    assert len(conv_messages) == 3
    assert conv_messages[0] == {"role": "assistant", "content": "Hi there!"}
    assert conv_messages[1] == {"role": "user", "content": "How are you?"}
    assert conv_messages[2] == {"role": "user", "content": "I'm good, thanks."}
