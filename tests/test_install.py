"""Тесты install.sh: копия кита с тестовыми профилями, установка --offline во временные проекты."""

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
BEGIN = "<!-- platform-agent-kit:begin -->"


@pytest.fixture(scope="session")
def kit(tmp_path_factory):
    """Копия кита без .git и с тестовыми профилями: test-a и test-b, который требует test-a."""
    kit = tmp_path_factory.mktemp("kit") / "kit"
    shutil.copytree(
        ROOT, kit, ignore=shutil.ignore_patterns(".git", ".venv", "*_cache", "__pycache__", ".agents", ".claude")
    )
    for p in ("a", "b"):
        prof = kit / "profiles" / f"test-{p}"
        (prof / "skills" / f"test-{p}-skill").mkdir(parents=True)
        (prof / "rules.md").write_text(f"## Profile {p}\n\nRule of {p}.\n")
        (prof / "skills.md").write_text(f"| situation {p} | `test-{p}-skill` |\n")
        (prof / "review.md").write_text(f"- check of {p}\n")
        (prof / "skills" / f"test-{p}-skill" / "SKILL.md").write_text(
            f"---\nname: test-{p}-skill\ndescription: test\n---\n"
        )
    (kit / "profiles" / "test-b" / "requires").write_text("test-a\n")
    (kit / "profiles" / "test-a" / "README.md").write_text("# Profile test-a\n\nFirst line\nof a.\n\nMore.\n")
    (kit / "profiles" / "test-a" / "templates" / "dev").mkdir(parents=True)
    (kit / "profiles" / "test-a" / "templates" / "dev" / "a.txt").write_text("template of a\n")
    return kit


@pytest.fixture
def project(tmp_path):
    """Пустой проект под git."""
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "test@example.com")
    git(tmp_path, "config", "user.name", "test")
    return tmp_path


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True).stdout


def run(kit, project, *profiles):
    return subprocess.run(
        [str(kit / "install.sh"), "--offline", str(project), *profiles], capture_output=True, text=True
    )


def install(kit, project, *profiles):
    result = run(kit, project, *profiles)
    assert result.returncode == 0, result.stderr


def read(project, name):
    return (project / name).read_text()


def test_core_install(kit, project):
    install(kit, project)
    agents = read(project, "AGENTS.md")
    for text in (
        BEGIN,
        "<!-- platform-agent-kit:end -->",
        "Rules that must not be broken",
        "`change-workflow`",
        "Decision log:",
    ):
        assert text in agents
    assert "@AGENTS.md" in read(project, "CLAUDE.md")
    for c in ("simplify", "code-review", "security-review"):
        assert (project / ".opencode" / "commands" / f"{c}.md").is_file()
    assert (project / ".agents" / "skills" / "change-workflow" / "SKILL.md").is_file()
    assert (project / ".claude" / "skills" / "change-workflow").is_symlink()
    assert (project / ".claude" / "skills" / "change-workflow" / "SKILL.md").is_file()
    assert (project / "TASKS.md").is_file()
    assert (project / "docs" / "specs" / "README.md").is_file()
    assert ".agents/" in read(project, ".gitignore")
    assert "profiles=" in read(project, ".agent-kit.lock")


def test_rerun_changes_nothing(kit, project):
    install(kit, project, "test-b")
    git(project, "add", "-A")
    git(project, "commit", "-q", "-m", "snapshot")
    install(kit, project, "test-b")
    assert git(project, "status", "--porcelain") == ""
    assert read(project, ".gitignore").splitlines().count(".agents/") == 1


def test_project_text_kept(kit, project):
    (project / "AGENTS.md").write_text("# My project\n\nMy own rule.\n")
    install(kit, project)
    assert "My own rule." in read(project, "AGENTS.md")
    assert BEGIN in read(project, "AGENTS.md")
    # Текст после блока остаётся, ручная правка внутри блока исчезает.
    edited = read(project, "AGENTS.md").replace("Rules that must not be broken", "Edited by hand") + "\nTail rule.\n"
    (project / "AGENTS.md").write_text(edited)
    install(kit, project)
    agents = read(project, "AGENTS.md")
    assert "My own rule." in agents
    assert "Tail rule." in agents
    assert "Rules that must not be broken" in agents
    assert "Edited by hand" not in agents
    assert agents.count(BEGIN) == 1


