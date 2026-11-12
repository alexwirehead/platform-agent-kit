# syntax=docker/dockerfile:1
# Образ для разработки platform-agent-kit: bash-установщик, тесты на pytest через uv
# (решение К10), helm и kubeconform для теста шаблона dev/check-chart.sh, terraform, terragrunt,
# tflint, trivy и terraform-docs для теста шаблона dev/check-terraform.sh, kustomize, flux,
# flux-operator и yq для теста шаблонов dev/check-flux.sh.
# Версии закреплены, загрузки сверяются с sha256 из файлов контрольных сумм
# релизов: при обрыве сети или подмене файла сборка падает. Python скачивает uv
# и сам сверяет его хеш. Обновление — правка ARG вместе с хешами для arm64 и
# amd64, затем Rebuild.
# Базовый образ закреплён по digest: тег 3-ubuntu26.04 переезжает на новые
# сборки. Обновление — новый digest из
# https://mcr.microsoft.com/v2/devcontainers/base/manifests/3-ubuntu26.04.
FROM mcr.microsoft.com/devcontainers/base:3-ubuntu26.04@sha256:91eff046d5c12318fc98e59258982b87ba896c467427ed8b5dab5a02107a5db7

ARG UV_VERSION=0.13.1
ARG UV_SHA256_ARM64=9041c73c99fdc5892cf128140beb354eca9231d502068cc36e6cb53a8e59ad14
ARG UV_SHA256_AMD64=eadd9d27c134ab5ac1ffd4473b97a741407f3ea238288f03121fc4deddf90220
ARG PYTHON_VERSION=3.13.16
# helm и kubeconform — тест шаблона dev/check-chart.sh профиля helm, кластер не нужен.
# Закреплены так же, как uv: версия и sha256 из файлов контрольных сумм релизов.
ARG HELM_VERSION=4.3.0
ARG HELM_SHA256_ARM64=31c5794dd55c66a51e6b7d2e2ac7a114ae8b1de41ff1d9ba51748ac973b06a08
ARG HELM_SHA256_AMD64=86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb
ARG KUBECONFORM_VERSION=0.8.0
ARG KUBECONFORM_SHA256_ARM64=1f53fc8e81258197a35e8603054162a5af1de8c5af13746c71ab680d9534ed87
ARG KUBECONFORM_SHA256_AMD64=9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883
# terraform, terragrunt, tflint, trivy, terraform-docs — тест шаблона dev/check-terraform.sh профиля
# terraform, облако не нужно. Версии старше двух недель на момент выбора, sha256 из файлов
# контрольных сумм релизов.
ARG TERRAFORM_VERSION=1.16.6
ARG TERRAFORM_SHA256_ARM64=a750b5a11038f165846b2658c40c88cd7070aa67a61bab431a14ba27928ea9ea
ARG TERRAFORM_SHA256_AMD64=38034b38d03096399a7a1264a14561a8029b2b496fd1f169452656e53968f1b7
ARG TERRAGRUNT_VERSION=1.1.6
ARG TERRAGRUNT_SHA256_ARM64=44b43df99bae7a309fdb831180bd9efb84fb145cf38a80c139e490395581649d
ARG TERRAGRUNT_SHA256_AMD64=d75a80bb264758ba00dabcb17f4b507fcdab4ca90d9e41f96750df036bf69b04
ARG TFLINT_VERSION=0.64.0
ARG TFLINT_SHA256_ARM64=560da89aacf59389d4eb029730dd5b109b7288096c32f2726a0d9e783a5ea8eb
ARG TFLINT_SHA256_AMD64=cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537
ARG TRIVY_VERSION=0.76.0
ARG TRIVY_SHA256_ARM64=aab21e677a7b7071fc79f1711480840754c18a1b9d9cefa7ccd06af63a0e8f4c
ARG TRIVY_SHA256_AMD64=e24b1c51293c1b15e4ba8d45bbc7891ba053f90278ec2698f3562c993e145fe7
ARG TERRAFORM_DOCS_VERSION=0.24.0
ARG TERRAFORM_DOCS_SHA256_ARM64=d12bd7b73c1fc9c64efc79f8157dd713dabd559f1ecf3cfc0f42e32279a155fd
ARG TERRAFORM_DOCS_SHA256_AMD64=9005daf969de0b50134493a2c00078b49f5f5b39d021cda7c89bf4d4f3d776d3
# kustomize, flux, flux-operator, yq — тест шаблонов dev/check-flux.sh профиля fluxcd, кластер не
# нужен (kubeconform — выше). Версии старше двух недель на момент выбора, sha256 из файлов
# контрольных сумм релизов.
ARG KUSTOMIZE_VERSION=5.8.3
ARG KUSTOMIZE_SHA256_ARM64=9867b76482cfc6d25b546abc1d2b5a32bd137505aba640649b4b378f64f6d68f
ARG KUSTOMIZE_SHA256_AMD64=cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61
ARG FLUX_VERSION=2.10.0
ARG FLUX_SHA256_ARM64=c3c435052e5e18156858bc73f26bcadb62821a6e30951b4b302beb4e65a532c2
ARG FLUX_SHA256_AMD64=208dd7012c04fedeed5b2d0b6e63df3b15b1c34a381527811685c098bc9f8659
ARG FLUX_OPERATOR_VERSION=0.62.1
ARG FLUX_OPERATOR_SHA256_ARM64=4f427dd86747472f83144487404b8f77296660356d0b90859a14abbe6065a8e8
ARG FLUX_OPERATOR_SHA256_AMD64=7bb9e54d370039d8701d4271b38aed57d6c89668432b7caddce69f4e26e24c1b
ARG YQ_VERSION=4.54.1
ARG YQ_SHA256_ARM64=189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b
ARG YQ_SHA256_AMD64=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f
# Задаёт BuildKit: arm64 на Apple Silicon, amd64 на Intel.
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq git unzip \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
      arm64) p=aarch64; sha="${UV_SHA256_ARM64}" ;; \
      amd64) p=x86_64; sha="${UV_SHA256_AMD64}" ;; \
      *) echo "unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    t="$(mktemp -d)"; cd "$t"; \
    curl -fsSL --retry 5 --retry-all-errors -o uv.tgz \
      "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${p}-unknown-linux-gnu.tar.gz"; \
    echo "${sha}  uv.tgz" | sha256sum -c -; \
    tar xzf uv.tgz --strip-components=1 -C /usr/local/bin "uv-${p}-unknown-linux-gnu/uv" "uv-${p}-unknown-linux-gnu/uvx"; \
    cd /; rm -rf "$t"; \
    uv --version

