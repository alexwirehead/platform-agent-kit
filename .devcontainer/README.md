# Девконтейнер platform-agent-kit

Окружение для разработки кита: Claude Code, uv с закреплённым Python 3.13 для тестов установщика
(`uv run pytest`, решение К10), helm и kubeconform для теста шаблона `dev/check-chart.sh`, Node.js для
`npx` (CLI `skills`, ctx7). Образ на `mcr.microsoft.com/devcontainers/base:3-ubuntu26.04` для arm64
(Apple Silicon) и amd64.

## Что внутри

| Утилита | Для чего |
|---|---|
| uv, uvx, Python 3.13 | тесты (`pytest`), ruff, shellcheck (`shellcheck-py`) из `pyproject.toml` |
| git, jq, curl | установщик и проверки руками |
| helm, kubeconform | тест `test_check_chart_skips_crds`; без них тест пропускается |
| Claude Code, Node.js | features, версии закреплены в `devcontainer-lock.json` |
| Расширения VS Code | Python, Ruff, ShellCheck |

Версии uv, Python, helm и kubeconform — в `ARG` в начале `Dockerfile`, архивы сверяются с sha256 из
релизов. Базовый образ закреплён по digest.

bash 3.2 (macOS) в контейнере нет: совместимость установщика с ним проверяется прогоном
`uv run pytest` на маке.

## Первый запуск

Нужны Docker Desktop и VS Code с расширением Dev Containers.

1. Открыть папку кита в VS Code: `Cmd+Shift+P` → **Dev Containers: Reopen in Container**.
   `initializeCommand` сам создаст на маке `~/.devcontainer-state/platform-agent-kit/{claude,agents,shell-history}`.
2. После сборки `postCreateCommand` ставит зависимости (`uv sync`, если есть `pyproject.toml`) и
   добавляет рабочую папку в `safe.directory` git контейнера.
3. В терминале контейнера запустить `claude` и войти. Учётные данные сохранятся в
   `~/.devcontainer-state/platform-agent-kit/claude` на маке.
4. Проверка: `uv run pytest`.

## Что где хранится

| Что | Где | Переживает |
|---|---|---|
| Сессии и настройки Claude (`~/.claude`, включая `.claude.json`) | мак, `~/.devcontainer-state/platform-agent-kit/claude` | удаление контейнера и томов |
| `~/.agents` | мак, `~/.devcontainer-state/platform-agent-kit/agents` | то же |
| История bash и zsh | мак, `~/.devcontainer-state/platform-agent-kit/shell-history` | то же |
| `.venv` | папка кита | всё; в `.gitignore` |
| VS Code Server | том `platform-agent-kit-vscode-server` | Rebuild |
| uv, Python, helm, kubeconform | образ | кешируются слоями Docker |

## Если что-то пошло не так

- **`dubious ownership` в git.** `postCreateCommand` не отработал: выполнить в контейнере
  `git config --global --add safe.directory "$PWD"` в корне кита.
- **Сборка упала на sha256.** Файл скачался битым или хеш в `Dockerfile` не совпадает с релизом:
  повторить сборку, при повторной ошибке проверить хеш.
- **Обновить версию.** Поменять `ARG` вместе с хешами для arm64 и amd64 и сделать Rebuild.
