# /// script
# requires-python = ">=3.10"
# dependencies = ["tiktoken", "tokenizers", "huggingface_hub"]
# ///
"""Сколько токенов контекста съедают AGENTS.md и навыки проекта (решение К18).

Запуск из клона кита: uv run scripts/count-tokens.py <проект> [--hf <репо|tokenizer.json>].
Без --hf — оценка токенизатором o200k_base; с --hf — токенизатор модели с Hugging Face.
"""

import argparse
from pathlib import Path

SKILL_DIRS = (".agents/skills", ".claude/skills")


def split_frontmatter(text):
    """Frontmatter без разделителей и тело SKILL.md."""
    if text.startswith("---\n"):
        front, sep, body = text[4:].partition("\n---\n")
        if sep:
            return front, body
    return "", text


def read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


def measure(project, count):
    """Токены AGENTS.md и строки навыков (имя, тело, прочие файлы, frontmatter) по убыванию тела."""
    agents = project / "AGENTS.md"
    agents_md = count(agents.read_text()) if agents.is_file() else 0
    seen = set()
    skills = []
    for root in SKILL_DIRS:
        for skill_md in sorted((project / root).glob("*/SKILL.md")):
            folder = skill_md.parent.resolve()
            if folder in seen:
                continue
            seen.add(folder)
            front, body = split_frontmatter(skill_md.read_text())
            others = sum(
                count(text)
                for f in sorted(folder.rglob("*"))
                if f.is_file() and f.name != "SKILL.md" and (text := read_text(f)) is not None
            )
            skills.append((skill_md.parent.name, count(body), others, count(front)))
    skills.sort(key=lambda s: (-s[1], s[0]))
    return agents_md, skills


def counter(hf):
    if hf:
        from tokenizers import Tokenizer

        tok = Tokenizer.from_file(hf) if Path(hf).is_file() else Tokenizer.from_pretrained(hf)
        return f"{hf} (Hugging Face)", lambda text: len(tok.encode(text, add_special_tokens=False).ids)
    import tiktoken

    enc = tiktoken.get_encoding("o200k_base")
    return "o200k_base (оценка)", lambda text: len(enc.encode(text, disallowed_special=()))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("project", type=Path)
    parser.add_argument("--hf", help="репозиторий модели на Hugging Face или путь к tokenizer.json")
    args = parser.parse_args()

    name, count = counter(args.hf)
    agents_md, skills = measure(args.project, count)
    fronts = sum(s[3] for s in skills)
    width = max([len("skill list")] + [len(s[0]) for s in skills])

    print(f"Токенизатор: {name}\n")
    print("Всегда в контексте:")
    print(f"  {'AGENTS.md':<{width}} {agents_md:>7}")
    print(f"  {'skill list':<{width}} {fronts:>7}   frontmatter {len(skills)} навыков, на каждом шаге")
    print(f"  {'total':<{width}} {agents_md + fronts:>7}\n")
    print("Навыки: body — при загрузке, files — если дочитать всё, front — в списке навыков")
    print(f"  {'skill':<{width}} {'body':>7} {'files':>7} {'front':>6}")
    for skill_name, body, others, front in skills:
        print(f"  {skill_name:<{width}} {body:>7} {others:>7} {front:>6}")
    print(f"  {'total':<{width}} {sum(s[1] for s in skills):>7} {sum(s[2] for s in skills):>7} {fronts:>6}")


if __name__ == "__main__":
    main()
