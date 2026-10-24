#!/usr/bin/env bash
# Проверка Helm-чартов без кластера: lint и рендер для каждого ci/*-values.yaml, kubeconform,
# обязательные values. Нужны helm и kubeconform; kubeconform берёт схемы Kubernetes из сети
# (github.com/yannh/kubernetes-json-schema), кеш переживает запуски.
# Запуск из любого каталога: dev/check-chart.sh
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
SCHEMAS="${XDG_CACHE_HOME:-$HOME/.cache}/kubeconform"
mkdir -p "$SCHEMAS"

# expect_fail <чарт> <ожидаемый текст ошибки> <аргументы helm template...>
expect_fail() {
  local chart="$1" message="$2" out
  shift 2
  if out="$(helm template check "$chart" "$@" 2>&1)"; then
    echo "FAIL: rendered without error, expected: $message"
    exit 1
  fi
  grep -qF "$message" <<< "$out" || { echo "FAIL: expected '$message', got: $out"; exit 1; }
  echo "ok: $message"
}

for chart in deploy/helm/*/; do
  chart="${chart%/}"
  for values in "$chart"/ci/*-values.yaml; do
    [ -f "$values" ] || { echo "FAIL: $chart has no ci/*-values.yaml"; exit 1; }
    name="$(basename "$chart")-$(basename "$values" -values.yaml)"
    echo "== $name"
    helm lint --strict "$chart" -f "$values"
    helm template check "$chart" -f "$values" > "$OUT/$name.yaml"
  done
done

echo "== kubeconform"
# CRD без схемы в стандартном каталоге kubeconform пропускаются: -skip ServiceMonitor,...
kubeconform -strict -summary -cache "$SCHEMAS" "$OUT"/*.yaml

echo "== required values"
# Обязательные values: без них рендер падает с понятной ошибкой, а не Pod на старте. Пример:
# expect_fail deploy/helm/app "at '/image/repository'" --set image.repository=

echo "charts OK"
