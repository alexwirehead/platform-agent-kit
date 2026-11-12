#!/usr/bin/env bash
# Проверки fleet-репозитория, повторяющие то, что сделает Flux в кластере
# (навык flux-gitops):
#   - окружение кластера: папка clusters/<проект>/<окружение>/, ENVIRONMENT
#     в runtime-info.yaml и путь к версиям совпадают. Проект dev-среды платформы
#     (PLATFORM_PROJECT) берёт версии из environments/<PLATFORM_PROJECT>-<окружение>,
#     остальные проекты — из общего environments/<окружение>;
#   - пользовательские проекты смотрят только в теги: в их environments/
#     все *_REF — refs/tags/...;
#   - CLUSTER_NAME совпадает с именем папки и уникален в проекте;
#   - flux envsubst --strict: все ${VAR} определены в runtime-info.yaml
#     кластера и versions.yaml его окружения;
#   - flux-operator build rset: шаблоны tenants/ собираются с входными
#     данными каждого заказа в clusters/<проект>/<окружение>/<кластер>/<папка заказов>;
#   - в собранных ResourceSet каждый GitRepository смотрит в refs/heads/...
#     или refs/tags/...: страховка к check-refs.sh от опечаток в ${..._REF};
#   - имена заказов (name) уникальны в кластере: каждое имя — это namespace;
#   - в папках заказов только заказы: ResourceSetInputProvider с меткой
#     ORDER_LABEL своей папки.
# Настройки PLATFORM_PROJECT, ORDER_LABEL, ORDERS — в dev/check-flux.sh.
# Требуется: bash 4+, kustomize, flux, flux-operator, yq.
set -o errexit -o nounset -o pipefail

root="${1:-.}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "ERROR - $*"; exit 1; }

platform_project="${PLATFORM_PROJECT:?set PLATFORM_PROJECT in dev/check-flux.sh}"
order_label="${ORDER_LABEL:?set ORDER_LABEL in dev/check-flux.sh}"
# Папка заказов => значение метки ORDER_LABEL.
declare -A orders=()
for order in ${ORDERS:-data-services=data-service apps=app}; do
  orders[${order%%=*}]="${order#*=}"
done

# Kustomization папки заказов применяет её под cluster-admin, поэтому в ней
# допустимы только ResourceSetInputProvider с меткой своего шаблона. Объекты
# читаются из потока YAML на stdin; $1 — что проверяем, $2 — значение метки.
check_orders_only() {
  local rel="$1" kind_label="$2" bad
  bad="$(yq -N 'select(. != null) | select(
      (.apiVersion == "fluxcd.controlplane.io/v1" and .kind == "ResourceSetInputProvider"
        and .metadata.namespace == "flux-system"
        and .metadata.labels["'"$order_label"'"] == "'"$kind_label"'") | not)
    | .kind + "/" + (.metadata.name // "?")')"
  [[ -z "$bad" ]] || fail "${rel}: допустимы только ResourceSetInputProvider с меткой ${order_label}: ${kind_label}, найдено: ${bad//$'\n'/, }"
}

# Опечатка в ссылке на переменную ("{X_REF}" вместо "${X_REF}") проходит
# envsubst и build rset и ломает GitRepository только в кластере. Объекты
# собранного ResourceSet читаются из потока YAML на stdin, $1 — что проверяем.
# После сборки {X_REF} без кавычек — уже не строка, а YAML-словарь.
check_git_refs() {
  local rel="$1" bad
  bad="$(yq -N 'select(.kind == "GitRepository")
    | select(.spec.ref.name | if tag == "!!str" then test("^refs/(heads|tags)/[^[:space:]]+$") else false end | not)
    | .metadata.namespace + "/" + .metadata.name + ": " + (.spec.ref.name | to_json(0))')"
  [[ -z "$bad" ]] || fail "${rel}: GitRepository должен смотреть в refs/heads/... или refs/tags/..., найдено: ${bad//$'\n'/, }"
}

declare -A seen=()

