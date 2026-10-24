---
name: grafana-dashboard
description: How to build a Grafana status dashboard stored as JSON in the repository — v2 format from a Grafana export, Stat and Table panels only, colours by value mappings, Unknown versus No data, a data-collection row, PromQL ranking and joins, table pitfalls (noValue, nested tables), checking on a local stand. Use when creating or changing a dashboard JSON, its panels, variables or queries. Триггеры — дашборд, Grafana, панель, плитка, value mappings, переменная, PromQL.
---

# Grafana status dashboard

Panel options are named as in the Grafana docs (`grafana.com/docs/grafana/latest/panels-visualizations/`);
check every option and schema field there or in the schema of the target version, not from memory
(`source-driven-development`). Pitfalls below are marked with the version they were seen on.

## File and format

- The dashboard is a JSON file in the repository (`dashboards/<name>.json`) for import
  (Dashboards → New → Import) and file provisioning.
- Ask the target Grafana version first: the format depends on it.
- Format v2 (`apiVersion: dashboard.grafana.app/v2`, `kind: Dashboard`) when conditional rendering is
  needed (hide a panel without data); schema `apps/dashboard/kinds/v2/dashboard_spec.cue` at the
  version tag. Grafana 13.2 has the new layouts GA and on by default.
- The file is produced by **exporting from Grafana** (Export → v2), then the layout is edited. The
  shape of queries and variables comes from Grafana itself (`DataQueryKind.spec` is a free object in
  the schema): never invent it.
- `metadata` has only `name` (the uid comes from it); default selections are empty; datasource in
  queries is `{"name": "${datasource}"}`.
- File provisioning loads v2 (13.2.4). A log line `[SHOULD NOT HAPPEN] failed to update managedFields
  ... field not declared in schema` is a Kubernetes API service record and does not affect loading.

## Panels and variables

- Only basic panels: Stat for tiles, Table for details. Variables of type Data source and Query.
  Clarity of colour matters, beauty does not.
- `datasource` variable (Prometheus type) so the JSON imports into any Grafana.
- A selector variable: Query, single choice, no All, sorted. Variables used only to repeat panels or
  rows are hidden (`hideVariable`), multi-choice, All, current value All.
- Tiles: Instant on, Format Time series, Calculation Last *, Text mode Value and name, Color mode
  Background Solid, Graph mode None, the legend is the resource name.

## Colour and states

- **Colour comes from value mappings, not thresholds**: a state code is a category, not a magnitude.
- One label vocabulary for states, for example Atlassian Statuspage: Operational (green), Degraded
  (yellow), Partial outage (orange), Major outage (red), Unknown (gray). Special mappings Null and NaN →
  No data, no colour. `noValue` text for an empty answer.
- **Unknown is not No data.** Unknown (gray): the resource exists but its state is unknown (stopped,
  no health, the poll failed). No data: there are no series at all — the exporter is down or not
  scraped. They must look different.
- A **data-collection row** separates "the service is down" from "the exporter cannot ask the API":
  - poll status: `min(<prefix>_exporter_collect_success{...})`, mappings 1 → Operational, 0 → Errors;
  - data age: `time() - max(max_over_time(<prefix>_exporter_last_cycle_timestamp_seconds[1h]))`, unit
    seconds, red above the threshold. `max_over_time(…[1h])` keeps the panel red after the exporter
    dies: without it the series leaves the instant query after the staleness window (about 5 minutes)
    and the panel shows No data instead of a growing age;
  - where errors are: `<prefix>_exporter_collect_success{...} == 0` as a table.

## PromQL patterns

- **Rank for sorting** when state codes are not ordered by severity: map each code to a rank,
  `(m == 2) * 0 + 4 or (m == 4) * 0 + 3 or ...`.
- **Name from a parent series**: multiply by 1 with a join,
  `<expr> * on(cluster_id) group_left(cluster_name) (0 * label_replace(<parent>, "cluster_name", "$1", "name", "(.*)") + 1)`.
  A value cannot become a label in PromQL: use one `label_replace` per code to put a rank into a label.
- Repeating panels by a hidden variable: the variable's query filters by the selector
  (`label_values(<metric>{selector="$sel"}, service)`), so a missing item has no panel at all.

## Table pitfalls (seen on 13.2.4)

- `noValue` in `fieldConfig.defaults` is shown both for an empty table and for **every empty cell**.
  Put the "all fine" text in defaults and an override `byType` = `string` → `noValue: ""`: empty cells
  stay empty, an empty table says all fine.
- "Group to nested tables" (`groupToNestedTable`): defaults do not apply to the nested table; give it
  its own overrides with `scope: nested` (cell type, mappings, name).
- Value mappings compare values as strings, so they work for a label column too.
- In v2 `GridLayoutItem` has no `conditionalRendering`; a panel hidden by "Has data" goes into an
  `AutoGridLayout` (`maxColumnCount: 1` for full width), the rest into a `GridLayout`.

## Checking without the real system

1. A local stand: the exporter on fake clients, Prometheus or VictoriaMetrics, Grafana with
   provisioned datasource and dashboard.
2. Open the dashboard, pick the selector value.
3. Check every state's colour and label; panels exist only where there is data; the details table
   shows the bad resources first and empty cells empty; in the flip scenario tiles turn gray and the
   poll status turns red after an error.
4. A screenshot or a short note goes into the task notes. The user confirms on the real Grafana before
   merge.
