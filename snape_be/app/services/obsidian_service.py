import asyncio
import logging
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

from app.core.config import settings
from app.db.models import ChatMessage, User

logger = logging.getLogger(__name__)


class ObsidianService:
    """Lightweight, non-blocking service for integrating Snape AI with Obsidian Vault."""

    def __init__(self, vault_path: str | None = None, enabled: bool | None = None) -> None:
        self.vault_path = Path(vault_path or settings.OBSIDIAN_VAULT_PATH)
        self.enabled = enabled if enabled is not None else settings.OBSIDIAN_ENABLED
        self.snape_dir = self.vault_path / "Snape"

    def _ensure_dirs(self) -> None:
        """Ensure necessary Snape subdirectories exist in vault."""
        if not self.enabled:
            return
        for sub in ("Sessions", "Learnings", "Topics", "Profile"):
            (self.snape_dir / sub).mkdir(parents=True, exist_ok=True)

    def _load_topics_sync(self, limit: int = 5) -> list[str]:
        """Synchronously scan topics directory and notes cleanly stripping frontmatter."""
        topics: list[str] = []
        if not self.vault_path.exists():
            return topics

        topics_dir = self.snape_dir / "Topics"
        if topics_dir.exists():
            for md_file in sorted(topics_dir.glob("*.md"))[:limit]:
                try:
                    lines: list[str] = []
                    in_frontmatter = False
                    with open(md_file, "r", encoding="utf-8", errors="ignore") as f:
                        for _ in range(25):
                            line = f.readline()
                            if not line:
                                break
                            clean = line.strip()
                            if clean == "---":
                                in_frontmatter = not in_frontmatter
                                continue
                            if in_frontmatter:
                                continue
                            if clean:
                                lines.append(clean.lstrip("#").strip())
                    if lines:
                        topic_summary = " - ".join(lines[:2])
                        topics.append(f"{md_file.stem}: {topic_summary}")
                except Exception as err:
                    logger.debug("Failed to read topic file %s: %s", md_file, err)

        return topics[:limit]

    async def load_curated_topics(self, limit: int = 5) -> list[str]:
        """Asynchronously load curated discussion topics."""
        if not self.enabled:
            return []
        try:
            return await asyncio.to_thread(self._load_topics_sync, limit)
        except Exception as exc:
            logger.warning("Error loading curated topics from Obsidian: %s", exc)
            return []

    def _export_session_journal_sync(
        self,
        session_id: UUID,
        session_title: str | None,
        messages: list[ChatMessage],
        memories: list[str],
    ) -> Path | None:
        """Write session journal markdown file synchronously."""
        self._ensure_dirs()
        sessions_dir = self.snape_dir / "Sessions"
        now = datetime.now(timezone.utc)
        date_str = now.strftime("%Y-%m-%d")
        short_id = str(session_id)[:8]
        file_path = sessions_dir / f"{date_str}_{short_id}.md"

        title = session_title or f"Chat Session ({short_id})"
        content_lines = [
            "---",
            "tags:",
            "  - snape-session",
            "  - ai-journal",
            f"session_id: \"{session_id}\"",
            f"date: \"{now.isoformat()}\"",
            f"title: \"{title}\"",
            "---",
            f"# {title}",
            "",
            f"*Session recorded on {date_str} at {now.strftime('%H:%M:%S UTC')}*",
            "",
        ]

        if memories:
            content_lines.append("## Extracted Learnings & Key Takeaways")
            for mem in memories:
                content_lines.append(f"- {mem}")
            content_lines.append("")

        content_lines.append("## Conversation Transcript")
        for msg in messages:
            role_label = "Learner" if msg.role == "user" else "Snape"
            timestamp = msg.created_at.strftime("%H:%M") if hasattr(msg, "created_at") and msg.created_at else ""
            time_tag = f" [{timestamp}]" if timestamp else ""
            content_lines.append(f"**{role_label}**{time_tag}:\n{msg.content.strip()}\n")

        with open(file_path, "w", encoding="utf-8") as f:
            f.write("\n".join(content_lines))

        return file_path

    async def export_session_journal(
        self,
        session_id: UUID,
        session_title: str | None,
        messages: list[ChatMessage],
        memories: list[str],
    ) -> Path | None:
        """Asynchronously export session conversation transcript and takeaways to Obsidian."""
        if not self.enabled:
            return None
        try:
            return await asyncio.to_thread(
                self._export_session_journal_sync,
                session_id,
                session_title,
                messages,
                memories,
            )
        except Exception as exc:
            logger.warning("Failed to export session journal to Obsidian: %s", exc)
            return None

    def _sync_profile_sync(self, user: User, memories: list[str]) -> None:
        """Sync learner profile and accumulated memories."""
        self._ensure_dirs()
        profile_file = self.snape_dir / "Profile" / "User.md"
        now = datetime.now(timezone.utc)

        lines = [
            "---",
            "tags:",
            "  - snape-profile",
            f"updated_at: \"{now.isoformat()}\"",
            "---",
            f"# Learner Profile: {user.full_name or user.username or 'Default User'}",
            f"- **Native Language**: {user.native_language}",
            f"- **English Proficiency Level**: {user.english_level}",
            f"- **Last Updated**: {now.strftime('%Y-%m-%d %H:%M:%S UTC')}",
            "",
            "## Known Facts & Episodic Memory",
        ]

        if memories:
            for mem in memories:
                lines.append(f"- {mem}")
        else:
            lines.append("*(No persistent memories recorded yet)*")

        with open(profile_file, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

    async def sync_user_profile(self, user: User, memories: list[str]) -> None:
        """Asynchronously update User.md in Obsidian."""
        if not self.enabled:
            return
        try:
            await asyncio.to_thread(self._sync_profile_sync, user, memories)
        except Exception as exc:
            logger.warning("Failed to sync user profile to Obsidian: %s", exc)


_obsidian_service: ObsidianService | None = None


def get_obsidian_service() -> ObsidianService:
    """Dependency / Singleton accessor for ObsidianService."""
    global _obsidian_service
    if _obsidian_service is None:
        _obsidian_service = ObsidianService()
    return _obsidian_service
