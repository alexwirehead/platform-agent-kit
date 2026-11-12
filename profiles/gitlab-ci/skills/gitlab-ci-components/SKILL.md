---
name: gitlab-ci-components
description: Team conventions for GitLab CI/CD (GitLab 18.11) — deciding whether a component is needed at all, refactoring old shared templates (include project + extends) into components, component repository layout, spec inputs, self-testing, release to the CI/CD Catalog, consumer versions, keeping script logic out of YAML, offline checks and glab ci lint. Use when writing or reviewing .gitlab-ci.yml, a component template, or migrating templates to components. Триггеры — гитлаб, gitlab-ci, пайплайн, компонент, CI/CD каталог, шаблон CI, include, extends, inputs, рефакторинг шаблонов.
---

# GitLab CI components and pipelines

GitLab 18.11. CI syntax comes from the official docs (`source-driven-development`), never from memory:
https://docs.gitlab.com/ci/components/, https://docs.gitlab.com/ci/inputs/, https://docs.gitlab.com/ci/yaml/.

## 1. Is a component needed at all

Do not turn a template into a component by default. A template becomes a component only when **all
three** hold:

1. It is needed in **two or more projects now**, not "some day".
2. The projects differ in what `spec:inputs` can express, not in copied and edited jobs.
3. Its interface (inputs, job names, stages) is stable.

Otherwise it stays local: a job in `.gitlab-ci.yml`, an `include: local` file, or `extends` inside the
project.

A large YAML file is **not** a reason for a component — components are for reuse, not for size. Size is
handled like this, whatever the verdict:

- Logic in `script:` with branches, loops or functions moves into `.gitlab/ci/scripts/<name>.sh`:
  shellcheck checks it, it runs locally, the job keeps one call line.
- A large pipeline is split into `.gitlab/ci/*.yml` files with `include: local`. This is structure, not
  reuse.
- The same logic needed in two or more projects becomes a component: the script lives in the
  component's image, the template stays thin (inputs and the call). Never copy a script between projects.

## 2. Refactoring old templates

Old style: a shared repository with hidden jobs (`.build_*`), consumed with `include: project` + `ref`
+ `file` and `extends`.

1. **Assess first.** Write a table in the spec of the project doing the refactoring:

   | Template | Consumers | Verdict | Reason |
   |---|---|---|---|
   | `.build_image` | 6 projects | component `build-image` | same job everywhere, differs by image name and context — inputs |
   | `.notify_chat` | 1 project | local | one consumer |
   | `.lint_old` | 0 | delete | not used |

   Verdicts: **component**, **keep local**, **merge into another component**, **delete**. Consumers are
   counted from real `include` and `extends` usages, not guessed; ask the user when they cannot be found.
2. **The user approves the table.** Nothing is migrated before that.
3. **One template at a time:** release the component, then move consumers one by one. The old template
   stays under its existing tag while it has consumers; delete it after the last one moved.

## 3. Component repository

One repository per component, published in the CI/CD Catalog: the **CI/CD Catalog project** toggle is
on and the project has a description.

```
templates/<name>/template.yml   the component; only this file is released to consumers
templates/<name>/Dockerfile     the component's own image, if it has one
.gitlab/ci/scripts/             scripts used by the repository's own pipeline
tests/                          fixtures the self-test runs on
README.md                       required: what the component does, inputs, an include example
.gitlab-ci.yml                  build image, self-test, release
```

A component without its own image may be a single file `templates/<name>.yml`.

### Inputs

Every input has `description`. Add `type` (`string`, `number`, `boolean`, `array`), `options`, `regex`
and `default` where they fit; an input without `default` is mandatory.

```yaml
spec:
  inputs:
    stage:
      description: Stage of the build job
      default: build
    image-name:
      description: Name of the image in the registry
---
build-image:
  stage: $[[ inputs.stage ]]
  image: <registry>/<name>:1.4.0
  script:
    - build-image "$[[ inputs.image-name ]]"
```

### Own image

The image is built in the same repository: `:<sha>` in merge requests, `:X.Y.Z` on a release tag. The
template references `:X.Y.Z`. The release job fails when the image tag in the template differs from the
release tag — bump the template together with the tag.

Building images is itself a component (buildah, push to the registry), not a hidden `.build_*` job from a
shared template.

### Self-test and release

```yaml
include:
  # the component from this commit, on the fixture in tests/
  - component: $CI_SERVER_FQDN/$CI_PROJECT_PATH/<name>@$CI_COMMIT_SHA
    inputs:
      context: tests/<fixture>

stages: [build, test, release]

create-release:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:<version>
  rules:
    - if: $CI_COMMIT_TAG =~ /^[0-9]+\.[0-9]+\.[0-9]+$/
  script:
    - |
      grep -q "<name>:$CI_COMMIT_TAG\$" templates/<name>/template.yml || {
        echo "ERROR: template image is not <name>:$CI_COMMIT_TAG"
        exit 1
      }
  release:
    tag_name: $CI_COMMIT_TAG
    description: "Release $CI_COMMIT_TAG of $CI_PROJECT_PATH"
```

- The tag is `X.Y.Z` without `v`. The release is created only by a job with the `release` keyword after
  the tests in the tag pipeline: this is how GitLab publishes to the catalog.
- An incompatible change of inputs, job names or behaviour bumps the major version: consumers on `@1`
  must not break.

## 4. Consumers

```yaml
include:
  - component: $CI_SERVER_FQDN/<group>/<project>/<name>@1
    inputs:
      image-name: app
```

Version is major or minor (`@1`, `@1.2`): fixes arrive without a merge request. Partial versions work
only for components published in the CI/CD Catalog. Never a branch or `~latest`; a SHA only in the
component's own self-test.

## 5. Checks

- `dev/check-ci.sh`, offline: yamllint for `.gitlab-ci.yml`, `.gitlab/ci/*.yml` and `templates/`; the
  GitLab CI schema (`check-jsonschema --builtin-schema vendor.gitlab-ci`) for `.gitlab-ci.yml` and
  `.gitlab/ci/*.yml`; shellcheck for `.gitlab/ci/scripts/`.
- The schema does not check component templates: a template is two YAML documents, and a `number` or
  `boolean` input is a string before substitution — the schema reports false errors. A template is
  checked by the self-test pipeline and `glab ci lint` on that pipeline.
- `glab ci lint` (`--dry-run --ref <branch>` to simulate pipeline creation) is the only check that
  expands `include` and validates inputs. The agent runs it itself with the user's `glab` login,
  read-only. This is the one exception to "the agent does not call the real system": the agent never
  runs or retries pipelines and never reads or changes CI/CD variables.
