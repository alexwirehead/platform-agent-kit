# 006. Профили fluxcd и fluxcd-debug: GitOps на Flux Operator

Статус: сделана 2026-11-12
Задачи: T4.2 [x]
Решения: К16

## Зачем

Нужны правила для GitOps-репозиториев на Flux Operator. Модель уже обкатана пользователем: два
репозитория (fleet и компоненты), гибрид ControlPlane D1/D2, работает на лабораторном кластере.
Источники — ADR пользователя о движке, структуре и окружениях, самообслуживании, проверках CI,
секретах и именах файлов, его скрипты проверок и интервью 2026-11-12 (К4). В кит всё это попадает
без внутренних имён (правило кита 6).

## Что меняется

### Профиль `fluxcd`

Свой навык `flux-gitops`: правила ниже, раскладка обоих репозиториев, поток выпуска компонента.

- **Движок — Flux Operator.**
  - `FluxInstance` с `multitenant: true` в каждом кластере, pull-модель.
  - Flux управляет собой из Git: `FluxInstance` лежит в fleet-репозитории, смена версии Flux — MR.
  - Bootstrap делает Terraform: чарт оператора, токены доступа к Git, первичный `FluxInstance`.
    После этого Flux владеет `FluxInstance`, а не Terraform.
- **Два репозитория** с обобщёнными именами `<fleet>` и `<components>`:
  - fleet — окружения, кластеры, тенанты (`ResourceSet`) и заказы сервисов;
  - components — манифесты компонентов.

  Права разделены на уровне реконсиляции: инфраструктура применяется под `cluster-admin`, сервисы —
  с правами администратора namespace. Право записи в fleet и в инфраструктуру components
  равносильно `cluster-admin`.
- **Источники и версии (гибрид D1/D2).**
  - У каждого компонента свой `GitRepository`. `spec.ignore` оставляет в артефакте только папку
    компонента, `spec.ref.name` — `refs/heads/main` или `refs/tags/<component>/vX.Y.Z`.
  - Версии записаны в `environments/<env>/versions.yaml`: ConfigMap с ключами `<COMPONENT>_REF`,
    который подключается через `postBuild.substituteFrom`.
  - Шаблоны ссылаются на `${<COMPONENT>_REF}` без значения по умолчанию. При включённом
    `StrictPostBuildSubstitutions` пропущенная переменная останавливает реконсиляцию.
  - В `main` смотрит только dev-среда платформы, остальные окружения — только в защищённые теги
    `*/v*`.
  - Выпуск: мёрж в `main`, проверка в dev-среде платформы, тег, MR в `environments/dev`, затем
    `environments/prod`.
- **Раскладка.**
  - components: `infra/<c>/{controllers,configs}/{base,dev,prod}`, сервисы — `<group>/<c>/{base,dev,prod}`.
    Оверлеи меняют только размеры, реплики, эндпоинты и ссылки на секреты. Структурных различий
    в оверлеях нет.
  - fleet: кластер — это папка `clusters/<project>/<env>/<cluster>/`. В ней лежат `flux-system/`
    (`FluxInstance`, `sync.path` равен пути папки), `runtime-info.yaml` без секретов
    (`ENVIRONMENT`, `CLUSTER_NAME`) и явный `kustomization.yaml` с версиями своего окружения.
  - `tenants/policies` применяется раньше остальных тенантов (`dependsOn`).
  - Lockdown запрещает ссылки между namespace, поэтому общие Secret и `runtime-info` копируются
    в namespace тенанта аннотацией `fluxcd.controlplane.io/copyFrom`.
- **Сервис — один файл.** Заказ — `ResourceSetInputProvider` типа `Static` в папке заказов
  кластера (`data-services/`, `apps/`), с меткой своего шаблона. Общий `ResourceSet` собирает
  такие файлы через `inputsFrom` с селектором. Шаблон ставит `fluxcd.controlplane.io/prune: disabled`
  на namespace и Kustomization сервиса, параметры передаёт через `valuesFrom` из ConfigMap с меткой
  `reconcile.fluxcd.io/watch: Enabled` и создаёт `Alert` о развёртывании. В папке заказов нет
  ничего, кроме заказов: она применяется под `cluster-admin`.
- **Имена файлов:** только `.yaml`, строчные через дефис, `values.yaml`, `secrets.sops.yaml`.
  Незашифрованного `Secret` в Git нет. Способ доставки секретов (ESO, SOPS) кит не задаёт: опыт
  ещё не накоплен, решение пользователя.
