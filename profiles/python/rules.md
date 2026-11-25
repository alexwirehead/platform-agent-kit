## Python

- Tooling is uv only: `uv add`, `uv add --dev`, `uv run`; no `pip install`, no hand-made virtualenv. The
  Python version comes from `requires-python` in `pyproject.toml`.
- Lint and format: `uv run ruff check`, `uv run ruff format`. Types: ty (`uv add --dev ty`,
  `uv run ty check`). Deviation from `python-code-style`: it shows `pip install` and mypy or pyright — use
  uv and ty instead.
- Tests: `uv run pytest`; async tests with the plugin the project already uses (`pytest-asyncio` or
  AnyIO). Tests never reach the network or real systems: fixtures, fakes, dependency overrides.
- Docs for libraries come from `ctx7` for the version in `uv.lock`, not from memory.
