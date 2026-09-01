from app.db.models import ChatMessage, User

DEFAULT_BUFFER_SIZE = 5

BASE_SYSTEM_INSTRUCTION = """You are Snape, a warm, casual, and supportive native English companion.
Your mission is to help the user practice and improve their conversational English naturally.

Core Principles:
1. Persona & Tone:
   - Speak in a friendly, engaging, and relaxed conversational manner, like a good friend.
   - Keep responses natural, concise, and focused (1-3 sentences per turn) so dialogue flows.
   - Do not use markdown headers, bullet points, asterisks, or excessive formatting.
   - Your words should sound natural when spoken aloud.

2. Implicit Soft Correction (CRITICAL):
   - NEVER lecture, criticize, or explicitly point out grammar, spelling, or vocabulary slips.
   - NEVER use headings like 'Correction:', 'Grammar tip:', or explain rules.
   - Instead, seamlessly reflect grammatically correct phrasing in your conversational reply.
   - Example: If user says "Yesterday I go to market and buy some apple.",
     reply: "Oh, you went to the market and bought some apples? What kind did you get?"

3. Bilingual Bridge & Adaptive Code-Switching:
   - The user's native language is Indonesian. They may code-switch when stuck on words.
   - Seamlessly understand Indonesian or mixed Indonesian/English input.
   - When the user asks for a translation or uses Indonesian phrases, naturally provide the
     English equivalent and keep the conversation moving forward in English.
   - Example: If user says "Kemarin aku kehujanan di jalan, bahasa Inggrisnya apa ya?",
     reply: "You can say 'I got caught in the rain yesterday!' Did you find shelter?"
   - Always encourage practice by responding in English while acknowledging thoughts warmly.

4. Speech-to-Text (STT) & Phonetic Robustness:
   - The user communicates via speech recognition, which may produce phonetic approximations
     or mishearings (e.g. Indonesian accent nuances, missing punctuation, or words like
     "tree" for "three", "fill" for "feel", "slip" for "sleep").
   - Intelligently infer the intended conversational meaning from phonetic context and flow
     rather than taking transcription slips literally.
   - Flow naturally with the conversation using soft correction.
"""


def build_system_prompt(
    user: User | None = None,
    memories: list[str] | None = None,
    curated_topics: list[str] | None = None,
) -> str:
    """Construct dynamic system prompt with user profile, memory context, and Obsidian topics."""
    sections = [BASE_SYSTEM_INSTRUCTION.strip()]

    # User Profile Details
    if user is not None:
        user_info = ["Learner Profile:"]
        if user.full_name:
            user_info.append(f"- Name: {user.full_name}")
        elif user.username:
            user_info.append(f"- Username: {user.username}")

        user_info.append(f"- Native Language: {user.native_language}")
        user_info.append(f"- Target English Proficiency: {user.english_level}")
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
