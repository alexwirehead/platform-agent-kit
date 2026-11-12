## GitLab CI

- Pipelines and components follow `gitlab-ci-components`. A template becomes a component only when it
  is needed in two or more projects now, the difference fits `spec:inputs` and the interface is stable;
  otherwise it stays local. Before migrating old templates, write an assessment table and get it
  approved by the user.
- Logic with branches, loops or functions never stays in `script:`: it goes to
  `.gitlab/ci/scripts/<name>.sh` or into the component's image.
- Checks: `dev/check-ci.sh` offline, then `glab ci lint` with the user's `glab` login, read-only. Never
  run, retry or cancel pipelines; never read or change CI/CD variables.
