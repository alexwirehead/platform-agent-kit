---
name: change-workflow
description: How a change is made in a project — spec in docs/specs/NNN-slug.md, task in TASKS.md, failing test, code, docs update, git branch and merge request. Use for any behaviour change (feature, metric, config option, alert, dashboard panel, chart value, deploy) and when starting or finishing a task. Триггеры — доработка, новая фича, спецификация, спека, задача, TASKS.md, ветка, мерж.
---

# Change workflow

Order is fixed: **spec → task → failing test → code → docs → merge request**. Never skip ahead.

Stop for the user twice: after the spec draft and before every commit. Each stop is a question with
the question tool (Claude Code: `AskUserQuestion`, OpenCode: `question`) that ends your turn; do not
go on until the user answers.

## 1. Spec

Any behaviour change starts with `docs/specs/NNN-slug.md` made from the template in
`docs/specs/README.md`: next free number, short English slug, status `черновик`.

- Not needed for: fixing code to match already described behaviour, refactoring without behaviour
  change, typos, documentation edits.
- Ambiguous input or several reasonable options — ask the user before writing (options with honest
  pros and cons, recommended first).
- A decision made along the way goes to the project's decision log (number, date, who decided,
  reason); the spec links to it.
- An unanswered open question keeps the spec in `черновик`.
- **Stop 1 — spec approval.** Show the user a summary of «Что меняется» and «Готово, когда» and ask:
  accept or change. Set the status to `принята ГГГГ-ММ-ДД, пользователь` only after the user's explicit
  yes to this question. Interview answers are not an approval. Before it: no task, no test, no code.
- After context compaction the spec file wins over the compaction summary: a spec in `черновик` means
  ask again, even if the summary says it was approved.

## 2. Task

After the spec is accepted, add one or more tasks to `TASKS.md` in the matching stage.

- The task has a line `Спека: docs/specs/NNN-slug.md`; the spec header lists the task in `Задачи:`.
- Statuses: `[ ]` not started, `[~]` in progress, `[x]` done, `[!]` blocked (reason in notes).
- Work discovered on the way that is not in the list becomes a new task, not silent extra work.

## 3. Test, then code

Start the task: mark it `[~]`. Write a failing test first (`test-driven-development`), then the
minimal code to make it pass. The task includes moving the change into the documents that describe
the current state (listed in the spec's «Затронутые документы»). The spec itself stays as history.

## 4. Finish

- Check every «Готово, когда» criterion with a fresh run of the commands
  (`verification-before-completion`). Only then mark `[x]` with the date and the run result in
  «Заметки», for example `2026-10-24, pytest: 42 passed`.
- Update the task mark in the spec header. All tasks closed — spec status `сделана ГГГГ-ММ-ДД`.
  After that the spec file is never edited.
- Commit after every finished task.
- **Stop 2 — commit.** Before every commit show `git diff --stat`, the commit message and the result of
  the full verification command, and ask whether to commit. Work without a spec (see section 1) has
  this stop only.

## 5. Branch and merge request

- No direct commits to `main`. Branch from a fresh `main`: `<type>/<KEY>-<slug>`, for example
  `feature/PROJ-123-node-group-presets`; `<type>` is `feature`, `fix` or `docs`. One branch — one
  feature or one fix.
- `<KEY>` is the Jira issue key: from the user's request or the current branch name. Not found — ask
  before creating the branch, never invent one. If the user says there is no issue, the branch and the
  commits go without a key.
- The branch is ready when the work is committed and the project's full verification command is clean.
- You never push, open a merge request or merge. Give the user a merge request title (like the commit
  header) and a short description: what and why, how it was checked, the spec link
  `docs/specs/NNN-slug.md`. The user pushes, opens the merge request in GitLab and merges after review.
- Code, charts, dashboards, deploy: say what the user has to check on the real environment before the
  merge. A branch waiting for the merge is recorded as `Ветка: <name>` in the task notes.
