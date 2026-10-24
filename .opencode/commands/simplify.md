---
description: Clean up changed code — reuse, simplification, efficiency, fix altitude
---

Replacement for the Claude Code built-in `simplify` skill (AGENTS.md, rule 1). You look for needless
complexity, not bugs.

Scope: $ARGUMENTS. If empty — `git diff HEAD`; if that is empty, the last commit (`git show HEAD`).

Review the changes from four sides:

1. Reuse: new code repeats something that already exists in the repository or in a library. Name the
   existing function.
2. Simplification: redundant or derivable state, copy-paste with variations, deep nesting, dead
   code. Name the simpler form.
3. Efficiency: repeated computation and I/O, needless work at startup or in hot loops.
4. Altitude: the cause is fixed, not the symptom; no special cases on top of a general mechanism.

Fix what you found if the fix keeps the intended behaviour and stays close to the diff. Skip the
rest with a reason. After the fixes run the project's full verification command (AGENTS.md). At the
end list what was fixed and what was skipped; add the summary to the task notes in `TASKS.md`.
