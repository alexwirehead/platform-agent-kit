---
name: yc-fact-check
description: Verify a fact about the Yandex Cloud API (REST path, host, field, enum values, error codes, role, behaviour of the yandexcloud Python SDK) at the primary source — cloudapi proto, endpoint registry, api-ref pages, python-sdk code — and record it with the source; start from the verified general facts in facts.md. Use whenever a project needs a Yandex Cloud API fact. Триггеры — Yandex Cloud, YC, cloudapi, proto, yandexcloud SDK, роль, IAM-токен, сервисный аккаунт.
---

# Checking a fact about the Yandex Cloud API

The procedure and recording rules are those of `api-fact-check`; this skill adds the Yandex Cloud
sources. General facts already verified are in `facts.md` next to this file — read it first and
re-check a fact at its source if the project depends on it and the date is old.

## Sources, most reliable first

1. Proto files: `https://github.com/yandex-cloud/cloudapi`.
   ```bash
   D=<scratchpad>/cloudapi
   [ -d "$D" ] || git clone --depth 1 https://github.com/yandex-cloud/cloudapi.git "$D"
   git -C "$D" log -1 --format='%H %cd'      # record the hash next to the fact
   ```
   - REST path: `grep -n -A3 'rpc <Method>(' "$D"/yandex/cloud/<service>/v1/*_service.proto` → `get:`/`post:`.
   - Enums and fields: the resource `*.proto`. The value numbered 0 is the default and never appears in JSON.
   - Constraints: options `(value)`, `(length)`, `(required)`.
2. Host registry: `curl -s https://api.cloud.yandex.net/endpoints | jq -r '.endpoints[]|"\(.id) \(.address)"'`
   (public, no auth).
3. Docs: `https://yandex.cloud/ru/docs/<service>/api-ref/<Resource>/<method>` (REST address, camelCase
   fields, response example) and `https://yandex.cloud/ru/docs/<service>/security/` (roles). Pages are
   large: download with `curl` into the scratchpad, convert to text, search in it.
4. Behaviour of the `yandexcloud` SDK (stubs, discovery, token, retries): SDK code of the version in
   `uv.lock`, not its README.
   ```bash
   S=<scratchpad>/python-sdk
   [ -d "$S" ] || git clone --depth 1 https://github.com/yandex-cloud/python-sdk.git "$S"
   grep -oE '^class [A-Za-z]+Stub' "$S"/yandex/cloud/<service>/v1/<x>_service_pb2_grpc.py
   ```
   If the SDK is installed, the same is visible in `.venv/lib/python3.*/site-packages/yandex*`.

## Recording

Source tags: `[proto] <path>@<commit>`, `[doc] <page> (<date>)`, `[sdk] <file>@<version>`, `[reg] (<date>)`.

## Fixture from a fact

REST response body: camelCase fields, enums as strings; default-valued fields (enum = 0, empty lists,
empty `nextPageToken`) **omitted**; made-up IDs of the real shape (`b1g...`, `c9q...`). Parsing with
`json_format.Parse` into the SDK response class rejects unknown fields and enum names, so every fixture
is also checked against the proto schema.
