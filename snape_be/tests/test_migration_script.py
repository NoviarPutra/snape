import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

# Ensure scripts directory is in sys.path
SCRIPT_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import apply_supabase_migration  # noqa: E402


def test_apply_migrations_applies_all_when_none_applied(tmp_path: Path) -> None:
    # Create mock migration files
    f1 = tmp_path / "20260830000001_create_snape_schema.sql"
    f1.write_text("CREATE TABLE users (id int);", encoding="utf-8")
    f2 = tmp_path / "20260903000001_add_space_slug.sql"
    f2.write_text("ALTER TABLE chat_sessions ADD space_slug text;", encoding="utf-8")

    mock_cursor = MagicMock()
    # Initially no migrations applied
    mock_cursor.fetchall.return_value = []

    mock_conn = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

    with patch("psycopg2.connect", return_value=mock_conn):
        applied = apply_supabase_migration.apply_migrations(
            migrations_dir=tmp_path,
            database_url="postgresql://user:pass@localhost:5432/db",
        )

    assert applied == [
        "20260830000001_create_snape_schema.sql",
        "20260903000001_add_space_slug.sql",
    ]
    # Check that both SQL files were executed and recorded
    executed_sqls = [call_args[0][0] for call_args in mock_cursor.execute.call_args_list]
    assert "CREATE TABLE users (id int);" in executed_sqls
    assert "ALTER TABLE chat_sessions ADD space_slug text;" in executed_sqls


def test_apply_migrations_skips_already_applied(tmp_path: Path) -> None:
    f1 = tmp_path / "20260830000001_create_snape_schema.sql"
    f1.write_text("CREATE TABLE users (id int);", encoding="utf-8")
    f2 = tmp_path / "20260903000001_add_space_slug.sql"
    f2.write_text("ALTER TABLE chat_sessions ADD space_slug text;", encoding="utf-8")

    mock_cursor = MagicMock()
    # f1 is already applied
    mock_cursor.fetchall.return_value = [("20260830000001_create_snape_schema.sql",)]

    mock_conn = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

    with patch("psycopg2.connect", return_value=mock_conn):
        applied = apply_supabase_migration.apply_migrations(
            migrations_dir=tmp_path,
            database_url="postgresql://user:pass@localhost:5432/db",
        )

    assert applied == ["20260903000001_add_space_slug.sql"]
    executed_sqls = [call_args[0][0] for call_args in mock_cursor.execute.call_args_list]
    assert "CREATE TABLE users (id int);" not in executed_sqls
    assert "ALTER TABLE chat_sessions ADD space_slug text;" in executed_sqls


def test_apply_migrations_no_pending_does_nothing(tmp_path: Path) -> None:
    f1 = tmp_path / "20260830000001_create_snape_schema.sql"
    f1.write_text("CREATE TABLE users (id int);", encoding="utf-8")

    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = [("20260830000001_create_snape_schema.sql",)]

    mock_conn = MagicMock()
    mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

    with patch("psycopg2.connect", return_value=mock_conn):
        applied = apply_supabase_migration.apply_migrations(
            migrations_dir=tmp_path,
            database_url="postgresql://user:pass@localhost:5432/db",
        )

    assert applied == []
    # Verify no DDL or INSERT was executed
    insert_calls = [c for c in mock_cursor.execute.call_args_list if "INSERT INTO" in str(c)]
    assert len(insert_calls) == 0
