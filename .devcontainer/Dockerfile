# syntax=docker/dockerfile:1
# Образ для разработки platform-agent-kit: bash-установщик, тесты на pytest через uv
# (решение К10), helm и kubeconform для теста шаблона dev/check-chart.sh.
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
# Задаёт BuildKit: arm64 на Apple Silicon, amd64 на Intel.
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq git \
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
