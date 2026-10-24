---
description: Review changes for correctness bugs (end of a stage)
---

Replacement for the Claude Code built-in `code-review` skill (AGENTS.md, skills table).

Scope: $ARGUMENTS. If empty — changes of the current stage: find the first commit of the stage in
`git log` by the task numbers from `TASKS.md` and review `git diff <commit>^..HEAD`.

Look for bugs, not style:

- behaviour differs from the spec (`docs/specs/`, the task's `Спека:` line) or from the documents
  describing the current state;
- facts about external systems or library APIs that have no source (AGENTS.md, rule 2);
- unhandled errors, exceptions of the wrong type, resource leaks;
- tests that pass on broken code; branches from «Готово, когда» that no test covers;
- the project-specific items under "Review checks" in AGENTS.md.

Verify each finding against the code before reporting: file, line, scenario "input → wrong result",
severity. Change nothing unless the user asks. Put the summary into the notes of the stage's last
task.
