#!/usr/bin/env bash
# Проверка Terraform и Terragrunt без облака (навык terraform-conventions).
# Репозиторий модуля (*.tf в корне): terraform fmt, init -backend=false и validate, tflint, trivy config,
# актуальность README от terraform-docs. Live-репозиторий Terragrunt (root.hcl в корне): terragrunt
# hcl fmt --check и hcl validate; validate юнитов читает state и outputs зависимостей, поэтому идёт в CI
# вместе с plan.
# Нужны terraform, tflint, trivy, terraform-docs, для live — terragrunt. init ставит провайдеры из зеркала
# (~/.terraformrc), trivy при первом запуске скачивает правила; облако и ключи не нужны.
# Запуск из любого каталога: dev/check-terraform.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f root.hcl ]; then
  echo "== terragrunt hcl fmt"
  terragrunt hcl fmt --check --diff
  echo "== terragrunt hcl validate"
  terragrunt hcl validate
  echo "live OK"
  exit 0
fi

compgen -G '*.tf' > /dev/null || {
  echo "FAIL: neither root.hcl nor *.tf in $PWD"
  exit 1
}
echo "== terraform fmt"
terraform fmt -check -recursive -diff
echo "== terraform validate"
terraform init -backend=false -input=false > /dev/null
terraform validate
echo "== tflint"
tflint
echo "== trivy"
trivy config --quiet --exit-code 1 --severity HIGH,CRITICAL --tf-exclude-downloaded-modules .
echo "== terraform-docs"
terraform-docs markdown table --output-file README.md --output-check .
echo "module OK"
