# Профиль python

Общие правила Python-проекта: uv, Ruff, ty, pytest. Базовый профиль для `fastapi`, `temporal` и
`python-exporter`.

- Только uv: зависимости `uv add`, запуск `uv run`, версия Python — из `requires-python`.
- Проверки: `ruff check`, `ruff format --check`, `ty check`, `pytest`; тесты без сети и реальных систем.
- Сторонние навыки (wshobson/agents): `python-code-style` (стиль, типы), `python-testing-patterns`
  (pytest), `async-python-patterns` (asyncio; в коде workflow Temporal не действует). Отступление: вместо
  `pip` и mypy из навыка — uv и ty.
- Пункты ревью: блокирующие вызовы в `async def`, тесты без сети.