- **Агент работает офлайн.** Ему разрешены `kustomize build`, `flux envsubst`,
  `flux-operator build rset`, kubeconform и шаблоны проверок. `kubectl`, `flux reconcile` и любой
  доступ к кластеру ему запрещены, кроме профиля `fluxcd-debug`.
- **Проверки — шаблоны из обкатанных скриптов пользователя:**
  - `dev/check-flux.sh` — точка входа. Если в корне есть `clusters/` и `environments/`, это
    fleet-репозиторий, и выполняются все проверки ниже. Иначе это репозиторий компонентов, и
    выполняются соглашения и оверлеи;
  - `dev/flux/check-conventions.sh` — расширение, имена, `Secret` только с метаданными SOPS;
  - `dev/flux/check-refs.sh` — ссылки ровно `${<NAME>_REF}`, ключи и значения `versions.yaml`;
  - `dev/flux/validate-overlays.sh` — `kustomize build` каждого оверлея с опциями
    kustomize-controller и kubeconform со схемами Flux и Flux Operator;
  - `dev/flux/validate-fleet.sh` — окружение и имя кластера в трёх местах, только теги вне
    dev-среды платформы, `flux envsubst --strict`, `flux-operator build rset` с каждым заказом,
    `GitRepository` только на `refs/heads/` или `refs/tags/`, уникальные имена заказов, в папках
    заказов только заказы.

  Имя проекта dev-среды платформы и ключ метки заказов вынесены в переменные в начале
  `validate-fleet.sh`. Пока там плейсхолдер, скрипт падает.
- **Сторонние навыки** (К3, коммит закрепляется после чтения навыка целиком): `gitops-knowledge`
  и `gitops-repo-audit` из `fluxcd/agent-skills`. Отступления от них записываются в `rules.md`
  профиля.
- **Пункты ревью:**
  - версия компонента вне dev-среды платформы — защищённый тег;
  - различия оверлеев не структурные;
  - в папке заказов только заказы;
  - в `runtime-info.yaml` нет секретов;
  - нет незашифрованного `Secret`;
  - у изменения prune или удаления есть причина.

### Профиль `fluxcd-debug`

Профиль требует `fluxcd` и ставит сторонний навык `gitops-cluster-debug` с правилами:

- кластер доступен только через MCP-сервер Flux Operator, запущенный с `serve --read-only`
  (tools reconcile, suspend, resume, apply и delete отключены) и с `--mask-secrets` (так по
  умолчанию);
- MCP-сервер настраивает пользователь, установщик его не настраивает;
- агент ничего не меняет в кластере, а исправление делает MR в репозиторий.

Это отступление от правила «агент не ходит в реальную систему», как К14 у `glab ci lint` (К16).

В `INSTALL.md` у `fluxcd-debug` вместо признака стоит вопрос: если ставится `fluxcd`, агент
спрашивает, нужна ли отладка живого кластера. По умолчанию не ставит.

## Что не меняется

- Установщик.
- Доставка секретов, change gates (автомёрж, gate для prod), перенос с Argo CD — в кит не входят.
- Проверки повторяют обкатанные скрипты. `validate-fleet.sh` требует bash 4+ (`declare -A`):
  на macOS — bash из Homebrew. Схемы CRD скачиваются с последних релизов Flux и Flux Operator,
  как в исходном скрипте.

## Затронутые документы

`README.md` (таблица профилей), `docs/00-overview.md` (К4, К16), `INSTALL.md` (строки `fluxcd`,
`fluxcd-debug`), `TASKS.md` (T4.2), `profiles/fluxcd/README.md`, `profiles/fluxcd-debug/README.md`,
`.devcontainer/` (kustomize, kubeconform, flux, flux-operator, yq для теста шаблонов).

## Готово, когда

- `install.sh <проект> fluxcd` и `install.sh <проект> fluxcd-debug` — exit 0
  (`test_every_real_profile`); `fluxcd-debug` подтягивает `fluxcd`.
- Тест шаблонов на минимальных fleet- и components-репозиториях во временном каталоге: на
  корректных exit 0, на опечатке `{X_REF}`, на ветке в версиях пользовательского окружения и на
  файле `.yml` — exit 1. Без утилит тест пропускается.
- `uv run pytest` и ruff проходят, shellcheck по шаблонам чистый.

## Открытые вопросы

Нет.
