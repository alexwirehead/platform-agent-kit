## Flux GitOps

- GitOps repositories follow `flux-gitops`: Flux Operator with `FluxInstance` (`multitenant: true`) in
  every cluster, a fleet repository and a components repository, one `GitRepository` per component,
  versions as `<COMPONENT>_REF` in `environments/<env>/versions.yaml`, only protected tags
  `<component>/vX.Y.Z` outside the platform dev environment, a service is one `ResourceSetInputProvider`
  file.
- The agent works offline: `kustomize build`, `flux envsubst`, `flux-operator build rset`,
  `flux schema`, kubeconform, `dev/check-flux.sh`. Never `kubectl`, `flux reconcile`, `flux suspend`,
  `flux resume` or any other cluster call; when one is needed, give the user the exact command. The only
  exception is the `fluxcd-debug` profile.
- No unencrypted `Secret` in Git. The secrets delivery method (ESO, SOPS) is the project's decision.
- Deviations from third-party skills:
  - `gitops-knowledge`: delivery is Git-based (one `GitRepository` per component, versions in
    `versions.yaml`), not Gitless OCI; no image automation — a version changes by a merge request to
    `versions.yaml`; cluster commands in its references are for the user, not the agent;
  - `gitops-repo-audit`: infrastructure components applied as `cluster-admin` is the accepted design,
    not a finding — flag only service tenants or order folders with more than namespace admin; no OCI
    sources, so Cosign and OCI tag checks do not apply.
