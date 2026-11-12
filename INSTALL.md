# Installing platform-agent-kit with an agent

Instructions for an agent asked to install or update the kit in a project ("install the kit from
<link>", "update the kit") or in every project under a folder. Spec: `docs/specs/005-agent-install.md`.

Ask the user with the question tool (Claude Code: `AskUserQuestion`, OpenCode: `question`): show what
you found and the list you propose, recommended option first. Never invent kit rules for something the
kit has no profile for. Never commit.

## 1. Find the kit

- If a clone exists at `~/projects/platform-agent-kit`, run `git pull` in it and use it.
- Otherwise propose `~/projects/platform-agent-kit` and ask the user where to clone. Clone over HTTPS:
  `git clone https://github.com/alexwirehead/platform-agent-kit.git <path>` — the repository is public,
  no SSH key is needed.
- The installer needs `bash`, `git` and `npx`. If `npx` is missing, tell the user and stop: never
  install the kit around `install.sh`.

## 2. What is installed already

If the project has `.agent-kit.lock`, this is an update: every profile from its `profiles=` line stays
in the list. `install.sh` removes profiles missing from the list, so drop a profile only when the user
asks for it.

## 3. Signals

Look through the project with your own tools. Each profile and its signals:

| Profile | Signals |
|---|---|
| `terraform` | `*.tf`, `terragrunt.hcl`, `root.hcl` |
| `yandex-cloud` | provider `yandex-cloud/yandex`, SDK `yandexcloud`, `*.yandexcloud.net` addresses |
| `cloudru` | provider `sbercloud-terraform/sbercloud` |
| `helm` | `Chart.yaml` |
| `python-exporter` | a Python project depending on `prometheus-client` |
| `external-api` | code calls an external API the agent has no access to; added automatically by `yandex-cloud` and `cloudru` |
| `grafana` | Grafana dashboard JSON files in the repository |
| `fluxcd` | `FluxInstance`, `ResourceSet`, `kustomize.toolkit.fluxcd.io` resources, `clusters/*/flux-system/` |
| `fluxcd-debug` | no file signal: when installing `fluxcd`, ask whether live cluster debugging through the read-only Flux MCP server is wanted; default no |
| `gitlab-ci` | `.gitlab-ci.yml`, `.gitlab/ci/`, `templates/*.yml` with `spec:inputs` |

`install.sh --help` in the kit lists every profile with a one-line description.

Ask the user when:
- a signal is weak (`external-api`; Python without an exporter);
- signals contradict each other;
- a Terraform project shows no cloud;
- the user named a profile whose signals are absent.

If the project has signals of something the kit has no profile for (FluxCD, Ansible, …), say so and
install only the core and the matching profiles.

## 4. Install

```bash
<kit>/install.sh <project> <profile>...
```

## 5. After install

- **`Project` section of `AGENTS.md`:** fill in what the project shows — the full verification command,
  the profile lines from `project.md`. Ask for the rest; never guess a placeholder.
- **Existing agent rules:** if `AGENTS.md` outside the kit block or `CLAUDE.md` already has agent rules,
  find duplicates of and conflicts with the kit rules. Propose what to remove and what to keep as a
  project deviation with its reason. Do not delete anything yourself.
- **`CLAUDE.md`:** if it existed before and has no `@AGENTS.md` line, Claude Code does not see the kit
  rules — propose adding the import.
- **Summary:** `git status`, the profiles installed with the reason for each, what is left for the user.
  The user commits.

## Many projects at once

"Look through every folder in `<root>` and install the kit": one git repository is one project, and
projects may need different profiles.

1. **Find repositories:** search `<root>` recursively for directories with `.git`; do not descend into a
   repository once found (submodules and nested clones are not projects). Skip the kit's own clone.
2. **Survey without changes:** for each repository do steps 2–3. Skip a repository with uncommitted
   changes (`git status --porcelain` not empty) — kit changes would mix with the user's work — unless
   the user includes it explicitly.
3. **One plan:** before installing, show one table: repository, profiles, reason, open question or
   "skipped" with the reason. Ask the profile questions in one batch and merge identical ones ("7
   Terraform repositories show no cloud — which one?"). Install after the user approves the plan.
4. **Install** repository by repository with the one kit clone. If one fails, go on with the next and
   record the error.
5. **After install:** fill `Project` with what each repository shows. Do not ask per repository about
   remaining placeholders or old agent rules — list them in the summary. The summary is a table:
   repository, profiles, changed files, what is left. Never commit.

## Update

"Update the kit": steps 1, 2 and 4 with the profiles from `.agent-kit.lock`. If the kit has new
profiles whose signals are in the project, propose them; add them only after the user agrees. For many
projects, the same over every repository with `.agent-kit.lock`, with one plan.
