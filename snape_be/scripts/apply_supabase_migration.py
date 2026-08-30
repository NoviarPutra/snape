#!/usr/bin/env python3
"""
Utility script to apply Supabase SQL schema migrations to Supabase PostgreSQL.
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

DATABASE_URL = os.getenv("DATABASE_URL")
MIGRATION_FILE = BE_DIR / "supabase" / "migrations" / "20260830000001_create_snape_schema.sql"

if not DATABASE_URL:
    host = os.getenv("SUPABASE_DB_HOST")
    port = os.getenv("SUPABASE_DB_PORT", "5432")
    user = os.getenv("SUPABASE_DB_USER", "postgres")
    password = os.getenv("SUPABASE_DB_PASSWORD")
    dbname = os.getenv("SUPABASE_DB_NAME", "postgres")

    if host and password:
        DATABASE_URL = f"postgresql://{user}:{password}@{host}:{port}/{dbname}?sslmode=require"
    else:
        print("❌ Error: DATABASE_URL or SUPABASE_DB_PASSWORD is not set in environment or .env.")
        sys.exit(1)

# Ensure synchronous psycopg2 connection string format
if DATABASE_URL.startswith("postgresql+asyncpg://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
if "ssl=require" in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("ssl=require", "sslmode=require")


def apply_migration() -> None:
    try:
        import psycopg2
    except ImportError:
        print("❌ psycopg2 is not installed. Run: pip install psycopg2-binary python-dotenv")
        sys.exit(1)

    parsed = urlparse(DATABASE_URL)
    raw_host = parsed.hostname
    host_str = (
        raw_host.decode("utf-8")
        if isinstance(raw_host, bytes)
        else (raw_host or "")
    )
    print(f"Connecting to database host: {host_str}...")

    if not MIGRATION_FILE.exists():
        print(f"❌ Migration file not found at: {MIGRATION_FILE}")
        sys.exit(1)

    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = True
        with conn.cursor() as cur:
            with open(MIGRATION_FILE) as f:
                sql = f.read()
            print("Executing migration SQL script...")
            cur.execute(sql)
        conn.close()
        print("✅ Migration applied successfully!")
    except Exception as e:
        print(f"❌ Error applying migration: {e}")
        sys.exit(1)


if __name__ == "__main__":
    apply_migration()
