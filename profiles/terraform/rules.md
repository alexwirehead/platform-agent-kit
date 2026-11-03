## Terraform and Terragrunt

- Modules and Terragrunt live repositories follow `terraform-conventions`: Terraform CLI and Terragrunt
  1.x, one repository per module, one live repository per cloud, modules only from the internal GitLab
  by tag, lower version bounds in modules, exact versions and lock files in live units, state in `s3`
  with `use_lockfile`.
- The agent works offline: `fmt`, `validate` with `init -backend=false`, `tflint`, `trivy config`,
  `terraform-docs`, `terragrunt hcl fmt` and `hcl validate`, `dev/check-terraform.sh`. Never `plan`,
  `apply`, `state`, `import`, `output` or `terragrunt run`; never asks for cloud keys.
- Real cloud, folder and project IDs in a live repository are configuration, not secrets: they may be
  committed in `*.hcl`. Keys, tokens and passwords never are.
- Deviations from third-party skills:
  - `terraform-style-guide`: modules have no `provider` block and no `~>` constraints — lower bounds
    only; security scanning is `trivy config`, not checkov or tfsec;
  - `refactor-module`: no `terraform state` commands and no `terraform test`; modules live in their own
    repositories, a `git::` source takes `?ref=` and never `version`;
  - `terrashark`: no MCP lookups of live IDs and no `terraform test`; its CI examples are general advice,
    the pipeline belongs to the project's CI rules.
