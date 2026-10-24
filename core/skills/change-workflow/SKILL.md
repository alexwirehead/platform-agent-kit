---
name: change-workflow
description: How a change is made in a project — spec in docs/specs/NNN-slug.md, task in TASKS.md, failing test, code, docs update, git branch and merge. Use for any behaviour change (feature, metric, config option, alert, dashboard panel, chart value, deploy) and when starting, finishing or merging a task. Триггеры — доработка, новая фича, спецификация, спека, задача, TASKS.md, ветка, мерж.
---

# Change workflow

Order is fixed: **spec → task → failing test → code → docs → branch merge**. Never skip ahead.

## 1. Spec

Any behaviour change starts with `docs/specs/NNN-slug.md` made from the template in
`docs/specs/README.md`: next free number, short English slug, status `черновик`.

- Not needed for: fixing code to match already described behaviour, refactoring without behaviour
  change, typos, documentation edits.
- Ambiguous input or several reasonable options — ask the user before writing (options with honest
  pros and cons, recommended first).
- A decision made along the way goes to the project's decision log (number, date, who decided,
  reason); the spec links to it.
- An unanswered open question keeps the spec in `черновик`. Agreed with the user — `принята`.

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

## 5. Branches and merge

- No direct commits to `main`. Branch from a fresh `main`: `feature/NNN-slug` by spec number; work
  without a spec — `fix/<slug>` or `docs/<slug>`. One branch — one feature or one fix.
- The branch is ready when the project's full verification command is clean.
- Code, charts, dashboards, deploy: merge only after the user has checked the branch on the real
  environment and confirmed it. Docs, specs, rules, dev tooling: after verification and an explicit
  "merge" from the user.
- Merge: `git switch main && git merge --no-ff <branch>`; the merge message follows the commit
  message rules (Conventional Commits), its body references the spec: `Спека: docs/specs/NNN-slug.md`.
  Delete the branch after merge (`git branch -d`).
- Never merge without confirmation. A branch waiting for a check is recorded as `Ветка: <name>` in the
  task notes.
