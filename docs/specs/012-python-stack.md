# 012. Профили python, fastapi, temporal и backstage

Статус: принята 2026-11-25, пользователь
Задачи: T4.9 [ ]
Решения: К22

## Зачем

Пользователь (2026-11-25): нужны профили для разработки на Python и FastAPI, workflow Temporal и
плагинов Backstage (frontend и backend). Связка в работе: плагины Backstage шлют запросы в API на
FastAPI (стандартные шаблоны scaffolder не используются), API запускает workflow Temporal, worker —
отдельный процесс, он, например, создаёт инфраструктуру. Деплой — k8s.

Источник правил по решению пользователя — сторонние навыки и официальная документация; выбор
инструментов — по интервью. Стек сверен с `uv.lock` проекта пользователя (в кит не попадает): Python 3.14,
FastAPI 0.140, temporalio 1.33, pydantic-settings, httpx, pytest + pytest-asyncio, ruff; БД нет.

## Что меняется

### `python` — новый профиль, база для остальных

- Сторонние навыки (wshobson/agents@0874a27, прочитаны целиком): `python-code-style` (переезжает из
  `python-exporter`), `python-testing-patterns`, `async-python-patterns`.
- Правила: только uv (`uv add`, `uv run`, без pip); `ruff check` и `ruff format`; типы — `ty`
  (`uv add --dev ty`, `uv run ty check`, docs.astral.sh/ty); тесты — `uv run pytest`; версия Python —
  из `requires-python`. Тесты не ходят в сеть и реальные системы — фейки и подмены.
- `project.md`: полная проверка `uv run pytest && uv run ruff check && uv run ruff format --check &&
  uv run ty check`.
- `python-exporter` требует `python`; общие команды уходят из его `rules.md`, остаётся стенд.

### `fastapi`, требует `python`

- Навык `fastapi` — официальный, из репозитория FastAPI (`fastapi/.agents/skills/fastapi`@05e6df7).
- Отступления: деплой не FastAPI Cloud (`fastapi deploy`), а k8s через чарт проекта; советы навыка
  про SQLModel, Asyncer и другие библиотеки — только с согласия пользователя; слоя БД нет, его появление
  решает пользователь.
- Версия: навык описывает свежий FastAPI. Возможность, которой может не быть в версии из `uv.lock`,
  проверяется по документации этой версии (ctx7), иначе не используется.
- API — только Temporal Client: запускает workflow, worker в процессе API не стартует. Клиент —
  зависимость (`Annotated[..., Depends(...)]`), в тестах подменяется `app.dependency_overrides`;
  запросы в тестах — `httpx.AsyncClient` с `ASGITransport` или `TestClient` (fastapi.tiangolo.com).
- OpenAPI — контракт с Backstage: изменение, ломающее клиентов, — вопрос пользователю; после изменения
  схемы агент напоминает перегенерировать клиент в Backstage.

### `temporal`, требует `python`

- Навык `temporal-developer` — официальный (temporalio/skill-temporal-developer@db4cbca, MIT).
  Прочитаны целиком SKILL.md и справочники Python: детерминизм, тесты, SDK; остальные — по заголовкам и
  поиску команд, меняющих сервер.
- Python SDK, свой кластер. Раскладка из навыка: `workflows/`, `activities/`, `models/`, `worker.py`
  отдельно; worker — своя точка входа, не API.
- В коде workflow правила детерминизма Temporal важнее `async-python-patterns`: время, случайность,
  UUID, сон, I/O — только через API `workflow` или в activity.
- Activity с внешними вызовами (создание инфраструктуры) — с ключом идемпотентности (`gotchas`).
  Входы — одна dataclass или модель Pydantic, новые поля с значениями по умолчанию.
- Изменение кода workflow при живых выполнениях — версионирование (`workflow.patched`) и тест replay;
  есть ли живые выполнения — вопрос пользователю.
- Тесты: `WorkflowEnvironment.start_local()` (первый запуск качает dev-сервер), activity подменяются,
  `ActivityEnvironment` для activity, time-skipping — только для таймеров.
- CLI — только против локального `temporal server start-dev`. Команды против реального кластера
  (`terminate`, `reset`, `cancel`, `signal` и др. из справочника отладки) агент отдаёт пользователю.

### `backstage`

- Навыки из монорепозитория Backstage (backstage/backstage@1be002d, `.agents/skills/`):
  `frontend-plugin-development`, `backend-plugin-development`. `onboard-to-openapi-server` не берём —
  он под монорепозиторий самого Backstage (`backstage-repo-tools`, changesets).
- Систему плагинов агент определяет по коду проекта (`createPlugin` — старая frontend-система,
  `createFrontendPlugin` — новая; backend — `createBackendPlugin`) и следует ей; новый плагин в приложении
  на старой системе — вопрос пользователю (пользователь не знает, на какой системе проект).
- Логики инфраструктуры в Backstage нет: плагин вызывает API, API — Temporal. Стандартные шаблоны
  scaffolder для этого не используются.
- Клиент API — генерируется из OpenAPI сервиса; генератор — тот, что уже в проекте, нет — вопрос.
- Проверки: `yarn tsc`, `yarn lint`, `yarn test`. Дев-приложение в браузере смотрит пользователь:
  агент перечисляет, что проверить (страница рисуется, нет блока `App startup encountered warnings:`).
- Версия — из `backstage.json`, документация этой версии.

### Общее

- Строки в `INSTALL.md`: `python` — `pyproject.toml`, `uv.lock`; `fastapi` — зависимость `fastapi`;
  `temporal` — `temporalio`; `backstage` — `backstage.json`, пакеты `@backstage/*`.
- README: таблица профилей. Установка `backstage` дольше: навыки из большого монорепозитория (~1 мин на
  навык).

## Что не меняется

- Ядро и установщик.
- Шаблонов (`dev/check-*.sh`) у новых профилей нет: проверка — команды из `project.md`.
- Навыки Temporal ops/cloud/serverless, миграции Backstage — не берём.

## Затронутые документы

- `profiles/python/`, `profiles/fastapi/`, `profiles/temporal/`, `profiles/backstage/` — новые.
- `profiles/python-exporter/` — `requires`, `skills.txt`, `rules.md`, `skills.md`.
- `INSTALL.md`, `README.md`, `docs/00-overview.md` (К4, К22).

## Готово, когда

- Тест: `python-exporter` требует `python`; `python-code-style` ставится один раз; у каждого нового
  профиля строка в `INSTALL.md` (существующий тест).
- Установка с сетью во временный проект: `fastapi temporal backstage` — все навыки на месте, без
  `backstage` его навыки уходят.
- `uv run pytest && uv run ruff check && uv run ruff format --check` чистые.
- Пользователь проверил профили в своём проекте.

## Открытые вопросы

Нет.
