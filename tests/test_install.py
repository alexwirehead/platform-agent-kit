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
    shutil.copytree(ROOT, kit, ignore=shutil.ignore_patterns(".git", ".venv", "*_cache", "__pycache__"))
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
    assert run(kit, project, "no-such-profile").returncode != 0
    assert not (project / "AGENTS.md").exists()


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


@pytest.mark.parametrize("profile", sorted(p.name for p in (ROOT / "profiles").iterdir() if p.is_dir()))
def test_every_real_profile(kit, project, profile):
    install(kit, project, profile)
    assert profile in read(project, ".agent-kit.lock")


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
