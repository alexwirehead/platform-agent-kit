#!/usr/bin/env bash
# Сборка каждого оверлея kustomize и проверка схем kubeconform (навык flux-gitops):
# сборка — с теми же опциями, что у kustomize-controller.
# Требуется: kustomize >= 5, kubeconform >= 0.7, curl.
set -o errexit -o nounset -o pipefail

root="${1:-.}"
schemas="${FLUX_SCHEMAS_DIR:-/tmp/flux-crd-schemas}"

if [[ ! -d "$schemas/master-standalone-strict" ]]; then
  mkdir -p "$schemas/master-standalone-strict"
  curl -sL https://github.com/controlplaneio-fluxcd/flux-operator/releases/latest/download/crd-schemas.tar.gz \
    | tar zxf - -C "$schemas/master-standalone-strict"
  curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz \
    | tar zxf - -C "$schemas/master-standalone-strict"
fi

kubeconform_args=(-strict -ignore-missing-schemas -skip=Secret
  -schema-location default -schema-location "$schemas" -summary)

while IFS= read -r -d '' k; do
  dir="$(dirname "$k")"
  echo "INFO - kustomize build ${dir}"
  kustomize build --load-restrictor=LoadRestrictionsNone "$dir" | kubeconform "${kubeconform_args[@]}"
done < <(find "$root" -path '*/.*' -prune -o -path '*/terraform' -prune -o -type f -name kustomization.yaml -print0 | sort -z)

echo "INFO - Все оверлеи собираются"
