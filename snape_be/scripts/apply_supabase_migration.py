#!/usr/bin/env python3
"""
Utility script to dynamically apply Supabase SQL schema migrations to Supabase PostgreSQL.
Tracks applied migrations in public.schema_migrations table.
"""

import os
import sys
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv

# Base directory paths
SCRIPT_DIR = Path(__file__).resolve().parent
BE_DIR = SCRIPT_DIR.parent
PROJECT_ROOT = BE_DIR.parent

# Load variables from snape_be/.env
env_path = BE_DIR / ".env"
load_dotenv(dotenv_path=env_path)


def get_database_url() -> str:
    """Resolve and format synchronous PostgreSQL database connection URL."""
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        host = os.getenv("SUPABASE_DB_HOST")
        port = os.getenv("SUPABASE_DB_PORT", "5432")
        user = os.getenv("SUPABASE_DB_USER", "postgres")
        password = os.getenv("SUPABASE_DB_PASSWORD")
        dbname = os.getenv("SUPABASE_DB_NAME", "postgres")

        if host and password:
            db_url = f"postgresql://{user}:{password}@{host}:{port}/{dbname}?sslmode=require"
        else:
            print("❌ Error: DATABASE_URL or SUPABASE_DB_PASSWORD is not set in environment or .env.")
            sys.exit(1)

    # Ensure synchronous psycopg2 connection string format
    if db_url.startswith("postgresql+asyncpg://"):
        db_url = db_url.replace("postgresql+asyncpg://", "postgresql://")
    if "ssl=require" in db_url:
        db_url = db_url.replace("ssl=require", "sslmode=require")

    return db_url


def apply_migrations(
    migrations_dir: Path | None = None,
    database_url: str | None = None,
) -> list[str]:
    """
    Dynamically discover and apply unapplied SQL migrations in chronological order.
    """
    try:
        import psycopg2
    except ImportError:
        print("❌ psycopg2 is not installed. Run: pip install psycopg2-binary python-dotenv")
        sys.exit(1)

    db_url = database_url or get_database_url()
    target_dir = migrations_dir or (BE_DIR / "supabase" / "migrations")

    if not target_dir.exists() or not target_dir.is_dir():
        print(f"❌ Migrations directory not found at: {target_dir}")
        sys.exit(1)

    migration_files = sorted(target_dir.glob("*.sql"))
    if not migration_files:
        print(f"ℹ️ No migration files found in {target_dir}.")
        return []

    parsed = urlparse(db_url)
    raw_host = parsed.hostname
    host_str = (
        raw_host.decode("utf-8")
        if isinstance(raw_host, bytes)
        else (raw_host or "")
    )
    print(f"Connecting to database host: {host_str}...")

    applied: list[str] = []
    try:
        conn = psycopg2.connect(db_url)
        with conn.cursor() as cur:
            # Create schema_migrations tracking table if it doesn't exist
            cur.execute("""
                CREATE TABLE IF NOT EXISTS public.schema_migrations (
                    version VARCHAR(255) PRIMARY KEY,
                    applied_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
                );
            """)
            conn.commit()

            # Retrieve already applied migrations
            cur.execute("SELECT version FROM public.schema_migrations;")
            applied_versions = {row[0] for row in cur.fetchall()}

            pending_migrations = [
                f for f in migration_files if f.name not in applied_versions
            ]

            if not pending_migrations:
                print("✅ Database is up to date. No new migrations to apply.")
                conn.close()
                return []

            print(f"Found {len(pending_migrations)} pending migration(s):")
            for migration_file in pending_migrations:
                print(f"  • Applying {migration_file.name}...")
                with open(migration_file, "r", encoding="utf-8") as f:
                    sql = f.read()

                cur.execute(sql)
                cur.execute(
                    "INSERT INTO public.schema_migrations (version) VALUES (%s);",
                    (migration_file.name,),
                )
                conn.commit()
                applied.append(migration_file.name)
                print(f"    ✓ Applied {migration_file.name}")

        conn.close()
        print(f"✅ Successfully applied {len(applied)} migration(s)!")
        return applied
    except Exception as e:
        print(f"❌ Error applying migration: {e}")
        sys.exit(1)


if __name__ == "__main__":
    apply_migrations()
