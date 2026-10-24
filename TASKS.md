# Задачи

Статусы: `[ ]` не начата, `[~]` в работе, `[x]` сделана, `[!]` заблокирована.

## Этап 0. Каркас

- [x] T0.1 Каркас репозитория, решения К1–К8, спецификация 001.
  Заметки: 2026-10-24, сделано по интервью с пользователем.
- [x] T0.2 Согласовать спецификацию 001 с пользователем, статус «принята».
  Заметки: 2026-10-24, принята пользователем без правок.

## Этап 1. Ядро

- [ ] T1.1 `core/rules.md` (EN) — общие правила без привязки к проекту.
  Спека: docs/specs/001-kit-v1.md
- [ ] T1.2 Навык `change-workflow` и шаблоны `core/templates/` (`docs/specs/README.md`, `TASKS.md`).
  Спека: docs/specs/001-kit-v1.md
- [ ] T1.3 Команды OpenCode `simplify`, `code-review`, `security-review` без привязки к Yandex Cloud.
  Спека: docs/specs/001-kit-v1.md
- [ ] T1.4 `core/skills.txt`: сторонние навыки ядра с закреплёнными коммитами.
  Спека: docs/specs/001-kit-v1.md

## Этап 2. Установщик

- [ ] T2.1 `tests/run.sh`: установка `--offline` во временный каталог, проверки из «Готово, когда».
  Спека: docs/specs/001-kit-v1.md
- [ ] T2.2 `install.sh`: профили и зависимости, блок `AGENTS.md`, навыки, команды, шаблоны, lock.
  Спека: docs/specs/001-kit-v1.md
- [ ] T2.3 Повторный запуск и смена профилей: без изменений, лишние навыки удаляются, `.gitignore`.
  Спека: docs/specs/001-kit-v1.md

## Этап 3. Профили v1

- [ ] T3.1 `helm`: `helm-conventions`, `helm-chart-scaffolding`, шаблон проверки чарта, хуки pre-commit.
  Проверить навык на внутренние адреса. Спека: docs/specs/001-kit-v1.md
- [ ] T3.2 `python-exporter`: правила цикла, метрик, логов, тестов на fake-клиентах; `python-code-style`,
  `docker-patterns`. Спека: docs/specs/001-kit-v1.md
- [ ] T3.3 `external-api`: навык `api-fact-check`. Спека: docs/specs/001-kit-v1.md
- [ ] T3.4 `yandex-cloud`: навык `yc-fact-check` поверх `api-fact-check`. Спека: docs/specs/001-kit-v1.md
- [ ] T3.5 `grafana`: навык `grafana-dashboard`. Спека: docs/specs/001-kit-v1.md

## Этап 4. Заготовки профилей

Каждая: интервью с пользователем → спецификация → правила. Без интервью правила не пишутся (К4).

- [ ] T4.1 `cicd`: GitLab CI и/или GitHub Actions.
- [ ] T4.2 `fluxcd`: манифесты FluxCD и Flux Operator.
- [ ] T4.3 `argocd`: Application, ApplicationSet, проекты.
- [ ] T4.4 `otel`: экспортеры и коллектор OpenTelemetry.
- [ ] T4.5 `monitoring`: правила алертов, ServiceMonitor, VictoriaMetrics.

## Этап 5. Обкатка

- [ ] T5.1 Установка в чистый проект с сетью: навыки видны в Claude Code и OpenCode.
  Спека: docs/specs/001-kit-v1.md
- [ ] T5.2 Перевести на кит существующие проекты: спецификация в каждом проекте, отдельная ветка.
- [ ] T5.3 Замерить токены одного навыка на русском и на английском (`count_tokens`) и записать в К5.
- [ ] T5.4 Удалённый репозиторий кита: где хранить и как обновлять в проектах (вопрос пользователю).