RUN set -eux; \
    case "${TARGETARCH}" in \
      arm64) helm_sha="${HELM_SHA256_ARM64}"; kc_sha="${KUBECONFORM_SHA256_ARM64}" ;; \
      amd64) helm_sha="${HELM_SHA256_AMD64}"; kc_sha="${KUBECONFORM_SHA256_AMD64}" ;; \
      *) echo "unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    t="$(mktemp -d)"; cd "$t"; \
    curl -fsSL --retry 5 --retry-all-errors -o helm.tgz \
      "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz"; \
    echo "${helm_sha}  helm.tgz" | sha256sum -c -; \
    tar xzf helm.tgz --strip-components=1 -C /usr/local/bin "linux-${TARGETARCH}/helm"; \
    curl -fsSL --retry 5 --retry-all-errors -o kubeconform.tgz \
      "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${TARGETARCH}.tar.gz"; \
    echo "${kc_sha}  kubeconform.tgz" | sha256sum -c -; \
    tar xzf kubeconform.tgz -C /usr/local/bin kubeconform; \
    cd /; rm -rf "$t"; \
    helm version --short; kubeconform -v

RUN set -eux; \
    case "${TARGETARCH}" in \
      arm64) tf_sha="${TERRAFORM_SHA256_ARM64}"; tg_sha="${TERRAGRUNT_SHA256_ARM64}"; \
             tl_sha="${TFLINT_SHA256_ARM64}"; tv_sha="${TRIVY_SHA256_ARM64}"; tv_arch=ARM64; \
             td_sha="${TERRAFORM_DOCS_SHA256_ARM64}" ;; \
      amd64) tf_sha="${TERRAFORM_SHA256_AMD64}"; tg_sha="${TERRAGRUNT_SHA256_AMD64}"; \
             tl_sha="${TFLINT_SHA256_AMD64}"; tv_sha="${TRIVY_SHA256_AMD64}"; tv_arch=64bit; \
             td_sha="${TERRAFORM_DOCS_SHA256_AMD64}" ;; \
      *) echo "unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    t="$(mktemp -d)"; cd "$t"; \
    get() { curl -fsSL --retry 5 --retry-all-errors -o "$2" "$1"; echo "$3  $2" | sha256sum -c -; }; \
    get "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
      terraform.zip "${tf_sha}"; \
    unzip -q terraform.zip terraform -d /usr/local/bin; \
    get "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH}" \
      terragrunt "${tg_sha}"; \
    install -m 0755 terragrunt /usr/local/bin/terragrunt; \
    get "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip" \
      tflint.zip "${tl_sha}"; \
    unzip -q tflint.zip tflint -d /usr/local/bin; \
    get "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${tv_arch}.tar.gz" \
      trivy.tgz "${tv_sha}"; \
    tar xzf trivy.tgz -C /usr/local/bin trivy; \
    get "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz" \
      terraform-docs.tgz "${td_sha}"; \
    tar xzf terraform-docs.tgz -C /usr/local/bin terraform-docs; \
    cd /; rm -rf "$t"; \
    terraform version; terragrunt --version; tflint --version; trivy --version; terraform-docs --version

