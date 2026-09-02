from app.core.space_config import SpaceConfig, get_space_config
from app.db.models import ChatMessage, User

DEFAULT_BUFFER_SIZE = 5

BASE_SYSTEM_INSTRUCTION = get_space_config("english_b2").system_prompt


def build_system_prompt(
    user: User | None = None,
    memories: list[str] | None = None,
    curated_topics: list[str] | None = None,
    space_config: SpaceConfig | None = None,
) -> str:
    """Construct dynamic system prompt with space persona, profile, memory, and topics."""
    active_space = space_config if space_config is not None else get_space_config("english_b2")
    sections = [active_space.system_prompt.strip()]

    # User Profile Details
    if user is not None:
        user_info = ["Learner Profile:"]
        if user.full_name:
            user_info.append(f"- Name: {user.full_name}")
        elif user.username:
            user_info.append(f"- Username: {user.username}")

        user_info.append(f"- Native Language: {user.native_language}")
        user_info.append(f"- Target English Proficiency: {user.english_level}")

        # Dynamic Pedagogical Scaffolding
        level = (user.english_level or "Intermediate").lower()
        if "beginner" in level or "elementary" in level:
            user_info.append(
                "- Pedagogical Scaffolding: The learner is at a beginner level. Keep English "
                "vocabulary simple and sentence structures clear. Proactively provide gentle "
                "Indonesian clarifications or scaffolding when they hesitate or ask for help."
            )
        elif "advanced" in level or "proficient" in level:
            user_info.append(
                "- Pedagogical Scaffolding: The learner has advanced English proficiency. Maintain "
                "maximum English immersion. Only use Indonesian when the learner explicitly "
                "demands an Indonesian explanation."
            )
        else:
            user_info.append(
                "- Pedagogical Scaffolding: Balance natural English immersion with responsive "
                "bilingual assistance when requested."
            )

        sections.append("\n".join(user_info))

    # Relevant Long-Term Memories
    if memories and len(memories) > 0:
        memory_info = ["Relevant Context & Known Facts About Learner:"]
        for memory in memories:
            memory_info.append(f"- {memory.strip()}")
        memory_info.append(
            "Use these known facts naturally when relevant to personalize the dialogue."
        )
        sections.append("\n".join(memory_info))

    # Curated Topics from Obsidian Knowledge Base
    if curated_topics and len(curated_topics) > 0:
        topic_info = ["Suggested Discussion Topics from Obsidian Knowledge Base:"]
        for topic in curated_topics:
            topic_info.append(f"- {topic.strip()}")
        topic_info.append(
            "If the conversation naturally slows or the learner asks for topics to discuss,\n"
            "feel free to introduce or connect to these topics."
        )
        sections.append("\n".join(topic_info))

    return "\n\n".join(sections)


def build_conversation_messages(
    history: list[ChatMessage],
    current_user_message: str,
    buffer_size: int = DEFAULT_BUFFER_SIZE,
) -> list[dict[str, str]]:
    """Format short-term history buffer and current user message as standard messages."""
    recent_history = history[-buffer_size:] if buffer_size > 0 else []
    messages: list[dict[str, str]] = []

    for msg in recent_history:
        messages.append({"role": msg.role, "content": msg.content})

    messages.append({"role": "user", "content": current_user_message})
    return messages
