# Профиль temporal

Workflow и activity Temporal на Python SDK, свой кластер. Требует `python`.

- Официальный навык `temporal-developer`: детерминизм, паттерны, версионирование, тесты, отладка;
  агент читает справочники `core/` и `python/`.
- Раскладка: `workflows/`, `activities/`, `models/`, `worker.py`; worker — отдельный процесс, не API.
- В коде workflow детерминизм важнее советов `async-python-patterns`; activity с внешними вызовами — с
  ключом идемпотентности; изменение кода при живых выполнениях — `workflow.patched` и тест replay.
- Тесты — `WorkflowEnvironment.start_local()`, первый запуск качает dev-сервер.
- CLI — только против локального `temporal server start-dev`; команды против реального кластера
  выполняет человек.
- Пункты ревью: детерминизм, идемпотентность, версионирование, CLI.
