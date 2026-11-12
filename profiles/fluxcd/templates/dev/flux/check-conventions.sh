#!/usr/bin/env bash
# Соглашения об именах и секретах (навык flux-gitops):
# только .yaml, имена строчные через дефис, Secret только зашифрованный SOPS.
# Требуется: yq >= 4.
set -o errexit -o nounset -o pipefail

root="${1:-.}"
fail=0

while IFS= read -r -d '' f; do
  echo "ERROR - ${f}: расширение .yml, нужно .yaml"
  fail=1
done < <(find "$root" -path '*/.*' -prune -o -type f -name '*.yml' -print0)

while IFS= read -r -d '' f; do
  name="$(basename "$f")"
  if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*)*\.yaml$ ]]; then
    echo "ERROR - ${f}: имя не по правилу «строчные, через дефис»"
    fail=1
  fi
  # Каждый документ kind: Secret должен содержать метаданные SOPS.
  plain="$(yq ea 'select(.kind == "Secret" and has("sops") | not) | .metadata.name' "$f" 2>/dev/null | grep -v '^---$' || true)"
  if [[ -n "$plain" ]]; then
    echo "ERROR - ${f}: Secret без шифрования SOPS: ${plain//$'\n'/, }"
    fail=1
  fi
done < <(find "$root" -path '*/.*' -prune -o -type f -name '*.yaml' -print0)

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "INFO - Соглашения соблюдены"