for cluster_dir in "$root"/clusters/*/*/*/; do
  cluster_dir="${cluster_dir%/}"
  cluster="$(basename "$cluster_dir")"
  env_name="$(basename "$(dirname "$cluster_dir")")"
  project="$(basename "$(dirname "$(dirname "$cluster_dir")")")"
  id="${project}/${env_name}/${cluster}"
  if [[ "$project" == "$platform_project" ]]; then
    versions_dir="${platform_project}-${env_name}"
  else
    versions_dir="$env_name"
  fi
  echo "INFO - Кластер ${id}"

  # Окружение и имя кластера.
  runtime="$cluster_dir/runtime-info.yaml"
  [[ -f "$runtime" ]] || fail "${id}: нет runtime-info.yaml"
  [[ "$(yq '.data.ENVIRONMENT' "$runtime")" == "$env_name" ]] \
    || fail "${id}: ENVIRONMENT в runtime-info.yaml не совпадает с папкой окружения"
  [[ "$(yq '.data.CLUSTER_NAME' "$runtime")" == "$cluster" ]] \
    || fail "${id}: CLUSTER_NAME в runtime-info.yaml не совпадает с именем папки"
  env_refs="$(yq '.resources[] | select(test("environments/"))' "$cluster_dir/kustomization.yaml")"
  [[ "$env_refs" == "../../../../environments/${versions_dir}" ]] \
    || fail "${id}: kustomization.yaml должен подключать ровно ../../../../environments/${versions_dir}, а подключает: ${env_refs:-ничего}"
  [[ "$(yq '.spec.sync.path' "$cluster_dir/flux-system/flux-instance.yaml")" == "clusters/${id}" ]] \
    || fail "${id}: sync.path в FluxInstance не равен clusters/${id}"
  if [[ -n "${seen[$project/$cluster]:-}" ]]; then
    fail "имя кластера ${cluster} занято в проекте ${project} дважды: окружения ${seen[$project/$cluster]} и ${env_name}"
  fi
  seen[$project/$cluster]="$env_name"

  versions="$root/environments/$versions_dir/versions.yaml"
  [[ -f "$versions" ]] || fail "${id}: нет ${versions}"
  if [[ "$project" != "$platform_project" ]]; then
    not_tags="$(yq '.data | to_entries | .[] | select(.key | test("_REF$")) | select(.value | test("^refs/tags/") | not) | .key' "$versions")"
    [[ -z "$not_tags" ]] \
      || fail "${id}: пользовательские кластеры смотрят только в теги, в environments/${versions_dir} не теги: ${not_tags//$'\n'/, }"
  fi

  # Переменные кластера: runtime-info + версии окружения.
  vars="$tmp/vars.env"
  yq '.data | to_entries | .[] | .key + "=" + .value' \
    "$runtime" "$versions" | grep -v "^---$" > "$vars"

  # Корень кластера собирается без подстановок, как Kustomization flux-system.
  kustomize build --load-restrictor=LoadRestrictionsNone "$cluster_dir" > /dev/null

  # Тенанты: infra и шаблон каждой папки заказов, если он есть.
  for tenant in infra "${!orders[@]}"; do
    [[ -d "$root/tenants/$tenant" ]] || continue
    # shellcheck disable=SC2046 # переменные из vars.env — отдельные аргументы env
    env -i PATH="$PATH" $(cat "$vars") sh -c \
      "kustomize build --load-restrictor=LoadRestrictionsNone '$root/tenants/$tenant' | flux envsubst --strict" \
      > "$tmp/$tenant.yaml"
  done
  if [[ -f "$tmp/infra.yaml" ]]; then
    flux-operator build rset -f "$tmp/infra.yaml" | check_git_refs "${id}: tenants/infra"
    echo "INFO -   tenants/infra: ok"
  fi

  declare -A names=()
  for dir in "${!orders[@]}"; do
    # В папках заказов нет ничего, кроме заказов.
    for f in "$cluster_dir/$dir"/*; do
      [[ -e "$f" ]] || continue
      [[ -f "$f" && "$f" == *.yaml ]] || fail "${id}: ${f#"$cluster_dir"/}: в папке заказов допустимы только файлы .yaml"
      check_orders_only "${id}/${f#"$cluster_dir"/}" "${orders[$dir]}" < "$f"
    done
    for f in "$cluster_dir/$dir"/*.yaml; do
      [[ -e "$f" ]] || continue
      [[ -f "$tmp/$dir.yaml" ]] || fail "${id}: есть заказы в ${dir}/, но нет шаблона tenants/${dir}"
      rel="${dir}/$(basename "$f")"
      # Комментарии снимаются до подстановки: Flux подставляет переменные
      # после kustomize build, а он комментарии не сохраняет.
      # shellcheck disable=SC2046
      yq '... comments=""' "$f" \
        | env -i PATH="$PATH" $(cat "$vars") flux envsubst --strict > "$tmp/input.yaml"
      name="$(yq '.spec.defaultValues.name' "$tmp/input.yaml")"
      if [[ -n "${names[$name]:-}" ]]; then
        fail "${id}: имя ${name} уже занято (${names[$name]} и ${rel}): это один namespace"
      fi
      names[$name]="$rel"
      flux-operator build rset -f "$tmp/$dir.yaml" \
        --inputs-from-provider "$tmp/input.yaml" | check_git_refs "${id}/${rel}"
      echo "INFO -   ${rel}: ok"
    done
  done
  unset names
  rm -f "$tmp"/*.yaml
done

[[ ${#seen[@]} -gt 0 ]] || fail "в clusters/<проект>/<окружение>/ нет ни одного кластера"
echo "INFO - fleet-репозиторий собирается для всех кластеров"
