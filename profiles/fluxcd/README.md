# Профиль fluxcd

GitOps на Flux Operator: fleet-репозиторий и репозиторий компонентов, гибрид D1/D2.

- Навык `flux-gitops`: `FluxInstance` с `multitenant: true` и bootstrap через Terraform; два репозитория;
  `GitRepository` на компонент, версии `<COMPONENT>_REF` в `environments/<env>/versions.yaml`, вне
  dev-среды платформы — только защищённые теги; раскладка `{controllers,configs}/{base,dev,prod}`;
  кластер — папка, сервис — файл `ResourceSetInputProvider`; имена файлов.
- Агент работает офлайн: `kustomize build`, `flux envsubst`, `flux-operator build rset`, `flux schema`,
  kubeconform. В кластер не ходит; отладка живого кластера — профиль `fluxcd-debug`.
- Сторонние навыки из `fluxcd/agent-skills`: `gitops-knowledge` — поля CRD Flux по схемам;
  `gitops-repo-audit` — аудит репозитория. Отступления — в `rules.md` профиля.
- Шаблоны (кладутся, если файла нет): `dev/check-flux.sh` — точка входа, вид репозитория по
  `clusters/` и `environments/`; `dev/flux/` — соглашения, ссылки на версии, оверлеи, сборка кластеров.
  В начале `dev/check-flux.sh` — имя проекта dev-среды платформы и метка заказов: пока плейсхолдер,
  проверка fleet падает.
- Пункты ревью: теги вне dev-среды, оверлеи, папки заказов, секреты, prune и удаление.

Нужны: `kustomize`, `kubeconform`, `yq` 4, для fleet — `flux` 2.10+, `flux-operator`, bash 4+.
