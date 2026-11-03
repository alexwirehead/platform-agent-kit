# 003. Профиль terraform: Terraform и Terragrunt для Yandex Cloud и Cloud.ru Advanced

Статус: черновик
Задачи: T4.6 [ ], T4.7 [ ], T4.8 [ ]
Решения: К13

## Зачем

Нужна качественная разработка IaC на Terraform и Terragrunt, прежде всего для Yandex Cloud и Cloud.ru
Advanced. Обкатанного репозитория нет: правила собраны по интервью с пользователем 2026-11-03 (К4)
и по официальной документации. Запрос пользователя от 2026-11-03.

## Что меняется

### Профиль `terraform`

Общие правила Terraform и Terragrunt без привязки к облаку.

- **Рантайм** — Terraform CLI и Terragrunt 1.x. Не OpenTofu.
- **Репозитории.** Монорепозитория нет:
  - у каждого модуля свой репозиторий: модуль в корне (`versions.tf`, `variables.tf`, `outputs.tf`,
    `main.tf`, README от terraform-docs); релиз — semver-тег модуля, изменения описываются
    в `CHANGELOG.md`;
  - у каждого облака свой live-репозиторий Terragrunt — описание реальной инфраструктуры облака:
    `<каталог|проект>/<компонент>/terragrunt.hcl` в корне репозитория, без каталога `live/`.
    Корневой `root.hcl` генерирует бэкенд и провайдер, на каждом уровне — свой `*.hcl` с `locals`.
    Модуль подключается через `source` с `?ref=vX.Y.Z`. Переход окружения на новую версию модуля —
    отдельное изменение `ref`.
- **Готовые модули** берутся, если подходят, но только из зеркала во внутреннем GitLab и по тегу.
  Ссылок на публичные GitHub и registry в `source` нет. Свой модуль пишется, когда готового нет
  или он не подходит.
- **Версии:**
  - в модуле `required_version` и `required_providers` задают только нижнюю границу (`>= X.Y`);
  - точная версия провайдера — в root: блок `generate` в `root.hcl` и `.terraform.lock.hcl`;
  - lock-файл коммитится с хешами для `linux_amd64` и `darwin_arm64`.
- **Провайдеры** ставятся из зеркала: `network_mirror` в `~/.terraformrc`, потому что
  registry.terraform.io из РФ недоступен. Адрес зеркала и команда `terraform providers lock
  -net-mirror=...` записаны в фактах облака.
- **State** хранится в объектном хранилище облака через backend `s3` с `use_lockfile = true`.
  Бакет с версионированием. `dynamodb_table` не используется: в Terraform он объявлен устаревшим.
  `use_lockfile` в обоих облаках проверен и обкатан пользователем (2026-11-03).
- **Секреты:**
  - значений секретов нет в коде, в `*.tfvars` и в `inputs`;
  - переменные с секретами помечены `sensitive = true`;
  - state считается секретом.

  Способ доставки секретов (SOPS, Vault) пока не обкатан, и кит его не задаёт.
- **Агент работает офлайн.** Ему разрешены `fmt`, `validate` (`init -backend=false`), `tflint`,
  `trivy config`, `terraform-docs`, `terragrunt hcl fmt` и `hcl validate`. `plan` и `apply` запускает
  человек или CI, агент их не запускает и ключей не просит. Это то же правило, что в `external-api`.
- **Порядок доставки:** plan на MR, apply только после ревью plan и только из `main`. Конкретный
  пайплайн будет описан в профиле `cicd` (T4.1).
- **Проверки:** `terraform fmt -check`, `terragrunt hcl fmt --check`, `terraform validate`, `tflint`,
  `trivy config` и актуальность README от terraform-docs. Шаблон `dev/check-terraform.sh` запускает их
  все. Шаблоны `.tflint.hcl` и `.pre-commit-config.yaml` с теми же проверками кладутся в проект.
  `terraform test` не входит: решение пользователя.
- **Навыки:**
  - свой `terraform-conventions` — правила выше, раскладка обоих видов репозиториев, `root.hcl`,
    `dependency` с `mock_outputs` для офлайн-проверок, CLI Terragrunt 1.x (`run --all`);
  - сторонние (К3, коммит закрепляется после чтения навыка целиком): `terrashark`
    (LukasNiessen/terrashark) — цикл по типичным ошибкам IaC; `terraform-style-guide`
    и `refactor-module` (hashicorp/agent-skills). Отступления проекта от этих навыков записываются
    в `rules.md` профиля.
- **Пункты ревью:**
  - секреты не попали в код, tfvars и outputs без `sensitive`;
  - удаление и пересоздание ресурсов обосновано, при переименовании есть `moved`;
  - у модуля только нижние границы версий;
  - `ref` модуля — тег, а не ветка; `source` указывает на внутренний GitLab.

### Профиль `yandex-cloud`

В `facts.md` навыка `yc-fact-check` появляется раздел Terraform, у каждого факта источник и дата:
- провайдер `yandex-cloud/yandex`;
- зеркало `https://terraform-mirror.yandexcloud.net/` и настройка `~/.terraformrc`;
- бэкенд `s3` для Object Storage: `endpoints.s3 = https://storage.yandexcloud.net`,
  `region = ru-central1`, флаги `skip_region_validation`, `skip_credentials_validation`,
  `skip_requesting_account_id`, `skip_s3_checksum`;
- поддержка `If-None-Match` в Object Storage;
- `use_lockfile` работает: обкатан пользователем 2026-11-03.

### Профиль `cloudru`

Новый профиль для Cloud.ru Advanced, требует `external-api`. Навык `cloudru-fact-check` устроен
по образцу `yc-fact-check`. Источники — документация Cloud.ru Advanced и
репозиторий провайдера `sbercloud-terraform/terraform-provider-sbercloud`. Его `facts.md` содержит:
- провайдер `sbercloud-terraform/sbercloud`, который отдаёт и зеркало Yandex Cloud (проверено
  2026-11-03);
- бэкенд `s3` для OBS с `use_lockfile`: обкатан пользователем 2026-11-03.

## Что не меняется

- Способ доставки секретов (SOPS или Vault) — решим, когда подход будет обкатан.
- Пайплайн CI/CD — это профиль `cicd` (T4.1).
- OpenTofu, Terragrunt stacks, `terraform test` и Cloud.ru Evolution в профиль не входят.
- Установщик не меняется: профили собираются из уже поддержанных файлов.

## Затронутые документы

`README.md` (таблица профилей), `docs/00-overview.md` (К4 — список профилей, К13),
`profiles/terraform/README.md`, `profiles/cloudru/README.md`, `profiles/yandex-cloud/README.md`,
`.devcontainer/` (terraform, terragrunt, tflint, trivy, terraform-docs для теста шаблона).

## Готово, когда

- `install.sh <проект> terraform yandex-cloud` и `install.sh <проект> terraform cloudru` — exit 0,
  навыки и шаблоны на месте (тест `test_every_real_profile`).
- Тест шаблона `dev/check-terraform.sh`: на модуле, у которого все проверки проходят, exit 0, на
  модуле с неотформатированным файлом — exit 1. Без утилит тест пропускается, как тест чарта.
- `uv run pytest` и ruff проходят, shellcheck по шаблону чистый.

## Открытые вопросы

Нет.
