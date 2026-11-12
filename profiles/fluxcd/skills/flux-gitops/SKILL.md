---
name: flux-gitops
description: Team conventions for GitOps on Flux Operator — FluxInstance and bootstrap, fleet and components repositories (hybrid of ControlPlane D1/D2), one GitRepository per component, environment versions in versions.yaml, protected component tags and promotion, overlay rules, cluster folders, tenants as ResourceSet, a service as one ResourceSetInputProvider file, file naming, offline checks. Use when writing or reviewing a fleet or components repository, a FluxInstance, ResourceSet, service order, versions.yaml, overlay or component release. Триггеры — flux, флакс, fluxcd, gitops, гитопс, FluxInstance, ResourceSet, kustomization, оверлей, fleet, компонент, versions.yaml, заказ сервиса, продвижение версии.
---

# Flux GitOps conventions

Flux and Flux Operator fields come from the field index of `gitops-knowledge` and the official docs
(https://fluxcd.io/flux/, https://fluxoperator.dev/docs/), never from memory.

## 1. Engine

- **Flux Operator** in every cluster, pull model: a cluster needs read access to Git only.
- **`FluxInstance` named `flux` in `flux-system` with `cluster.multitenant: true`** from day one:
  components are applied as the ServiceAccount of their namespace, cross-namespace references are
  forbidden.
- **Flux manages itself from Git:** the `FluxInstance` lives in the fleet repository; a Flux version
  change is a merge request.
- **Bootstrap is Terraform:** the operator Helm chart, Git access secrets (read-only deploy token per
  repository), the initial `FluxInstance`. After that `FluxInstance` owns Flux, not Terraform.

## 2. Repositories

Two repositories, named here `<fleet>` and `<components>`:

| Repository | Contains | Who writes |
|---|---|---|
| `<fleet>` | `environments/`, `clusters/`, `tenants/`, service orders | platform team; automation writes orders only |
| `<components>` | component manifests | platform team |

Write access to `<fleet>` or to `<components>/infra/` equals `cluster-admin`: infrastructure is applied
as `cluster-admin`, services with namespace-admin rights. Orders sit in `<fleet>` so automation that
writes them cannot touch component manifests.

```
<fleet>/
├── environments/
│   ├── <platform>-dev/versions.yaml   # platform dev environment: *_REF = refs/heads/main
│   ├── dev/versions.yaml              # user projects: tags only
│   └── prod/versions.yaml             # user projects: tags only
├── clusters/<project>/<env>/<cluster>/
│   ├── kustomization.yaml             # explicit list + ../../../../environments/<versions>
│   ├── flux-system/                   # FluxInstance, sync.path = this folder
│   ├── runtime-info.yaml              # ENVIRONMENT, CLUSTER_NAME, CLUSTER_DOMAIN — no secrets
│   └── <orders>/                      # data-services/, apps/: one file per service
└── tenants/
    ├── policies/                      # admission policies, source allowlist
    ├── infra/                         # ResourceSet: infrastructure components
    └── <orders>/                      # ResourceSet: the template for one kind of service

<components>/
├── infra/<component>/{controllers,configs}/{base,dev,prod}
└── <group>/<component>/{base,dev,prod}
```

## 3. Sources and versions

- **One `GitRepository` per component**; for a service, one per instance in its namespace (lockdown
  forbids a source from another namespace). `spec.ignore` keeps only the component folder in the
  artifact. `spec.ref.name` is `refs/heads/main` or `refs/tags/<component>/vX.Y.Z`.
- **Versions per environment:** `environments/<env>/versions.yaml` is a ConfigMap with
  `<COMPONENT>_REF` keys, connected to every cluster of the environment through
  `postBuild.substituteFrom`. Templates reference `${<COMPONENT>_REF}` **without a default**: with
  `StrictPostBuildSubstitutions` (on by default in kustomize-controller) a missing variable stops the
  reconciliation instead of sending the environment to `main`.
- **Only the platform dev environment follows `main`.** Clusters of the platform project take versions
  from `environments/<platform>-<env>`, all other projects from the shared `environments/<env>`, and
  there every `*_REF` is a tag.
- **Component tags `*/v*` are protected:** only the platform team creates them, nobody moves them. A
  moved tag would reach prod without review.
- **Release flow:**

  ```
  MR in <components> → merge to main → platform dev applies
  → check in platform dev → tag <component>/vX.Y.Z
  → MR in <fleet>: environments/dev/versions.yaml → user dev applies
  → check on user dev clusters → MR: environments/prod/versions.yaml → prod applies
  ```

  A change in the `prod` overlay reaches prod only with a new tag — say so when proposing it.
- All clusters sync `main` of `<fleet>`: tags set component versions, not the cluster composition.

## 4. Overlays and clusters

- **One `base`, differences only in overlays:** sizes, replicas, endpoints, secret references. No
  structural differences between environments.
- **A cluster is a folder** `clusters/<project>/<env>/<cluster>/`. Its environment is written in three
  places — the folder, `ENVIRONMENT` in `runtime-info.yaml` and the `versions.yaml` path in
  `kustomization.yaml` — and they must match. The folder name equals `CLUSTER_NAME` and is unique in the
  project. A new cluster is a copy of a folder with new values; check the versions path when copying from
  the platform project.
- **Ordering:** `tenants/policies` before the other tenants (`dependsOn`), otherwise tenant resources
  are created before the policies apply.
- **Lockdown and shared data:** a `ResourceSet` copies the Git access Secret and `runtime-info` into a
  tenant namespace with the `fluxcd.controlplane.io/copyFrom` annotation, and labels the namespace
  `toolkit.fluxcd.io/role: tenant` for the source allowlist. Copy only the token of the repository the
  tenant reads: workloads of the tenant can read the copy.

## 5. A service is one file

- An order is a `ResourceSetInputProvider` of `type: Static` in
  `clusters/<project>/<env>/<cluster>/<orders>/<service>.yaml`, in the namespace of the `ResourceSet`,
  with the label of its template. No shared files that parallel merge requests would edit.

  ```yaml
  apiVersion: fluxcd.controlplane.io/v1
  kind: ResourceSetInputProvider
  metadata:
    name: analytics
    namespace: flux-system
    labels:
      <domain>/kind: data-service
  spec:
    type: Static
    defaultValues:
      name: analytics          # instance name = namespace
      component: trino         # folder in <components>
      ref: "${TRINO_REF}"      # environment version
      values: {}               # service parameters
  ```

- **One template per kind of service:** a `ResourceSet` in `tenants/<orders>/` collects orders with
  `inputsFrom` and a label `selector`, and generates the namespace, ServiceAccount and RoleBinding, the
  source, the Kustomization, the parameters ConfigMap, `Provider` and `Alert`.
- **Parameters through `valuesFrom`:** the ConfigMap has `reconcile.fluxcd.io/watch: Enabled`; the
  `HelmRelease` `values` win over `valuesFrom`, so neither base nor overlays set keys an order may set.
- **No accidental deletion:** `fluxcd.controlplane.io/prune: disabled` on the namespace and
  Kustomization of a service. A removed file leaves the service and its data in the cluster.
- **Readiness comes from Flux:** the template's `Alert` reports a successful or failed reconciliation,
  not the merge.
- An order folder holds only orders: it is applied as `cluster-admin`.
- `${…}` inside order parameters is substituted too; escape a literal `$` as `$$`.

## 6. Files

- Only `.yaml`; names lowercase with hyphens; component values `values.yaml` in `base` and each
  overlay; secrets `secrets.sops.yaml`.
- No unencrypted `Secret` in Git. How secrets are delivered (External Secrets, SOPS) is the project's
  decision.

## 7. Checks

`dev/check-flux.sh` runs everything offline; set `PLATFORM_PROJECT`, `ORDER_LABEL` and `ORDERS` at its
top once.

- `dev/flux/check-conventions.sh` — `.yaml`, names, `Secret` only with SOPS metadata.
- `dev/flux/check-refs.sh` — every version reference is exactly `${<NAME>_REF}`; `versions.yaml` keys
  are `<NAME>_REF`, values `refs/heads/…` or `refs/tags/…`.
- `dev/flux/validate-overlays.sh` — `kustomize build --load-restrictor=LoadRestrictionsNone` of every
  `kustomization.yaml` and kubeconform with Flux and Flux Operator schemas.
- `dev/flux/validate-fleet.sh` (fleet only) — the environment in three places, tags only outside the
  platform dev environment, `flux envsubst --strict` with each cluster's variables,
  `flux-operator build rset` with every order, every generated `GitRepository` on `refs/heads/` or
  `refs/tags/`, unique order names, only orders in order folders.

For new manifests also use `flux schema validate` from `gitops-knowledge`. The agent never calls the
cluster: when a reconcile or another cluster command is needed, give it to the user.