RUN set -eux; \
    case "${TARGETARCH}" in \
      arm64) kz_sha="${KUSTOMIZE_SHA256_ARM64}"; fx_sha="${FLUX_SHA256_ARM64}"; \
             fo_sha="${FLUX_OPERATOR_SHA256_ARM64}"; yq_sha="${YQ_SHA256_ARM64}" ;; \
      amd64) kz_sha="${KUSTOMIZE_SHA256_AMD64}"; fx_sha="${FLUX_SHA256_AMD64}"; \
             fo_sha="${FLUX_OPERATOR_SHA256_AMD64}"; yq_sha="${YQ_SHA256_AMD64}" ;; \
      *) echo "unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    t="$(mktemp -d)"; cd "$t"; \
    get() { curl -fsSL --retry 5 --retry-all-errors -o "$2" "$1"; echo "$3  $2" | sha256sum -c -; }; \
    get "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" \
      kustomize.tgz "${kz_sha}"; \
    tar xzf kustomize.tgz -C /usr/local/bin kustomize; \
    get "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${TARGETARCH}.tar.gz" \
      flux.tgz "${fx_sha}"; \
    tar xzf flux.tgz -C /usr/local/bin flux; \
    get "https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v${FLUX_OPERATOR_VERSION}/flux-operator_${FLUX_OPERATOR_VERSION}_linux_${TARGETARCH}.tar.gz" \
      flux-operator.tgz "${fo_sha}"; \
    tar xzf flux-operator.tgz -C /usr/local/bin flux-operator; \
    get "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" yq "${yq_sha}"; \
    install -m 0755 yq /usr/local/bin/yq; \
    cd /; rm -rf "$t"; \
    kustomize version; flux version --client; yq --version

# Python ставится в общий каталог, а не в домашний root: так его видит
# пользователь vscode. Владелец vscode, чтобы uv в контейнере мог доставить
# другую версию, если её попросит проект.
# UV_LINK_MODE=copy: кеш uv лежит в контейнере, а .venv — в папке проекта на
# маке; жёсткие ссылки между ними невозможны, и без этой настройки uv на
# каждой установке пишет предупреждение.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python \
    UV_LINK_MODE=copy
RUN uv python install --no-bin "${PYTHON_VERSION}" \
    && chown -R vscode:vscode "${UV_PYTHON_INSTALL_DIR}" \
    && uv python find "${PYTHON_VERSION}"

# Точки монтирования создаются заранее с владельцем vscode: Docker копирует
# владельца из образа в новый именованный том, и chown после старта не нужен.
RUN install -d -o vscode -g vscode \
      /home/vscode/.claude /home/vscode/.agents /home/vscode/.shell-history \
      /home/vscode/.vscode-server \
    && printf '%s\n' 'HISTFILE=~/.shell-history/bash_history' \
       'PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"' >> /home/vscode/.bashrc \
    && printf '%s\n' 'HISTFILE=~/.shell-history/zsh_history' >> /home/vscode/.zshenv \
    && chown vscode:vscode /home/vscode/.zshenv
