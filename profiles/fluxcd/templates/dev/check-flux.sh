#!/usr/bin/env bash
# Проверка GitOps-репозитория Flux без кластера (навык flux-gitops).
# fleet-репозиторий (в корне clusters/ и environments/): соглашения, ссылки на версии, оверлеи,
# сборка каждого кластера. Репозиторий компонентов: соглашения и оверлеи.
# Нужны kustomize, kubeconform, yq 4, для fleet — flux, flux-operator и bash 4+ (на macOS — из Homebrew).
# Схемы CRD Flux и Flux Operator validate-overlays.sh скачивает при первом запуске (сеть).
# Запуск из любого каталога: dev/check-flux.sh
set -euo pipefail

# Настройки проекта: заменить плейсхолдеры при установке шаблона.
# Проект dev-среды платформы: единственный, чьи кластеры следуют за main компонентов.
export PLATFORM_PROJECT="<platform-project>"
# Ключ метки заказа сервиса на ResourceSetInputProvider.
export ORDER_LABEL="<domain>/kind"
# Папки заказов в кластере и значение метки для каждой: <папка>=<значение>.
export ORDERS="data-services=data-service apps=app"

cd "$(dirname "$0")/.."
here="dev/flux"

if [ -d clusters ] && [ -d environments ]; then
  case "$PLATFORM_PROJECT$ORDER_LABEL" in
    *"<"*) echo "FAIL: set PLATFORM_PROJECT and ORDER_LABEL in dev/check-flux.sh"; exit 1 ;;
  esac
  "$here/check-conventions.sh" .
  "$here/check-refs.sh" .
  "$here/validate-overlays.sh" .
  "$here/validate-fleet.sh" .
  echo "fleet OK"
else
  "$here/check-conventions.sh" .
  "$here/validate-overlays.sh" .
  echo "components OK"
fi