def test_requires_order_and_templates(kit, project):
    install(kit, project, "test-b")
    agents = read(project, "AGENTS.md")
    assert "profiles=test-a test-b" in read(project, ".agent-kit.lock")
    assert "| situation a | `test-a-skill` |" in agents
    assert "- check of b" in agents
    assert agents.index("Profile a") < agents.index("Profile b")
    assert read(project, "dev/a.txt") == "template of a\n"


def test_dropped_profile_removed(kit, project):
    (project / ".claude" / "skills" / "own-skill").mkdir(parents=True)
    install(kit, project, "test-b")
    assert (project / ".agents" / "skills" / "test-b-skill" / "SKILL.md").is_file()
    install(kit, project, "test-a")
    for d in (".agents/skills/test-b-skill", ".claude/skills/test-b-skill"):
        assert not (project / d).exists() and not (project / d).is_symlink()
    assert "Profile b" not in read(project, "AGENTS.md")
    assert (project / ".agents" / "skills" / "test-a-skill" / "SKILL.md").is_file()
    assert (project / ".claude" / "skills" / "own-skill").is_dir()
    gitignore = read(project, ".gitignore").splitlines()
    assert "!.claude/skills/own-skill/" in gitignore
    assert "!.claude/skills/test-a-skill/" not in gitignore


def test_unknown_profile_fails(kit, project):
    result = run(kit, project, "no-such-profile")
    assert result.returncode != 0
    assert "unknown profile: no-such-profile" in result.stderr
    assert "test-a" in result.stderr
    assert not (project / "AGENTS.md").exists()


