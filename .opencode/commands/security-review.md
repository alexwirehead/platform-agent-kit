---
description: Security review of changes (end of a stage with secrets, images, manifests)
---

Replacement for the Claude Code built-in `security-review` skill (AGENTS.md, rule 4).

Scope: $ARGUMENTS. If empty — changes of the current stage, as in `/code-review`.

Check:

- keys and tokens never reach logs, `repr`, exception messages or their chains;
- the repository has no real IDs, keys, local configs or credential files;
- input is parsed safely (for example YAML only with a safe loader) and validated before use;
- images: non-root user, pinned versions, no secrets in layers, `.dockerignore`;
- manifests and charts: secrets are not stored in plain values, `readOnlyRootFilesystem`,
  `runAsNonRoot`, minimal egress;
- new dependencies and their pinned versions in the lock file;
- the project-specific items under "Review checks" in AGENTS.md.

Report only confirmed issues: file, line, attack or leak scenario. Change nothing unless the user
asks. Put the summary into the notes of the stage's last task.
