## Flux cluster debugging

- The agent reaches a live cluster only through the Flux Operator MCP server started with
  `flux-operator-mcp serve --read-only` (reconcile, suspend, resume, apply and delete tools disabled)
  and secrets masked (`--mask-secrets`, the default). The user configures the server; the kit does not.
- If write tools are present, the server is not read-only: do not use them, tell the user.
- Deviation from `gitops-cluster-debug`: never change the cluster, even when asked. A fix is a merge
  request to the repository; a reconcile or other cluster command is given to the user to run.
