import json
import logging
import math
from uuid import UUID

from google import genai
from google.genai import types
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.models import ChatMessage, UserMemory
from app.schemas.memory import MemoryCreate, MemoryQueryResult
from app.services.embedding_service import BaseEmbeddingService, get_embedding_service

logger = logging.getLogger(__name__)

MEMORY_EXTRACTION_SYSTEM_PROMPT = """You are an episodic memory extraction agent.
Analyze the user's message to extract durable facts, preferences, goals, and experiences.

Categories allowed:
- 'fact': Biographical facts (job, location, pets, family, education, background).
- 'preference': Personal likes, dislikes, habits, hobbies, favorite things.
- 'goal': Aspirations, learning objectives, travel plans, upcoming events, targets.
- 'experience': Notable past experiences, stories, or achievements shared by user.

Rules:
1. Only extract information explicitly stated by the user about THEMSELVES.
2. Do NOT extract ephemeral states (e.g., 'User is tired today', 'User is saying hi').
3. Keep each extracted memory concise, atomic, and third-person.
   Example: 'Works as a software engineer in Jakarta', 'Loves playing badminton'.
4. Return a JSON object with a 'memories' list of objects with 'category' and 'content'.
5. If no relevant long-term memories are found, return {"memories": []}.

JSON schema:
{
  "memories": [
    {
      "category": "fact" | "preference" | "goal" | "experience",
      "content": "concise atomic statement"
    }
  ]
}
"""

VALID_CATEGORIES = {"fact", "preference", "goal", "experience"}
DEFAULT_MATCH_THRESHOLD = 0.55
DEFAULT_DEDUPLICATION_THRESHOLD = 0.90


def cosine_similarity(v1: list[float], v2: list[float]) -> float:
    """Calculate cosine similarity between two float vectors."""
    if not v1 or not v2 or len(v1) != len(v2):
        return 0.0

    dot_product = sum(a * b for a, b in zip(v1, v2, strict=False))
    norm1 = math.sqrt(sum(a * a for a in v1))
    norm2 = math.sqrt(sum(b * b for b in v2))

    if norm1 == 0.0 or norm2 == 0.0:
        return 0.0

    return dot_product / (norm1 * norm2)


