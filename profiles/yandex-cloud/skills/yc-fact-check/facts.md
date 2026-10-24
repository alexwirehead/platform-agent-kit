# Verified general facts about the Yandex Cloud API

Each fact has its source and the date it was checked. Service-specific methods are not here: check
them with the procedure in `SKILL.md`.

Sources: **[proto]** `github.com/yandex-cloud/cloudapi@cb932fccd2dd64cebd5e45dfcdd613444447e7d5`
(2026-10-19); **[doc]** `https://yandex.cloud/ru/docs/...`; **[reg]** `GET https://api.cloud.yandex.net/endpoints`;
**[sdk]** `github.com/yandex-cloud/python-sdk` 0.411.0, commit `93781c7` (2026-10-19).

## Hosts

- Every service host is listed in the registry [reg] (public, no auth): `id` → `address`. Examples
  (2026-10-19/22): `iam` → `iam.api.cloud.yandex.net:443`, `resource-manager` →
  `resource-manager.api.cloud.yandex.net:443`, managed databases (`managed-postgresql`,
  `managed-kafka`, `managed-redis`, `managed-clickhouse`, `managed-mongodb`, `managed-opensearch`) →
  `mdb.api.cloud.yandex.net:443`, `managed-kubernetes` → `mks.api.cloud.yandex.net:443`
  (there is no `k8s.api.cloud.yandex.net`), `dataproc` → `dataproc.api.cloud.yandex.net:443`,
  `ydb` → `ydb.api.cloud.yandex.net:443`.
- The registry itself is `api.cloud.yandex.net:443`; the SDK uses it for discovery [sdk] `_auth_fabric.py`,
  `_channels.py`.

## REST and proto3 JSON

- REST fields are camelCase (`folderId`, `nextPageToken`), proto fields snake_case; enums in JSON are
  value-name strings (`"health": "DEGRADED"`) [doc] api-ref pages, `api-design-guide/concepts/pagination`.
- Default-valued fields are **absent** from responses: "If the field has default value, it is not
  returned in the response" [doc] `managed-postgresql/api-ref/Cluster/listHosts`; proto3 JSON rule
  (`https://protobuf.dev/programming-guides/json/`). So enum = 0 (`*_UNKNOWN`, `*_UNSPECIFIED`) means no
  key, an empty list means no key (the response may be `{}`), the last page has no `nextPageToken`.
  An absent enum is "unknown", not "healthy".
- Pagination: request `pageSize` (0–1000, default 100) and `pageToken`, response `nextPageToken`;
  repeat until `nextPageToken` is absent [doc] `api-design-guide/concepts/pagination`.

## Errors

[doc] `api-design-guide/concepts/errors`: a REST error body carries the gRPC code, not the HTTP one:
`{"code": 16, "message": "...", "details": [{"@type": "type.googleapis.com/google.rpc.RequestInfo", "requestId": "..."}]}`.

| gRPC | Status | HTTP | Retry? |
|---|---|---|---|
| 3 | INVALID_ARGUMENT | 400 | no |
| 4 | DEADLINE_EXCEEDED | 504 | yes, later |
| 5 | NOT_FOUND | 404 | no |
| 7 | PERMISSION_DENIED | 403 | no — missing role |
| 8 | RESOURCE_EXHAUSTED | 429 | yes, later — rate limit |
| 13 | INTERNAL | 500 | yes, later |
| 14 | UNAVAILABLE | 503 | yes, "retry in a few seconds" |
| 16 | UNAUTHENTICATED | 401 | token; the SDK refreshes it itself |

Observation (production, 2026-10-20): a REST 403 came with `"code": 403` in the body, not 7. For manual
`curl` checks look at the HTTP status.

## Python SDK `yandexcloud` [sdk]

- Clients: `sdk = yandexcloud.SDK(service_account_key=<dict>)`, then `sdk.client(<Stub>)`; the service
  is resolved from the stub's module (`_sdk.py`, `_supported_modules`). Request and response classes are
  in the sibling `*_pb2` modules; Python fields are snake_case as in proto.
