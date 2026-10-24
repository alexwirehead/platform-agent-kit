---
name: python-exporter
description: How to build a Prometheus exporter in Python that polls an external API — background collection cycle with a snapshot, error handling with last known state, custom collector metrics, logfmt logging, tests on fixtures and fake clients, a local stand without the external system. Use when writing or changing exporter code, its metrics, logs or tests. Триггеры — экспортер, метрики, Prometheus, /metrics, цикл сбора, logfmt, стенд, fake-клиенты.
---

# Python exporter

Rules proven on a production exporter. Library APIs (`prometheus_client`, SDKs, `grpc`) come from
their docs (`source-driven-development`), facts about the polled system from the project's facts
document. A project deviates only by recording it in its `AGENTS.md`.

## Stack

- Python 3.13+, uv, `uv.lock` committed. Runtime dependencies are minimal: the API client,
  `prometheus-client`, a config parser. Each new runtime dependency is a recorded decision.
- Dev: `pytest`, `ruff`. Code takes its environment (config path, key path, port) as parameters;
  only the entry point reads environment variables.
- ruff: `line-length = 79`, `max-doc-length = 72`, rules `E W F I N D B C4 UP SIM`,
  `pydocstyle.convention = "google"`, `"tests/**" = ["D"]`, `include = ["*.py"]` (never reformat
  markdown). Style details — `python-code-style`.

## Collection cycle

- A background cycle every `interval_seconds` builds a new snapshot and swaps it in atomically;
  `/metrics` always serves the last snapshot. A scrape never calls the API.
- Calls are **sequential**: no threads, no asyncio, until a real environment shows the cycle does
  not fit into the interval. A cycle longer than the interval: the next one starts right after,
  with a warning in the log.
- Every list call is read to the end (follow the page token until it is empty).
- Every call gets an explicit timeout from config.
- An enum value unknown to the client library maps to `UNKNOWN_<number>` and the unknown state;
  a warning is logged once per value per process.

## Errors

- No retries inside a cycle: the retry is the next cycle. Do not enable SDK retry policies without
  checking they cannot hang (timeouts on discovery, auth).
- The unit of success is a pair (scope, service), for example (folder, service). Any error in a pair
  sets `<prefix>_exporter_collect_success{...} = 0` for it, collection moves on to the next pair.
- **Last known state.** Resources of a pair that failed this cycle are copied from the previous
  snapshot with the unknown state and their old labels: a tile turns gray instead of disappearing.
  Failed since process start — no resources, visible through `collect_success = 0`.
- Timeout cascade: after `UNAVAILABLE` or `DEADLINE_EXCEEDED` a service is not polled for the rest of
  the cycle (its resources are carried over as unknown). Fast errors (`PERMISSION_DENIED`) are not
  treated so: the next scope may answer.
- Only API errors are caught. Anything else crashes the process with a traceback; Kubernetes
  restarts the Pod. Handling is added when such errors are actually seen.

## Metrics

- One prefix per exporter. A **custom collector** yields metrics from the current snapshot on every
  scrape: a vanished resource vanishes from `/metrics`, no stale series pile up. No gauges with manual
  clearing.
- State as a numeric gauge with a fixed code table (for example 0 ok … 3 unknown); raw API status
  values go into labels only if the set is small and fixed.
- Labels: IDs and names of resources, never unbounded values (error texts, timestamps, request IDs).
  A child resource carries its parent ID label so one filter finds the parent with its children.
- Self metrics: `<prefix>_exporter_collect_success` (per pair), `<prefix>_exporter_cycle_duration_seconds`,
  `<prefix>_exporter_last_cycle_timestamp_seconds`. Default process and Python metrics stay on.
- Units in names (`_seconds`, `_bytes`), counters end in `_total`.

## HTTP and process

- Only `GET /metrics`; it is also the liveness probe. Before the first cycle it answers 200 with
  process metrics only.
- Startup error (config, key, busy port): one log line, exit code 1.
- SIGTERM and Ctrl+C stop the exporter after the current cycle.
- One replica per instance: replicas do not share work and produce duplicate series. Scale by a
  separate release per scope (cloud, account). Alert on `up == 0` and on
  `time() - <prefix>_exporter_last_cycle_timestamp_seconds` growing.

## Logging

- stdout, one record per line, logfmt, standard `logging` with an own formatter (~40 lines), level
  INFO, not configurable, no DEBUG.
- Key order: `ts` (UTC ISO 8601 with milliseconds and `Z`), `level`, `logger`, `msg`, then event
  fields in the order given. `msg` is a short constant event name without variable parts; everything
  variable goes into fields passed via `extra=`, never formatted into the message.
- A value with space, `=`, `"` or `\` is quoted with `"` and `\` escaped; newline becomes `\n`, other
  non-printable characters are escaped: a record is always one line. Empty value — `key=""`.
- Records of foreign loggers (SDK, grpc, `prometheus_client`) go through the same formatter.
  An uncaught exception's traceback goes into an `exc` field on the same line.
- Keys and tokens never reach logs: fields are IDs, codes and API error texts only.
- Typical events: `listening`, `cycle done` (`duration_s`, `calls`, `resources`, `failed_pairs`),
  `cycle longer than interval`, `call failed` (method, IDs, `code`, `details`), `startup failed`.

## Tests

- No network and no server in tests: API clients are replaced through a factory
  (`Fake(scenario).client(stub_cls)`). A scenario maps `(client, method, id[, page_token])` to a
  fixture, a response object or an error code; unknown keys in a scenario raise; missing key — empty
  response. Calls are recorded for assertions.
- Fixtures: one response per file, `tests/fixtures/<service>/<method>_<case>.json`, in the wire JSON
  form; fields with default values are omitted, as in a real response; IDs are made up. Fixtures are
  parsed strictly (unknown fields fail), so a typo fails a test instead of yielding an empty list.
- State rules are table-driven tests, one row per rule. The metrics test checks
  `generate_latest()` output and that a vanished resource disappears.
- Log assertions check record fields (`record.code`), not text.
- Mandatory cases: empty response, missing optional field, unknown enum value, two pages,
  permission error on a list and on a child list, auth failure on the first call.

## Local stand

`dev/run_fake.py --scenario <name> --port 8080` runs the whole exporter (cycle, snapshot, `/metrics`)
on fake clients, without keys or network. Two scenarios are enough: one with every state code and one
that flips an error on and off over time. It reuses `tests/fakes.py`. The stand does not check real
calls, auth or permissions: that is acceptance by a person with access.

## Image

Dockerfile rules — `docker-patterns`; building with uv — uv docs (`astral-sh/uv-docker-example`) via
`ctx7`. Non-root user, pinned base image, no secrets in layers.
