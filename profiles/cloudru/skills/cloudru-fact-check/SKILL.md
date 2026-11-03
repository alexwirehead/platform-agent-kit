---
name: cloudru-fact-check
description: Verify a fact about Cloud.ru Advanced (Terraform provider sbercloud resources and arguments, provider environment variables, regions, OBS state backend, API behaviour) at the primary source — provider docs at the pinned tag, Cloud.ru Advanced documentation — and record it with the source; start from the verified facts in facts.md. Use whenever a project needs a Cloud.ru Advanced fact. Триггеры — Cloud.ru, клауд ру, SberCloud, сберклауд, Advanced, sbercloud провайдер, OBS, ru-moscow-1.
---

# Checking a fact about Cloud.ru Advanced

The procedure and recording rules are those of `api-fact-check`; this skill adds the Cloud.ru Advanced
sources. General facts already verified are in `facts.md` next to this file — read it first, copy a
fact you use into the project facts document with its source, re-check it at the source if the date is old.

The platform is Cloud.ru Advanced; its provider and docs still use the SberCloud name. Cloud.ru
Evolution is a different platform: facts of one never apply to the other.

## Sources, most reliable first

1. Terraform provider `sbercloud-terraform/sbercloud`: the docs and code of the version the project pins,
   from its repository at that tag; versions on the mirror —
   `curl -s https://terraform-mirror.yandexcloud.net/registry.terraform.io/sbercloud-terraform/sbercloud/index.json`.
   ```bash
   S=<scratchpad>/terraform-provider-sbercloud
   [ -d "$S" ] || git clone --depth 1 --branch v<version> https://github.com/sbercloud-terraform/terraform-provider-sbercloud.git "$S"
   less "$S"/docs/resources/<resource>.md     # data sources: docs/data-sources/, guides: docs/guides/
   ```
   Argument names, defaults, import ID and which attributes force replacement are in the resource page;
   when the page is silent, the resource schema in the provider code at the same tag decides.
2. Cloud.ru Advanced documentation and API reference (public pages): service behaviour, quotas,
   regions, OBS. Pages are large: download with `curl` into the scratchpad, convert to text, search in it.

## Recording

Source tags as in `api-fact-check`: `[doc]` — page and date, `[code]` — terraform-provider-sbercloud
`<file>@<tag>`, `[mirror]` — mirror index and date.
