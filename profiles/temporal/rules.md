## Temporal

- Workflows, activities and workers follow the official `temporal-developer` skill, Python SDK; the
  cluster is self-hosted.
- Layout from the skill: `workflows/` (workflow classes only), `activities/`, `models/` (inputs and
  results), `worker.py`. The worker is its own entry point and process, never the API.
- Workflow code: Temporal determinism rules win over `async-python-patterns`. Time, randomness, UUIDs,
  sleep and I/O only through the `workflow` API or in activities.
- An activity that calls an external system (creates infrastructure) uses an idempotency key: activities
  are retried. Workflow and activity inputs are one dataclass or Pydantic model; new fields get defaults.
- Changing workflow code while executions may be running: use versioning (`workflow.patched`) and a
  replay test; ask the user whether running executions exist.
- Tests: `WorkflowEnvironment.start_local()` (the first run downloads the dev server), activities
  replaced by test doubles, `ActivityEnvironment` for activities; time-skipping only for timers.
- Deviation from `temporal-developer`: the Temporal CLI is used only against a local
  `temporal server start-dev`. Any command against a real cluster (`terminate`, `reset`, `cancel`,
  `signal` and others from the troubleshooting guide) is given to the user.
