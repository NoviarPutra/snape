.PHONY: dev test lint format migrate

# Run backend development server (auto-reload)
dev:
	@./scripts/dev_be.sh

# Run test suite
test:
	@cd snape_be && .venv/bin/pytest -v

# Run linter and type checker
lint:
	@cd snape_be && .venv/bin/ruff check . && .venv/bin/mypy app

# Auto-format code
format:
	@cd snape_be && .venv/bin/ruff format . && .venv/bin/ruff check --fix .

# Apply database migrations to Supabase Cloud
migrate:
	@cd snape_be && .venv/bin/python scripts/apply_supabase_migration.py
