# Verified general facts about Cloud.ru Advanced

Each fact has its source and the date it was checked. Resource-specific arguments are not here: check
them with the procedure in `SKILL.md`.

Sources: **[code]** `github.com/sbercloud-terraform/terraform-provider-sbercloud@v1.13.2`, commit
`d4947210ce10b36d85fbea585f76b41af0bea7ff` (2026-11-03); **[mirror]**
`GET https://terraform-mirror.yandexcloud.net/registry.terraform.io/sbercloud-terraform/sbercloud/index.json`
(2026-11-03).

## Terraform provider

- Registry address `sbercloud-terraform/sbercloud`, provider name in configuration `sbercloud`
  (`provider "sbercloud"`, resources `sbercloud_*`) [code] `docs/index.md`.
- The Yandex Cloud provider mirror serves it; versions up to 1.13.2 on 2026-11-03 [mirror]. Mirror
  settings and `providers lock -net-mirror` — `yandex-cloud` profile facts.
- Credentials, in order: static `access_key`/`secret_key` in the provider block (the docs warn against
  it) or environment `SBC_ACCESS_KEY`, `SBC_SECRET_KEY`; temporary credentials — `security_token` or
  `SBC_SECURITY_TOKEN` [code] `docs/index.md`.
- `region` is required (`SBC_REGION_NAME`), example `ru-moscow-1`; `project_name` (`SBC_PROJECT_NAME`),
  `account_name` (`SBC_ACCOUNT_NAME`, required for IAM resources), `enterprise_project_id`
  (`SBC_ENTERPRISE_PROJECT_ID`) [code] `docs/index.md`.
- API limit 100 requests per second; `rate_limit` (`SBC_RATE_LIMIT`, default 0 — unlimited) throttles the
  provider, the docs recommend 80–90; `max_retries` default 5 with exponential delay [code] `docs/index.md`.

## State backend in OBS

- OBS is S3-compatible; state is kept with backend `s3` [code] `docs/guides/remote-state-backend.md`:
  `region = "ru-moscow-1"`, endpoint `https://obs.ru-moscow-1.hc.sbercloud.ru`,
  `skip_region_validation`, `skip_credentials_validation`, `skip_metadata_api_check` — all `true`,
  "mandatory for SberCloud". Credentials — `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`. The bucket is
  created beforehand.
- The guide uses the old `endpoint` argument; current Terraform names it `endpoints = { s3 = "..." }`
  (`terraform` profile, backend docs). Further `skip_*` flags of current Terraform
  (`skip_requesting_account_id`, `skip_s3_checksum`) are not in the guide: take them from a working
  project configuration and record them here with the date.
- `use_lockfile = true` works in OBS — confirmed in production by the user (2026-11-03).
