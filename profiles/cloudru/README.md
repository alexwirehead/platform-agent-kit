# Профиль cloudru

Работа с Cloud.ru Advanced: Terraform-провайдер `sbercloud`, OBS, API.

Требует `external-api` (ставится сам, файл `requires`). Вместе с профилем `terraform`:
`install.sh <проект> terraform cloudru`.

- Навык `cloudru-fact-check`: источники Cloud.ru Advanced — документация провайдера
  `sbercloud-terraform/terraform-provider-sbercloud` по тегу версии, справка и API Cloud.ru Advanced.
- `facts.md` в навыке: проверенные факты с источником и датой — провайдер и его переменные окружения,
  зеркало, бэкенд `s3` в OBS с `use_lockfile`.
- Ключи только из окружения, не в блоках `provider` и `backend`; это же — пункт ревью.

Cloud.ru Evolution в профиль не входит: спецификация `docs/specs/003-terraform-profile.md`.
