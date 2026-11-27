# План: 013. План задачи в файле и известные ошибки агента

Спека: docs/specs/013-plan-and-mistakes.md

## T1.8 План задачи в файле

Файлы: `tests/test_install.py`, `core/skills/change-workflow/SKILL.md`, `core/rules.md`,
`core/templates/docs/specs/README.md`, `docs/specs/README.md`, `AGENTS.md` (блок), `docs/00-overview.md`
(К23), `README.md`.

1. [x] Тест `test_core_task_plan` падает: в навыке и правиле 7 порядок с «plan», в навыке
   `.plan.md` и правка плана в том же коммите, в шаблонах спек шаблон плана.
2. [x] Навык: порядок, новый раздел 3 «Plan» (там же — план виден на остановке 2), без плана без спеки.
3. [x] `core/rules.md`: шаг 4 «Starting a session», правило 7.
4. [x] Шаблон плана в обоих `docs/specs/README.md`.
5. [x] `./install.sh .`, К23, README; полная проверка.

## T1.9 Известные ошибки агента

Файлы: `tests/test_install.py`, `core/rules.md`, `install.sh`, `AGENTS.md` (блок), `README.md`, `TASKS.md`
(этап 6).

1. [ ] Тест `test_core_known_mistakes` падает: правило в `core/rules.md` с «only after the user's yes»,
   новый `AGENTS.md` содержит `### Known mistakes`.
2. [ ] Правило 8 в `core/rules.md`, подраздел в `install.sh` (режим `new`).
3. [ ] `./install.sh .`, README, идеи плейбука в этапе 6; полная проверка.
