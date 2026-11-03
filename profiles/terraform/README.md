# Профиль terraform

Разработка на Terraform и Terragrunt: модули и live-репозитории. Облако задаёт профиль `yandex-cloud` или `cloudru`.

- Навык `terraform-conventions`: Terraform CLI и Terragrunt 1.x; у каждого модуля свой репозиторий,
  у каждого облака свой live-репозиторий `<каталог|проект>/<компонент>/terragrunt.hcl`; модули только из
  внутреннего GitLab по тегу, в том числе зеркала готовых; в модуле нижние границы версий, точные версии и
  lock-файл в live; state в `s3` с `use_lockfile`; `moved`, `removed` и `import` при переносах; секреты.
- Агент работает офлайн: fmt, validate, tflint, trivy, terraform-docs, `terragrunt hcl`. `plan` и
  `apply` запускает человек или CI.
- Сторонние навыки: `terrashark` — типичные ошибки IaC и их предотвращение; `terraform-style-guide` и
  `refactor-module` от HashiCorp. Отступления от них — в `rules.md` профиля.
- Шаблоны (кладутся, если файла нет): `dev/check-terraform.sh` — проверки модуля или live-репозитория,
  вид определяется по `root.hcl`; `.tflint.hcl`; `.pre-commit-config.yaml`. Шаблон `.pre-commit-config.yaml`
  есть и у профиля `helm`: в проекте с обоими профилями ставится первый, второй переносится руками.
- Пункты ревью: секреты, удаление и пересоздание, версии в модулях, `source`, релиз модуля.
- В заготовку раздела проекта: версии Terraform и Terragrunt, адрес модулей, способ доставки секретов.

Нужны: `terraform`, `terragrunt`, `tflint`, `trivy`, `terraform-docs`, `pre-commit`.

Способ доставки секретов (SOPS или Vault), пайплайн CI, OpenTofu, Terragrunt stacks и `terraform test`
в профиль не входят: спецификация `docs/specs/003-terraform-profile.md`.