- Discovery: the first channel always calls `ApiEndpointService.List` on `api.cloud.yandex.net:443`;
  `endpoints=` overrides are applied after it (`_channels.py`). Channels are always TLS.
- Auth: `ServiceAccountAuth` builds a JWT `alg=PS256`, `kid`, `iss`,
  `aud=https://iam.api.cloud.yandex.net/iam/v1/tokens`, `exp = iat + 3600`; a token is considered fresh
  for 20 s (`_auth_plugin.py`, `TIMEOUT_SECONDS = 20`), then `IamTokenService.Create` is called again.
  The key must have `id`, `service_account_id`, `private_key` starting with
  `-----BEGIN PRIVATE KEY-----` (`_auth_fabric.py`).
- Retries: `yandexcloud.RetryPolicy(max_attempts=4, status_codes=(grpc.StatusCode.UNAVAILABLE,))` by
  default, passed to gRPC as service config (`_retry_policy.py`).
- **Do not pass `RetryPolicy` without a reason.** Discovery calls `ApiEndpointService.List` without a
  timeout, and the policy's `"waitForReady": True` reaches the discovery channel too. Checked locally
  (2026-10-19, a TCP server that accepts and stays silent): without `retry_policy` the first
  `sdk.client()` raises `UNAVAILABLE` after 20.0 s; with `RetryPolicy` it did not return within 45 s.
  Calls with `timeout=` are bounded by their deadline.
- No general pagination helper: loop over `next_page_token` yourself.
- In a protobuf object an absent field is 0 / empty string / empty list. Enum name: `Enum.Name(v)`; a
  number unknown to the SDK version raises `ValueError` — handle it explicitly.

## IAM token by a service account key

[doc] `iam/operations/iam-token/create-for-sa`: JWT header `typ=JWT`, `alg=PS256` (only PS256),
`kid` = key ID; payload `iss` = service account ID, `aud=https://iam.api.cloud.yandex.net/iam/v1/tokens`,
`exp - iat ≤ 3600`; exchange `POST https://iam.api.cloud.yandex.net/iam/v1/tokens` with
`{"jwt": "<JWT>"}`, response `iamToken`, `expiresAt`; use `Authorization: Bearer <token>`.
[doc] `iam/concepts/authorization/iam-token`: a token lives at most 12 hours, request a new one in
advance, the old one stays valid, IAM may return the same token while it is fresh.
`CreateForServiceAccount` is a different flow (on behalf of an authenticated subject).

## Roles

[doc] `<service>/security/`, `iam/roles-reference` (2026-10-19/23):

- Roles on an organisation, cloud or folder apply to nested resources.
- `auditor` (primitive): read configuration and metadata of any resource without access to data —
  the safest read-only role. `viewer` also reads service data: too broad for monitoring.
- `resource-manager.auditor`: view clouds and folders. Get/List of a cloud or folder need `viewer`,
  `resource-manager.viewer` or `resource-manager.auditor` on the folder or cloud; a role on a folder gives
  Get of that folder but not Get/List of the cloud.
- `resource-manager.clouds.member`: "view cloud info and contact support", cloud only. Observation
  (production, 2026-10-20): Cloud.Get with only this role returned `PERMISSION_DENIED`.
- `mdb.auditor`: view managed database clusters without data and logs; includes the
  `managed-*.auditor` roles. Whether a `managed-*.auditor` role covers hosts differs per service: check
  its `security/` page.
- Managed Kubernetes has no `k8s.auditor`; `k8s.viewer` gives clusters and only "basic information" on
  node groups. `k8s.clusters.agent` is not read-only (creates node groups, disks, load balancers).
- Observation (production, 2026-10-23): `auditor` on a folder is enough to list managed databases with
  hosts and Kubernetes clusters with node groups and nodes in that folder.
- Grant a role to a service account on a cloud [doc] `iam/operations/sa/assign-role-for-sa`:
  `yc resource-manager cloud add-access-binding <cloud> --role <role> --service-account-id <sa-id>`.
