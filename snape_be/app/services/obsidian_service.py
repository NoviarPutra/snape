import asyncio
import logging
from datetime import UTC, datetime
from pathlib import Path
from uuid import UUID

import httpx

from app.core.config import settings
from app.db.models import ChatMessage, User

logger = logging.getLogger(__name__)


class ObsidianService:
    """Lightweight, resilient service for integrating Snape AI with Obsidian Vault.

    Supports dual-mode access: Obsidian Local REST API as primary, with seamless
    filesystem fallback if the Obsidian desktop client is closed or unreachable.
    """

    def __init__(
        self,
        vault_path: str | None = None,
        enabled: bool | None = None,
        rest_url: str | None = None,
        rest_api_key: str | None = None,
        use_rest_api: bool | None = None,
        client: httpx.AsyncClient | None = None,
        timeout: float = 5.0,
    ) -> None:
        self.vault_path = Path(vault_path or settings.OBSIDIAN_VAULT_PATH)
        self.enabled = enabled if enabled is not None else settings.OBSIDIAN_ENABLED
        self.rest_url = (rest_url or settings.OBSIDIAN_REST_URL).rstrip("/")
        self.rest_api_key = rest_api_key or settings.OBSIDIAN_REST_API_KEY
        self.use_rest_api = (
            use_rest_api if use_rest_api is not None else settings.OBSIDIAN_USE_REST_API
        )
        self.timeout = timeout
        self.snape_dir = self.vault_path / "Snape"
        self._client = client

    def _get_client(self) -> httpx.AsyncClient:
        """Lazily initialize shared async HTTP client with SSL verification skipped for loopback."""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                verify=False,
                timeout=self.timeout,
            )
        return self._client

    def _get_headers(self) -> dict[str, str]:
        """Generate authentication headers for Local REST API."""
        return {
            "Authorization": f"Bearer {self.rest_api_key}",
            "Content-Type": "text/markdown",
            "Accept": "text/markdown, application/json",
        }

    async def write_note(self, relative_path: str, content: str) -> Path | str | None:
        """Write note markdown content to Obsidian via REST API with filesystem fallback."""
        if not self.enabled:
            return None

        clean_rel = relative_path.lstrip("/")

        # 1. Attempt write via Local REST API if configured
        if self.use_rest_api and self.rest_api_key and self.rest_url:
            try:
                client = self._get_client()
                url = f"{self.rest_url}/vault/{clean_rel}"
                response = await client.put(
                    url,
                    headers=self._get_headers(),
                    content=content.encode("utf-8"),
                )
                if response.status_code in (200, 201, 204):
                    logger.debug("Successfully wrote note '%s' via Obsidian REST API", clean_rel)
                    return clean_rel
                logger.warning(
                    "Obsidian REST API PUT returned %d: %s. Falling back to disk.",
                    response.status_code,
                    response.text,
                )
            except (httpx.ConnectError, httpx.TimeoutException, httpx.RequestError) as err:
                logger.debug("Obsidian REST API unreachable (%s). Using filesystem fallback.", err)
            except Exception as exc:
                logger.warning("Unexpected error with Obsidian REST API: %s. Using fallback.", exc)

        # 2. Filesystem fallback
        try:
            return await asyncio.to_thread(self._write_file_sync, clean_rel, content)
        except Exception as exc:
            logger.error("Failed to write note to disk at %s: %s", clean_rel, exc)
            return None

    def _write_file_sync(self, relative_path: str, content: str) -> Path:
        target_file = self.vault_path / relative_path
        target_file.parent.mkdir(parents=True, exist_ok=True)
        target_file.write_text(content, encoding="utf-8")
        return target_file

    async def read_note(self, relative_path: str) -> str | None:
        """Read note markdown content from Obsidian via REST API with filesystem fallback."""
        if not self.enabled:
            return None

        clean_rel = relative_path.lstrip("/")

        # 1. Attempt read via Local REST API if configured
        if self.use_rest_api and self.rest_api_key and self.rest_url:
            try:
                client = self._get_client()
                url = f"{self.rest_url}/vault/{clean_rel}"
                response = await client.get(url, headers=self._get_headers())
                if response.status_code == 200:
                    return response.text
                if response.status_code == 404:
                    return None
                logger.debug(
                    "Obsidian REST API GET returned %d for %s",
                    response.status_code,
                    clean_rel,
                )
            except (httpx.ConnectError, httpx.TimeoutException, httpx.RequestError):
                pass
            except Exception as exc:
                logger.debug("Obsidian REST API read error: %s", exc)

        # 2. Filesystem fallback
        try:
            return await asyncio.to_thread(self._read_file_sync, clean_rel)
        except Exception as exc:
            logger.debug("Filesystem read failed for %s: %s", clean_rel, exc)
            return None

    def _read_file_sync(self, relative_path: str) -> str | None:
        target_file = self.vault_path / relative_path
        if target_file.is_file():
            return target_file.read_text(encoding="utf-8")
        return None

    async def delete_note(self, relative_path: str) -> bool:
        """Delete note via REST API with filesystem fallback."""
        if not self.enabled:
            return False

        clean_rel = relative_path.lstrip("/")
        if self.use_rest_api and self.rest_api_key and self.rest_url:
            try:
                client = self._get_client()
                url = f"{self.rest_url}/vault/{clean_rel}"
                response = await client.delete(url, headers=self._get_headers())
                if response.status_code in (200, 204):
                    return True
            except Exception as err:
                logger.debug("REST delete failed: %s", err)

        try:
            return await asyncio.to_thread(self._delete_file_sync, clean_rel)
        except Exception as exc:
            logger.debug("Filesystem delete failed: %s", exc)
            return False

    def _delete_file_sync(self, relative_path: str) -> bool:
        target_file = self.vault_path / relative_path
        if target_file.is_file():
            target_file.unlink()
            return True
        return False

    async def get_learning_materials(self, level: str, category: str) -> str | None:
        """Retrieve curated CEFR study materials for a specific space level and topic/slug."""
        if not self.enabled:
            return None

        # Check standard level casing conventions (e.g. English/A1/..., English/a1/...)
        candidate_paths = [
            f"Snape/English/{level.upper()}/{category}.md",
            f"Snape/English/{level.lower()}/{category}.md",
            f"Snape/English/{level}/{category}.md",
        ]

        for path in candidate_paths:
            content = await self.read_note(path)
            if content is not None:
                return content

        return None

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
                    with open(md_file, encoding="utf-8", errors="ignore") as f:
                        for _ in range(25):
                            line = f.readline()
                            if not line:
                                break
                            clean = line.strip()
                            if clean == "---":
                                in_frontmatter = not in_frontmatter
                                continue
                            if in_frontmatter or not clean:
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
        """Load curated topics list for prompt enrichment."""
        if not self.enabled:
            return []
        try:
            return await asyncio.to_thread(self._load_topics_sync, limit)
        except Exception as exc:
            logger.warning("Error loading curated topics from Obsidian: %s", exc)
            return []

    async def export_session_journal(
        self,
        session_id: UUID,
        session_title: str | None,
        messages: list[ChatMessage],
        memories: list[str],
    ) -> Path | str | None:
        """Export session conversation transcript and takeaways to Obsidian."""
        if not self.enabled:
            return None

        now = datetime.now(UTC)
        date_str = now.strftime("%Y-%m-%d")
        short_id = str(session_id)[:8]
        rel_path = f"Snape/Sessions/{date_str}_{short_id}.md"

        title = session_title or f"Chat Session ({short_id})"
        content_lines = [
            "---",
            "tags:",
            "  - snape-session",
            "  - ai-journal",
            f'session_id: "{session_id}"',
            f'date: "{now.isoformat()}"',
            f'title: "{title}"',
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
            timestamp = (
                msg.created_at.strftime("%H:%M")
                if hasattr(msg, "created_at") and msg.created_at
                else ""
            )
            time_tag = f" [{timestamp}]" if timestamp else ""
            content_lines.append(f"### {role_label}{time_tag}")
            content_lines.append(msg.content or "")
            content_lines.append("")

        full_content = "\n".join(content_lines)
        return await self.write_note(rel_path, full_content)

    async def sync_user_profile(self, user: User, memories: list[str]) -> None:
        """Sync learner profile and accumulated memories to Obsidian."""
        if not self.enabled:
            return

        now = datetime.now(UTC)
        lines = [
            "---",
            "tags:",
            "  - snape-profile",
            f'updated_at: "{now.isoformat()}"',
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
            lines.append("- *No memories recorded yet.*")

        full_content = "\n".join(lines)
        await self.write_note("Snape/Profile/User.md", full_content)

    async def close(self) -> None:
        """Close internal HTTP client if open."""
        if self._client is not None and not self._client.is_closed:
            await self._client.aclose()


_obsidian_service: ObsidianService | None = None


def get_obsidian_service() -> ObsidianService:
    """Dependency / Singleton accessor for ObsidianService."""
    global _obsidian_service
    if _obsidian_service is None:
        _obsidian_service = ObsidianService()
    return _obsidian_service
