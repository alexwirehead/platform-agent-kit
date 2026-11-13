"""Тесты scripts/count-tokens.py: счётчик подменяется подсчётом слов, токенизатор не нужен."""

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("count_tokens", ROOT / "scripts" / "count-tokens.py")
count_tokens = importlib.util.module_from_spec(spec)
spec.loader.exec_module(count_tokens)


def words(text):
    return len(text.split())


def skill(root, name, body, **files):
    d = root / name
    d.mkdir(parents=True)
    (d / "SKILL.md").write_text(f"---\nname: {name}\ndescription: one two\n---\n{body}")
    for rel, content in files.items():
        (d / rel).parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            (d / rel).write_bytes(content)
        else:
            (d / rel).write_text(content)
    return d


def test_measure(tmp_path):
    (tmp_path / "AGENTS.md").write_text("a b c\n")
    agents = tmp_path / ".agents" / "skills"
    small = skill(agents, "small", "x\n", **{"references/ref.md": "r r r r\n", "logo.png": b"\x89PNG\x00\xff"})
    skill(agents, "big", "x x x x x\n")
    claude = tmp_path / ".claude" / "skills"
    claude.mkdir(parents=True)
    (claude / "small").symlink_to(small)
    skill(claude, "own", "x x\n")

    agents_md, skills = count_tokens.measure(tmp_path, words)

    assert agents_md == 3
    # Имя, тело, прочие файлы, frontmatter (name и description); симлинк small — один раз.
    assert skills == [("big", 5, 0, 5), ("own", 2, 0, 5), ("small", 1, 4, 5)]


def test_measure_without_agents_md(tmp_path):
    assert count_tokens.measure(tmp_path, words) == (0, [])
