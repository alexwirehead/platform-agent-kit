# Профиль yandex-cloud

Работа с API Yandex Cloud.

Требует `external-api` (ставится сам, файл `requires`).

- Навык `yc-fact-check`: источники Yandex Cloud — proto `cloudapi`, реестр эндпоинтов, страницы
  `api-ref` и `security`, код `python-sdk`; сборка фикстуры по факту.
- `facts.md` в навыке: проверенные общие факты с источником и датой — хосты, правила REST и proto3 JSON,
  ошибки, SDK (discovery, токен, почему не передавать `RetryPolicy`), IAM-токен, роли.
- Пункты ревью: SDK без `RetryPolicy`, таймауты, роли только на чтение.