class MemoryService:
    """Service handling vector search, deduplication, CRUD, and LLM-powered memory extraction."""

    def __init__(
        self,
        embedding_service: BaseEmbeddingService | None = None,
        client: genai.Client | None = None,
    ) -> None:
        self.embedding_service = embedding_service or get_embedding_service()
        self._client: genai.Client | None = None

        if client is not None:
            self._client = client
        elif settings.GEMINI_API_KEY:
            self._client = genai.Client(api_key=settings.GEMINI_API_KEY)

    async def create_memory(
        self,
        db: AsyncSession,
        user_id: UUID,
        memory_in: MemoryCreate,
        deduplicate: bool = True,
        deduplication_threshold: float = DEFAULT_DEDUPLICATION_THRESHOLD,
    ) -> UserMemory | None:
        """Create a new memory item, optionally skipping if a similar memory (>=0.90) exists."""
        if deduplicate:
            # Check for near-identical duplicate memories
            similar = await self.search_memories(
                db=db,
                user_id=user_id,
                query=memory_in.embedding,
                threshold=deduplication_threshold,
                limit=1,
            )
            if similar:
                logger.info(
                    "Skipping duplicate memory for user %s: '%s' (similarity: %.4f with '%s')",
                    user_id,
                    memory_in.content,
                    similar[0].similarity,
                    similar[0].content,
                )
                return None

        memory = UserMemory(
            user_id=user_id,
            category=memory_in.category if memory_in.category in VALID_CATEGORIES else "fact",
            content=memory_in.content.strip(),
            embedding=memory_in.embedding,
        )
        db.add(memory)
        await db.flush()
        return memory

    async def get_memories(
        self,
        db: AsyncSession,
        user_id: UUID,
        limit: int = 50,
        offset: int = 0,
        category: str | None = None,
    ) -> list[UserMemory]:
        """Fetch paginated memories for a user, optionally filtered by category."""
        stmt = select(UserMemory).where(UserMemory.user_id == user_id)
        if category and category in VALID_CATEGORIES:
            stmt = stmt.where(UserMemory.category == category)

        stmt = stmt.order_by(UserMemory.created_at.desc()).offset(offset).limit(limit)
        result = await db.execute(stmt)
        return list(result.scalars().all())

    async def get_memory_by_id(
        self,
        db: AsyncSession,
        memory_id: UUID,
        user_id: UUID,
    ) -> UserMemory | None:
        """Retrieve a specific memory by its ID ensuring user ownership."""
        stmt = (
            select(UserMemory)
            .where(UserMemory.id == memory_id)
            .where(UserMemory.user_id == user_id)
        )
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def delete_memory(
        self,
        db: AsyncSession,
        memory_id: UUID,
        user_id: UUID,
    ) -> bool:
        """Delete a memory item by ID."""
        memory = await self.get_memory_by_id(db, memory_id=memory_id, user_id=user_id)
        if not memory:
            return False
        await db.delete(memory)
        await db.flush()
        return True

    async def search_memories(
        self,
        db: AsyncSession,
        user_id: UUID,
        query: str | list[float],
        threshold: float = DEFAULT_MATCH_THRESHOLD,
        limit: int = 5,
    ) -> list[MemoryQueryResult]:
        """Perform semantic vector similarity search on user memories."""
        if isinstance(query, str):
            query_vector = await self.embedding_service.generate_embedding(query)
        else:
            query_vector = query

        # Detect dialect to use pgvector native cosine distance in PostgreSQL
        bind = db.get_bind()
        dialect_name = bind.dialect.name if bind is not None else "postgresql"

        if dialect_name == "postgresql":
            distance_expr = UserMemory.embedding.cosine_distance(query_vector)
            similarity_expr = (1.0 - distance_expr).label("similarity")

            stmt = (
                select(UserMemory, similarity_expr)
                .where(UserMemory.user_id == user_id)
                .where((1.0 - distance_expr) >= threshold)
                .order_by(distance_expr.asc())
                .limit(limit)
            )
            result = await db.execute(stmt)
            rows = result.all()

            return [
                MemoryQueryResult(
                    id=row[0].id,
                    user_id=row[0].user_id,
                    category=row[0].category,
                    content=row[0].content,
                    created_at=row[0].created_at,
                    similarity=float(row[1]),
                )
                for row in rows
            ]

        # SQLite / In-Memory Python fallback for unit testing
        stmt_fallback = select(UserMemory).where(UserMemory.user_id == user_id)
        result_fallback = await db.execute(stmt_fallback)
        all_memories = result_fallback.scalars().all()

        scored_memories: list[tuple[UserMemory, float]] = []
        for mem in all_memories:
            sim = cosine_similarity(mem.embedding, query_vector)
            if sim >= threshold:
                scored_memories.append((mem, sim))

        scored_memories.sort(key=lambda item: item[1], reverse=True)
        top_results = scored_memories[:limit]

        return [
            MemoryQueryResult(
                id=mem.id,
                user_id=mem.user_id,
                category=mem.category,
                content=mem.content,
                created_at=mem.created_at,
                similarity=sim,
            )
            for mem, sim in top_results
        ]

    async def extract_memories_from_text(
        self,
        user_content: str,
        recent_history: list[ChatMessage] | None = None,
    ) -> list[dict[str, str]]:
        """Extract atomic user facts, preferences, goals, or experiences using Gemini."""
        if not self._client:
            logger.debug("Gemini client unavailable for memory extraction.")
            return []

        context_lines: list[str] = []
        if recent_history:
            for msg in recent_history[-3:]:
                context_lines.append(f"{msg.role}: {msg.content}")

        prompt = f"Context:\n{chr(10).join(context_lines)}\n\nLatest User Message:\n{user_content}"

        config = types.GenerateContentConfig(
            system_instruction=MEMORY_EXTRACTION_SYSTEM_PROMPT,
            temperature=0.2,
            response_mime_type="application/json",
        )

        try:
            response = await self._client.aio.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=prompt,
                config=config,
            )

            if not response.text:
                return []

            data = json.loads(response.text)
            raw_memories = data.get("memories", [])
            valid_extracted: list[dict[str, str]] = []

            for item in raw_memories:
                cat = item.get("category", "fact")
                content = item.get("content", "").strip()
                if content and cat in VALID_CATEGORIES:
                    valid_extracted.append({"category": cat, "content": content})

            return valid_extracted
        except Exception as exc:
            logger.warning("Failed to extract memories via Gemini LLM: %s", exc)
            return []

    async def extract_and_persist(
        self,
        db: AsyncSession,
        user_id: UUID,
        user_content: str,
        recent_history: list[ChatMessage] | None = None,
    ) -> list[str]:
        """Extract memories from text, embed, deduplicate, and persist to user_memories."""
        extracted_items = await self.extract_memories_from_text(
            user_content=user_content,
            recent_history=recent_history,
        )

        if not extracted_items:
            return []

        persisted_contents: list[str] = []
        turn_embeddings: list[tuple[dict[str, str], list[float]]] = []

        # Batch or individual generate embeddings
        for item in extracted_items:
            emb = await self.embedding_service.generate_embedding(item["content"])
            turn_embeddings.append((item, emb))

        for item, emb in turn_embeddings:
            # Check deduplication against previously stored memories
            mem = await self.create_memory(
                db=db,
                user_id=user_id,
                memory_in=MemoryCreate(
                    user_id=user_id,
                    category=item["category"],
                    content=item["content"],
                    embedding=emb,
                ),
                deduplicate=True,
                deduplication_threshold=DEFAULT_DEDUPLICATION_THRESHOLD,
            )
            if mem is not None:
                persisted_contents.append(mem.content)

        if persisted_contents:
            await db.commit()

        return persisted_contents


_memory_service_instance: MemoryService | None = None


def get_memory_service() -> MemoryService:
    """Dependency / singleton factory for MemoryService."""
    global _memory_service_instance
    if _memory_service_instance is None:
        _memory_service_instance = MemoryService()
    return _memory_service_instance
