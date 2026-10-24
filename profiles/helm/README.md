# Профиль helm

Helm-чарты по правилам команды.

- Навык `helm-conventions`: раскладка чарта, аннотации values для helm-docs и `@schema`, генерация
  README и схемы через pre-commit, секреты через SOPS или Vault (bank-vaults), NetworkPolicy только для
  привилегированных контейнеров, сборка и публикация.
- Сторонний навык `helm-chart-scaffolding`: общие практики чартов.
- Шаблоны (кладутся, если файла нет): `dev/check-chart.sh` — проверка всех чартов в `deploy/helm/`
  без кластера; `.pre-commit-config.yaml` — хуки, в `helm-schema` подставить имя чарта.
- Пункты ревью: версия, аннотации values, секреты, securityContext.

Нужны: `helm`, `kubeconform`, `helm-docs`, плагин `helm schema`, `pre-commit`.
