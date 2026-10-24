---
name: grafana-dashboard
description: How to build any Grafana dashboard a platform engineer keeps in the repository as JSON — service (RED), infrastructure (USE), exporter or pipeline health, status maps, SLO. Covers the v2 JSON from a Grafana export, variables instead of copies, colour by thresholds or value mappings, $__rate_interval, data freshness and No data, PromQL ranking and joins, table pitfalls, checking on a local stand. Use when creating or changing a dashboard JSON, its panels, variables or queries. Триггеры — дашборд, Grafana, панель, плитка, переменная, PromQL, value mappings.
---

# Grafana dashboards

Panel options are named as in the Grafana docs; check every option and schema field there or in the
schema of the target version, not from memory (`source-driven-development`). Marks: **[docs]** —
Grafana docs, `grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices`
and `.../datasources/prometheus/template-variables`; **[13.2.4]** — seen on that version in practice.

## 1. File and format

- A dashboard is a JSON file in the repository (`dashboards/<name>.json`) for import
  (Dashboards → New → Import) and file provisioning. The JSON is the source of truth: no editing in
  the browser of the production Grafana; viewers change views with variables [docs].
- Ask the target Grafana version first: the format depends on it.
- Format v2 (`apiVersion: dashboard.grafana.app/v2`, `kind: Dashboard`) when its features are needed,
  for example conditional rendering (hide a panel without data); schema
  `apps/dashboard/kinds/v2/dashboard_spec.cue` at the version tag. Grafana 13.2 has the new layouts GA
  and on by default.
- The file is produced by **exporting from Grafana** (Export → v2 or classic), then edited. Query and
  variable shapes come from Grafana itself (`DataQueryKind.spec` is a free object in the schema):
  never invent them.
- `metadata` has only `name` (the uid comes from it); datasource in queries is
  `{"name": "${datasource}"}`; no real hosts, IDs or credentials in the JSON.
- File provisioning loads v2 [13.2.4]. A log line `[SHOULD NOT HAPPEN] failed to update managedFields
  ... field not declared in schema` is a Kubernetes API service record and does not affect loading.

## 2. Design

- One strategy per dashboard [docs]: **RED** (rate, errors, duration) for services — symptoms, user
  experience, the basis for alerts; **USE** (utilisation, saturation, errors) for resources — causes.
  A health dashboard of an exporter or pipeline shows whether data is fresh and complete.
- **Variables instead of copies** [docs]: one dashboard for all nodes, services or clusters, with the
  data source as a variable (`datasource`, Prometheus type) so the JSON works in any Grafana and
  cluster. Copying a dashboard to change one thing is sprawl.
- Hierarchy and drill-down [docs]: an overview dashboard links to detail dashboards; rows follow the
  service hierarchy or data flow; dashboards are linked from alerts.
- Compare like with like [docs]: split panels when magnitudes differ; normalise axes (CPU in percent
  of cores, not raw cores); colour has meaning — good and bad, not decoration.
- Clarity over beauty: prefer basic panels (Time series, Stat, Table, Bar gauge); every panel has a
  title that says what question it answers and a unit (Standard options → Unit).

## 3. Variables

- A selector variable (project, cluster, service): Query, single choice unless several values make
  sense together, sorted; default selection empty in the JSON.
- A variable used only to repeat rows or panels is hidden (`hideVariable`), multi-choice, All,
  current value All — the repeat needs it; this is the one allowed default.
- A repeat variable's query filters by the selector (`label_values(<metric>{sel="$sel"}, service)`),
  so a missing item has no panel at all instead of an empty one.

## 4. Queries

- Counters: `rate()` and `increase()` with **`$__rate_interval`**, never a fixed window or
  `$__interval` [docs]. It needs the data source's scrape interval set to the real one, otherwise the
  window is too small and `rate()` returns nothing. In recording rules use a fixed window [docs].
- Gauges are shown as is; aggregate with `sum by`/`max by` over the labels the panel needs only.
- **Name from another series**: multiply by 1 with a join,
  `<expr> * on(id) group_left(name_label) (0 * label_replace(<parent>, "name_label", "$1", "name", "(.*)") + 1)`.
- **Rank for sorting** when codes are not ordered by severity:
  `(m == 2) * 0 + 4 or (m == 4) * 0 + 3 or ...`. A value cannot become a label in PromQL: one
  `label_replace` per code.

## 5. Colour, No data, freshness

- **Magnitudes — thresholds** (latency, utilisation, age). **Categories — value mappings** (state
  codes, up/down): a code is not a magnitude, thresholds between codes lie.
- Special mappings Null and NaN → No data, no colour; a `noValue` text that says why it is empty.
- **No data is not zero and not unknown.** No series means the source is down or not scraped; it must
  look different from a measured zero or an "unknown" state.
- A dashboard fed by an exporter has a **data collection row**: success of polling
  (`min(<prefix>_exporter_collect_success)`), data age
  `time() - max(max_over_time(<prefix>_exporter_last_cycle_timestamp_seconds[1h]))` with a threshold,
  and where errors are. `max_over_time(…[1h])` keeps the age panel red after the exporter dies:
  without it the series leaves the instant query after the staleness window (about 5 minutes) and the
  panel shows No data instead of a growing age.

## 6. Tables [13.2.4]

- `noValue` in `fieldConfig.defaults` is shown both for an empty table and for **every empty cell**.
  Put the "all fine" text in defaults and an override `byType` = `string` → `noValue: ""`.
- "Group to nested tables" (`groupToNestedTable`): defaults do not apply to the nested table; give it
  its own overrides with `scope: nested` (cell type, mappings, name).
- Value mappings compare values as strings, so they work for a label column too.
- Tables of current state: Instant on, Format Table, `organize` transformation to order, hide and
  rename columns; raw API values renamed with a suffix like «(API)» to separate them from the result.

## 7. Layout in v2 [13.2.4]

- `GridLayoutItem` has no `conditionalRendering`. A panel hidden by "Has data" goes into an
  `AutoGridLayout` (`maxColumnCount: 1` for full width) inside a row; the rest into a `GridLayout`.
- A row repeated by a variable: `RowsLayoutRow` with `repeat: {mode: variable, value: <var>}`.

## 8. Status map dashboards

A tile per resource coloured by its state:

- Tiles are Stat: Instant on, Format Time series, Calculation Last *, Text mode Value and name, Color
  mode Background Solid, Graph mode None, legend is the resource name.
- One state vocabulary, for example Atlassian Statuspage: Operational (green), Degraded (yellow),
  Partial outage (orange), Major outage (red), Unknown (gray), No data.
- Unknown (gray) — the resource exists but its state is unknown (stopped, no health, the poll failed);
  No data — no series. A details table "what is wrong" lists bad resources first by rank.

## 9. Checking without the real system

1. A local stand: the data source fed by fakes (an exporter on fake clients or recorded series),
   Prometheus or VictoriaMetrics, Grafana with provisioned datasource and dashboard.
2. Open the dashboard, go through the variables.
3. Check every colour and label, the empty cases (no series, empty table, empty cell), and the error
   case of the stand (the data collection row turns red, affected panels turn gray or No data).
4. A screenshot or a short note goes into the task notes. The user confirms on the real Grafana before
   merge.
