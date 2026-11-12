#!/usr/bin/env bash
# Проверка GitLab CI без GitLab (навык gitlab-ci-components).
# yamllint — .gitlab-ci.yml, .gitlab/ci/*.yml и шаблоны компонентов templates/; схема GitLab CI
# (check-jsonschema) — только .gitlab-ci.yml и .gitlab/ci/*.yml: у шаблона два документа, а input
# с type number или boolean до подстановки — строка, схема дала бы ложную ошибку. Шаблон целиком
# проверяет пайплайн репозитория компонента и glab ci lint. shellcheck — .gitlab/ci/scripts/.
# Нужны yamllint, check-jsonschema, shellcheck.
# Запуск из любого каталога: dev/check-ci.sh
set -euo pipefail

cd "$(dirname "$0")/.."
shopt -s nullglob

pipelines=(.gitlab/ci/*.yml)
[ ! -f .gitlab-ci.yml ] || pipelines+=(.gitlab-ci.yml)
templates=(templates/*.yml templates/*/template.yml)
scripts=(.gitlab/ci/scripts/*.sh)
# ${a[@]+...}: пустой массив при set -u в bash 3.2 (macOS) иначе падает.
yaml=(${pipelines[@]+"${pipelines[@]}"} ${templates[@]+"${templates[@]}"})

if [ ${#yaml[@]} -eq 0 ]; then
  echo "FAIL: neither .gitlab-ci.yml, .gitlab/ci/*.yml nor templates/ in $PWD"
  exit 1
fi
echo "== yamllint"
yamllint --strict -d '{extends: default, rules: {document-start: disable, line-length: disable}}' "${yaml[@]}"
if [ ${#pipelines[@]} -gt 0 ]; then
  echo "== check-jsonschema"
  check-jsonschema --builtin-schema vendor.gitlab-ci "${pipelines[@]}"
fi
if [ ${#scripts[@]} -gt 0 ]; then
  echo "== shellcheck"
  shellcheck "${scripts[@]}"
fi
echo "ci OK"