def test_help_lists_profiles(kit):
    result = subprocess.run([str(kit / "install.sh"), "--help"], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    lines = result.stdout.splitlines()
    assert any(line.split() == ["test-a", "First", "line", "of", "a."] for line in lines)
    assert any(line.split() == ["test-b", "(requires:", "test-a)"] for line in lines)
    for profile in (d.name for d in (ROOT / "profiles").iterdir() if d.is_dir()):
        assert any(line.split()[:1] == [profile] for line in lines), profile
    no_args = subprocess.run([str(kit / "install.sh")], capture_output=True, text=True)
    assert no_args.returncode != 0
    assert "profiles:" in no_args.stderr


def test_templates_not_overwritten(kit, project):
    (project / "TASKS.md").write_text("my tasks\n")
    install(kit, project)
    assert read(project, "TASKS.md") == "my tasks\n"


def test_broken_markers_fail(kit, project):
    text = f"# X\n\n{BEGIN}\nold\n\n## My section\nkeep me\n"
    (project / "AGENTS.md").write_text(text)
    assert run(kit, project).returncode != 0
    assert read(project, "AGENTS.md") == text


def test_crlf_agents(kit, project):
    install(kit, project)
    (project / "AGENTS.md").write_bytes(read(project, "AGENTS.md").replace("\n", "\r\n").encode())
    install(kit, project, "test-a")
    agents = read(project, "AGENTS.md")
    assert "Profile a" in agents
    assert agents.count(BEGIN) == 1


def test_gitignore_without_newline(kit, project):
    (project / ".gitignore").write_text("node_modules")
    install(kit, project)
    assert "node_modules" in read(project, ".gitignore").splitlines()


def test_third_party_skill_names(kit, project):
    """Имя стороннего навыка — последний элемент пути, для навыка в корне репозитория — имя репозитория."""
    prof = kit / "profiles" / "test-third"
    prof.mkdir(exist_ok=True)
    sha = "0" * 40
    (prof / "skills.txt").write_text(
        f"https://github.com/owner/repo/tree/{sha}/skills/sub-skill\nhttps://github.com/owner/root-skill/tree/{sha}\n"
    )
    install(kit, project, "test-third")
    skills = [line for line in read(project, ".agent-kit.lock").splitlines() if line.startswith("skills=")][0]
    assert {"sub-skill", "root-skill"} <= set(skills.removeprefix("skills=").split())
    assert sha not in skills


@pytest.mark.parametrize("profile", sorted(p.name for p in (ROOT / "profiles").iterdir() if p.is_dir()))
def test_every_real_profile(kit, project, profile):
    install(kit, project, profile)
    assert profile in read(project, ".agent-kit.lock")


def test_kit_agents_block_up_to_date(kit, project):
    """Блок AGENTS.md кита совпадает с тем, что собрал бы установщик (К12)."""
    text = (ROOT / "AGENTS.md").read_text()
    (project / "AGENTS.md").write_text(text)
    install(kit, project)
    assert read(project, "AGENTS.md") == text, "блок устарел: запусти ./install.sh . в корне кита"


def test_shellcheck():
    scripts = [ROOT / "install.sh", *sorted((ROOT / "profiles").glob("*/templates/**/*.sh"))]
    result = subprocess.run(["shellcheck", *map(str, scripts)], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout


def test_deleted_template_not_recreated(kit, project):
    install(kit, project)
    (project / "TASKS.md").unlink()
    install(kit, project)
    assert not (project / "TASKS.md").exists()
    assert "templates=" in read(project, ".agent-kit.lock")


def test_profile_project_lines(kit, project):
    install(kit, project, "external-api")
    assert "Facts document:" in read(project, "AGENTS.md")


def test_project_skill_wins_over_kit_skill(kit, project):
    own = project / ".claude" / "skills" / "test-a-skill"
    own.mkdir(parents=True)
    (own / "SKILL.md").write_text("project version\n")
    result = run(kit, project, "test-a")
    assert result.returncode == 0, result.stderr
    assert "project version" in (own / "SKILL.md").read_text()
    assert not (project / ".agents" / "skills" / "test-a-skill").exists()
    assert "!.claude/skills/test-a-skill/" in read(project, ".gitignore").splitlines()


@pytest.mark.skipif(not (shutil.which("helm") and shutil.which("kubeconform")), reason="no helm or kubeconform")
def test_check_chart_skips_crds(kit, project):
    install(kit, project, "helm")
    chart = project / "deploy" / "helm" / "app"
    chart.parent.mkdir(parents=True)
    subprocess.run(["helm", "create", str(chart)], check=True, capture_output=True)
    (chart / "ci").mkdir()
    (chart / "ci" / "default-values.yaml").write_text("{}\n")
    (chart / "templates" / "servicemonitor.yaml").write_text(
        "apiVersion: monitoring.coreos.com/v1\nkind: ServiceMonitor\nmetadata:\n  name: app\n"
        "spec:\n  selector: {}\n  endpoints: [{port: http}]\n"
    )
    result = subprocess.run([str(project / "dev" / "check-chart.sh")], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr


TERRAFORM_TOOLS = ("terraform", "terragrunt", "tflint", "trivy", "terraform-docs")


def check_terraform(project):
    return subprocess.run([str(project / "dev" / "check-terraform.sh")], capture_output=True, text=True)


@pytest.mark.skipif(not all(map(shutil.which, TERRAFORM_TOOLS)), reason="no terraform tools")
def test_check_terraform_module(kit, project):
    install(kit, project, "terraform")
    (project / "terraform.tf").write_text('terraform {\n  required_version = ">= 1.10"\n}\n')
    (project / "variables.tf").write_text(
        'variable "name" {\n  description = "Name of the resource"\n  type        = string\n}\n'
    )
    (project / "main.tf").write_text('resource "terraform_data" "main" {\n  input = var.name\n}\n')
    (project / "outputs.tf").write_text(
        'output "name" {\n  description = "Name of the resource"\n  value       = terraform_data.main.output\n}\n'
    )
    subprocess.run(
        ["terraform-docs", "markdown", "table", "--output-file", "README.md", "."],
        cwd=project,
        check=True,
        capture_output=True,
    )
    result = check_terraform(project)
    assert result.returncode == 0, result.stdout + result.stderr
    (project / "main.tf").write_text('resource "terraform_data" "main" {\ninput = var.name\n}\n')
    assert check_terraform(project).returncode != 0


@pytest.mark.skipif(not all(map(shutil.which, TERRAFORM_TOOLS)), reason="no terraform tools")
def test_check_terraform_live(kit, project):
    install(kit, project, "terraform")
    (project / "root.hcl").write_text('locals {\n  cloud = "test"\n}\n')
    unit = project / "folder" / "vpc"
    unit.mkdir(parents=True)
    (unit / "terragrunt.hcl").write_text('include "root" {\n  path = find_in_parent_folders("root.hcl")\n}\n')
    result = check_terraform(project)
    assert result.returncode == 0, result.stdout + result.stderr
    (unit / "terragrunt.hcl").write_text('include "root" {\npath = find_in_parent_folders("root.hcl")\n}\n')
    assert check_terraform(project).returncode != 0


CI_TOOLS = ("yamllint", "check-jsonschema", "shellcheck")
CI_TEMPLATE = """spec:
  inputs:
    stage:
      description: Stage of the job
      default: build
    parallel:
      description: Number of jobs
      type: number
      default: 2
---
build:
  stage: $[[ inputs.stage ]]
  parallel: $[[ inputs.parallel ]]
  script:
    - .gitlab/ci/scripts/build.sh
"""
CI_PIPELINE = """include:
  - component: $CI_SERVER_FQDN/$CI_PROJECT_PATH/build@$CI_COMMIT_SHA
  - local: .gitlab/ci/release.yml

stages: [build, release]
"""


def check_ci(project):
    return subprocess.run([str(project / "dev" / "check-ci.sh")], capture_output=True, text=True)


@pytest.mark.skipif(not all(map(shutil.which, CI_TOOLS)), reason="no gitlab-ci tools")
def test_check_ci(kit, project):
    install(kit, project, "gitlab-ci")
    (project / "templates" / "build").mkdir(parents=True)
    (project / "templates" / "build" / "template.yml").write_text(CI_TEMPLATE)
    ci = project / ".gitlab" / "ci"
    (ci / "scripts").mkdir(parents=True)
    (ci / "scripts" / "build.sh").write_text('#!/usr/bin/env bash\necho "build"\n')
    (ci / "release.yml").write_text(
        "release:\n  stage: release\n  rules:\n    - if: $CI_COMMIT_TAG\n  script: echo release\n"
    )
    (project / ".gitlab-ci.yml").write_text(CI_PIPELINE)
    result = check_ci(project)
    assert result.returncode == 0, result.stdout + result.stderr
    (ci / "release.yml").write_text("release:\n  stage: release\n  scirpt: echo release\n")
    assert check_ci(project).returncode != 0
    (ci / "release.yml").write_text("release:\n  stage: release\n  script: echo release\n")
    (ci / "scripts" / "build.sh").write_text("#!/usr/bin/env bash\necho $1\n")
    assert check_ci(project).returncode != 0


def test_install_md_lists_every_profile():
    """Таблица признаков INSTALL.md: строка на каждый профиль, иначе агент его не предложит."""
    text = (ROOT / "INSTALL.md").read_text()
    rows = {line.split("|")[1].strip().strip("`") for line in text.splitlines() if line.startswith("| `")}
    profiles = {p.name for p in (ROOT / "profiles").iterdir() if p.is_dir()}
    assert profiles <= rows, f"no row in INSTALL.md for: {sorted(profiles - rows)}"


def test_readme_points_agent_to_install_md():
    assert "INSTALL.md" in (ROOT / "README.md").read_text().split("\n## ")[0]


FLUX_TOOLS = ("kustomize", "kubeconform", "yq", "flux", "flux-operator")


def configmap(name, **data):
    lines = "".join(f"  {k}: {v}\n" for k, v in data.items())
    return f"apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: {name}\n  namespace: flux-system\ndata:\n{lines}"


def kustomization(*resources):
    return "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n" + "".join(
        f"  - {r}\n" for r in resources
    )


def git_template(namespace):
    return (
        "  resources:\n    - apiVersion: source.toolkit.fluxcd.io/v1\n      kind: GitRepository\n"
        f'      metadata:\n        name: "<< inputs.name >>"\n        namespace: {namespace}\n'
        "      spec:\n        interval: 10m\n        url: https://git.example.com/components.git\n"
        '        ref:\n          name: "<< inputs.ref >>"\n'
    )


def cluster(project, env, name, versions):
    path = f"clusters/{project}/{env}/{name}"
    return {
        f"{path}/kustomization.yaml": kustomization(
            "flux-system", "runtime-info.yaml", f"../../../../environments/{versions}"
        ),
        f"{path}/flux-system/kustomization.yaml": kustomization("flux-instance.yaml"),
        f"{path}/flux-system/flux-instance.yaml": (
            "apiVersion: fluxcd.controlplane.io/v1\nkind: FluxInstance\nmetadata:\n  name: flux\n"
            "  namespace: flux-system\nspec:\n  distribution:\n    version: 2.x\n    registry: ghcr.io/fluxcd\n"
            "  cluster:\n    multitenant: true\n  sync:\n    kind: GitRepository\n"
            f"    url: https://git.example.com/fleet.git\n    ref: refs/heads/main\n    path: {path}\n"
        ),
        f"{path}/runtime-info.yaml": configmap("flux-runtime-info", ENVIRONMENT=env, CLUSTER_NAME=name),
    }


FLEET = {
    "environments/platform-dev/kustomization.yaml": kustomization("versions.yaml"),
    "environments/platform-dev/versions.yaml": configmap("flux-versions", DEMO_REF="refs/heads/main"),
    "environments/dev/kustomization.yaml": kustomization("versions.yaml"),
    "environments/dev/versions.yaml": configmap("flux-versions", DEMO_REF="refs/tags/demo/v1.0.0"),
    **cluster("platform", "dev", "lab-01", "platform-dev"),
    **cluster("acme", "dev", "app-01", "dev"),
    "clusters/acme/dev/app-01/apps/demo-app.yaml": (
        "apiVersion: fluxcd.controlplane.io/v1\nkind: ResourceSetInputProvider\nmetadata:\n  name: demo-app\n"
        "  namespace: flux-system\n  labels:\n    example.com/kind: app\nspec:\n  type: Static\n"
        '  defaultValues:\n    name: demo-app\n    ref: "${DEMO_REF}"\n'
    ),
    "tenants/infra/kustomization.yaml": kustomization("resourceset.yaml"),
    "tenants/infra/resourceset.yaml": (
        "apiVersion: fluxcd.controlplane.io/v1\nkind: ResourceSet\nmetadata:\n  name: infra\n"
        '  namespace: flux-system\nspec:\n  inputs:\n    - name: demo\n      ref: "${DEMO_REF}"\n'
        + git_template("flux-system")
    ),
    "tenants/apps/kustomization.yaml": kustomization("resourceset.yaml"),
    "tenants/apps/resourceset.yaml": (
        "apiVersion: fluxcd.controlplane.io/v1\nkind: ResourceSet\nmetadata:\n  name: apps\n"
        "  namespace: flux-system\nspec:\n  inputsFrom:\n    - kind: ResourceSetInputProvider\n"
        "      selector:\n        matchLabels:\n          example.com/kind: app\n" + git_template('"<< inputs.name >>"')
    ),
}
COMPONENTS = {
    "infra/demo/controllers/base/kustomization.yaml": kustomization("demo.yaml"),
    "infra/demo/controllers/base/demo.yaml": configmap("demo", LEVEL="info"),
    "infra/demo/controllers/dev/kustomization.yaml": kustomization("../base"),
}


def write_tree(root, files):
    for name, text in files.items():
        (root / name).parent.mkdir(parents=True, exist_ok=True)
        (root / name).write_text(text)


def check_flux(project):
    return subprocess.run([str(project / "dev" / "check-flux.sh")], capture_output=True, text=True)


@pytest.mark.skipif(not all(map(shutil.which, FLUX_TOOLS)), reason="no flux tools")
def test_check_flux_fleet(kit, project):
    install(kit, project, "fluxcd")
    script = project / "dev" / "check-flux.sh"
    write_tree(project, FLEET)
    assert "PLATFORM_PROJECT and ORDER_LABEL" in check_flux(project).stdout
    script.write_text(
        script.read_text().replace("<platform-project>", "platform").replace("<domain>/kind", "example.com/kind")
    )
    result = check_flux(project)
    assert result.returncode == 0, result.stdout + result.stderr
    broken = {
        # check-refs.sh: ключ не <ИМЯ>_REF validate-fleet.sh не видит.
        "environments/platform-dev/versions.yaml": ("DEMO_REF", "DEMO_REF: refs/heads/main\n  DEMO_VERSION"),
        # validate-fleet.sh: пользовательский проект смотрит в ветку.
        "environments/dev/versions.yaml": ("refs/tags/demo/v1.0.0", "refs/heads/main"),
        # Опечатку ловят оба: check-refs.sh до сборки, validate-fleet.sh после.
        "tenants/infra/resourceset.yaml": ("${DEMO_REF}", "{DEMO_REF}"),
    }
    for name, (old, new) in broken.items():
        (project / name).write_text(FLEET[name].replace(old, new))
        assert check_flux(project).returncode != 0, name
        (project / name).write_text(FLEET[name])


@pytest.mark.skipif(not all(map(shutil.which, FLUX_TOOLS)), reason="no flux tools")
def test_check_flux_components(kit, project):
    install(kit, project, "fluxcd")
    write_tree(project, COMPONENTS)
    result = check_flux(project)
    assert result.returncode == 0, result.stdout + result.stderr
    extra = project / "infra" / "demo" / "controllers" / "base" / "extra.yml"
    extra.write_text(configmap("extra"))
    assert check_flux(project).returncode != 0
    extra.unlink()
    (project / "infra" / "demo" / "controllers" / "dev" / "kustomization.yaml").write_text(kustomization("../missing"))
    assert check_flux(project).returncode != 0
