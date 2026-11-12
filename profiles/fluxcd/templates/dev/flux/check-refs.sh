#!/usr/bin/env bash
# Версии компонентов задаются только переменными <КОМПОНЕНТ>_REF из
# environments/*/versions.yaml (навык flux-gitops). Опечатка вроде
# "{DEMO_REF}" или "$DEMO_REF" — это обычная строка: flux envsubst её
# не трогает, ResourceSet собирается, а GitRepository падает уже в кластере.
# Проверяется:
#   - в tenants/*/resourceset.yaml каждый spec.inputs[].ref — ровно "${<ИМЯ>_REF}";
#   - в заказах clusters/<проект>/<окружение>/<кластер>/<папка заказов>
#     spec.defaultValues.ref — ровно "${<ИМЯ>_REF}";
#   - в environments/*/versions.yaml все ключи — <ИМЯ>_REF, значения — refs/heads/...
#     или refs/tags/... (иначе ключ не попадёт под проверку тегов в validate-fleet.sh).
# Папки заказов — ORDERS из dev/check-flux.sh. Требуется: yq >= 4.
set -o errexit -o nounset -o pipefail

root="${1:-.}"
fail=0

export REF_VAR_RE='^\$\{[A-Z][A-Z0-9_]*_REF\}$'
export REF_KEY_RE='^[A-Z][A-Z0-9_]*_REF$'
export REF_VALUE_RE='^refs/(heads|tags)/[^[:space:]]+$'

# Печатает каждый ref, который не равен "${<ИМЯ>_REF}".
# $1 — выражение yq, дающее список ref документа, $2 — файл.
bad_refs() {
  yq ea "select(. != null) | $1 | select((tag != \"!!str\") or (test(strenv(REF_VAR_RE)) | not))" "$2" \
    | grep -v '^---$' || true
}

report() {
  local f="$1" what="$2" bad="$3"
  [[ -z "$bad" ]] && return
  echo "ERROR - ${f}: ${what} должен быть ровно \"\${<ИМЯ>_REF}\", найдено: ${bad//$'\n'/, }"
  fail=1
}

for f in "$root"/tenants/*/resourceset.yaml; do
  [[ -e "$f" ]] || continue
  report "$f" "spec.inputs[].ref" "$(bad_refs '.spec.inputs[]? | select(has("ref")) | .ref' "$f")"
done

for order in ${ORDERS:-data-services=data-service apps=app}; do
  for f in "$root"/clusters/*/*/*/"${order%%=*}"/*.yaml; do
    [[ -e "$f" ]] || continue
    report "$f" "spec.defaultValues.ref" "$(bad_refs '.spec.defaultValues.ref' "$f")"
  done
done

for f in "$root"/environments/*/versions.yaml; do
  [[ -e "$f" ]] || continue
  bad="$(yq '.data | to_entries | .[] | select((.key | test(strenv(REF_KEY_RE)) | not) or (.value | test(strenv(REF_VALUE_RE)) | not)) | .key + ": " + .value' "$f")"
  if [[ -n "$bad" ]]; then
    echo "ERROR - ${f}: нужны ключи <ИМЯ>_REF со значениями refs/heads/... или refs/tags/..., не подходят: ${bad//$'\n'/, }"
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "INFO - Ссылки на версии корректны"
