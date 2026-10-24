#!/usr/bin/env bash
# Ставит правила и навыки кита в проект (спецификация docs/specs/001-kit-v1.md).
# Запуск: install.sh [--offline] <каталог-проекта> [профиль...]
# --offline — не скачивать сторонние навыки (для тестов). Совместим с bash 3.2 (macOS).
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_CLI="skills@1.7.4"
BEGIN='<!-- platform-agent-kit:begin -->'
END='<!-- platform-agent-kit:end -->'

die() {
  echo "install.sh: $*" >&2
  exit 1
}

# contains <значение> <элемент...> — есть ли значение среди элементов.
contains() {
  local x="$1" e
  shift
  for e in "$@"; do
    [ "$e" = "$x" ] && return 0
  done
  return 1
}

# Строки файла без комментариев и пустых; файла нет — ничего.
lines() {
  [ -f "$1" ] || return 0
  grep -v -e '^#' -e '^[[:space:]]*$' "$1" || true
}

OFFLINE=0
if [ "${1:-}" = "--offline" ]; then
  OFFLINE=1
  shift
fi
[ $# -ge 1 ] || die "usage: install.sh [--offline] <project-dir> [profile...]"
TARGET="$(cd "$1" 2> /dev/null && pwd)" || die "no such directory: $1"
shift

# Профили в порядке аргументов, зависимости из requires — перед зависимым.
PROFILES=()
add_profile() {
  local name="$1" depth="$2" req
  [ "$depth" -le 10 ] || die "requires cycle at profile $name"
  [ -n "$name" ] && [ -d "$KIT/profiles/$name" ] || die "unknown profile: $name"
  for req in $(lines "$KIT/profiles/$name/requires"); do
    add_profile "$req" $((depth + 1))
  done
  contains "$name" ${PROFILES[@]+"${PROFILES[@]}"} || PROFILES+=("$name")
}
for name in "$@"; do
  add_profile "$name" 0
done

# count_line <файл> <строка> — сколько строк файла равны строке (CRLF не мешает).
count_line() {
  awk -v m="$2" '{ sub(/\r$/, "") } $0 == m { n++ } END { print n + 0 }' "$1"
}

# Маркеры блока в AGENTS.md: оба нет — блок допишется, оба по одному и по порядку — заменится.
AGENTS="$TARGET/AGENTS.md"
MODE=new
if [ -f "$AGENTS" ]; then
  MODE=append
  b="$(count_line "$AGENTS" "$BEGIN")"
  e="$(count_line "$AGENTS" "$END")"
  if [ "$b" = 1 ] && [ "$e" = 1 ]; then
    MODE=replace
    awk -v begin="$BEGIN" -v end="$END" '{ sub(/\r$/, "") } $0 == end && !seen { exit 1 } $0 == begin { seen = 1 }' \
      "$AGENTS" || die "$AGENTS: end marker before begin marker"
  elif [ "$b" != 0 ] || [ "$e" != 0 ]; then
    die "$AGENTS: need exactly one '$BEGIN' and one '$END' line, found $b and $e"
  fi
fi

# Каталоги-источники: ядро, затем профили.
SOURCES=("$KIT/core")
for name in ${PROFILES[@]+"${PROFILES[@]}"}; do
  SOURCES+=("$KIT/profiles/$name")
done

# Свои навыки (каталоги) и сторонние (URL); имя навыка — последний элемент пути.
OWN=()
THIRD=()
for src in "${SOURCES[@]}"; do
  for d in "$src"/skills/*/; do
    [ -d "$d" ] && OWN+=("${d%/}")
  done
  for url in $(lines "$src/skills.txt"); do
    THIRD+=("$url")
  done
done
SKILLS=()
for d in ${OWN[@]+"${OWN[@]}"} ${THIRD[@]+"${THIRD[@]}"}; do
  SKILLS+=("$(basename "$d")")
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Блок AGENTS.md: правила ядра и профилей, таблица навыков, пункты ревью.
{
  echo "$BEGIN"
  echo "<!-- Managed by platform-agent-kit install.sh; edits inside this block are overwritten. -->"
  for src in "${SOURCES[@]}"; do
    [ -f "$src/rules.md" ] || continue
    echo
    cat "$src/rules.md"
  done
  echo
  echo "## Skills table"
  echo
  echo "| Situation | Skill |"
  echo "|---|---|"
  for src in "${SOURCES[@]}"; do
    lines "$src/skills.md"
  done
  echo
  echo "## Review checks"
  echo
  echo "Project-specific items for \`code-review\` and \`security-review\`."
  echo
  review="$(for src in "${SOURCES[@]}"; do lines "$src/review.md"; done)"
  echo "${review:-- none}"
  echo "$END"
} > "$TMP/block"

# write_if_changed <файл> <новое содержимое во временном файле>
write_if_changed() {
  cmp -s "$2" "$1" 2> /dev/null || cp "$2" "$1"
}

if [ "$MODE" = new ]; then
  {
    echo "# $(basename "$TARGET")"
    echo
    echo "## Project"
    echo
    echo "- Decision log: \`<path>\` — where project decisions are recorded."
    echo "- Full verification command: \`<command>\` — run before every commit."
    echo
    cat "$TMP/block"
  } > "$AGENTS"
elif [ "$MODE" = replace ]; then
  awk -v block="$TMP/block" -v begin="$BEGIN" -v end="$END" '
    { l = $0; sub(/\r$/, "", l) }
    l == begin { while ((getline line < block) > 0) print line; skip = 1; next }
    l == end { skip = 0; next }
    !skip { print }
  ' "$AGENTS" > "$TMP/agents"
  write_if_changed "$AGENTS" "$TMP/agents"
else
  { echo; cat "$TMP/block"; } >> "$AGENTS"
fi

[ -f "$TARGET/CLAUDE.md" ] || echo "@AGENTS.md" > "$TARGET/CLAUDE.md"

# Навыки: убрать те, что ставились раньше и больше не нужны, затем поставить нужные.
LOCK="$TARGET/.agent-kit.lock"
mkdir -p "$TARGET/.agents/skills" "$TARGET/.claude/skills"
if [ -f "$LOCK" ]; then
  # shellcheck disable=SC2013 # skills= — имена через пробел, нужны слова
  for old in $(sed -n 's/^skills=//p' "$LOCK"); do
    contains "$old" ${SKILLS[@]+"${SKILLS[@]}"} && continue
    rm -rf "${TARGET:?}/.agents/skills/$old"
    [ -L "$TARGET/.claude/skills/$old" ] && rm -f "$TARGET/.claude/skills/$old"
  done
fi
for d in ${OWN[@]+"${OWN[@]}"}; do
  name="$(basename "$d")"
  rm -rf "${TARGET:?}/.agents/skills/$name"
  cp -R "$d" "$TARGET/.agents/skills/$name"
  link="$TARGET/.claude/skills/$name"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "install.sh: $link is a project directory, symlink skipped" >&2
  else
    ln -sfn "../../.agents/skills/$name" "$link"
  fi
done
if [ "$OFFLINE" -eq 0 ]; then
  for url in ${THIRD[@]+"${THIRD[@]}"}; do
    echo "== $(basename "$url")"
    (cd "$TARGET" && npx -y "$SKILLS_CLI" add "$url" -a claude-code -a opencode -y)
  done
fi

# Команды OpenCode и шаблоны; шаблон не перезаписывает файл проекта.
mkdir -p "$TARGET/.opencode/commands"
for f in "$KIT"/core/commands/*.md; do
  write_if_changed "$TARGET/.opencode/commands/$(basename "$f")" "$f"
done
(cd "$KIT/core/templates" && find . -type f) | while read -r rel; do
  dst="$TARGET/${rel#./}"
  [ -e "$dst" ] && continue
  mkdir -p "$(dirname "$dst")"
  cp "$KIT/core/templates/${rel#./}" "$dst"
done

# .gitignore: блок кита один раз, исключения для своих навыков проекта (не симлинков кита).
GITIGNORE="$TARGET/.gitignore"
if [ -s "$GITIGNORE" ] && [ -n "$(tail -c 1 "$GITIGNORE")" ]; then
  echo >> "$GITIGNORE"
fi
if ! grep -qF "# platform-agent-kit" "$GITIGNORE" 2> /dev/null; then
  {
    echo "# platform-agent-kit: installed skills; project skills are kept by !.claude/skills/<name>/ lines"
    echo ".agents/"
    echo ".claude/skills/*"
    echo "skills-lock.json"
  } >> "$GITIGNORE"
fi
for d in "$TARGET"/.claude/skills/*/; do
  d="${d%/}"
  name="$(basename "$d")"
  [ -d "$d" ] && [ ! -L "$d" ] || continue
  contains "$name" ${SKILLS[@]+"${SKILLS[@]}"} && continue
  grep -qxF "!.claude/skills/$name/" "$GITIGNORE" || echo "!.claude/skills/$name/" >> "$GITIGNORE"
done

COMMIT="$(git -C "$KIT" rev-parse HEAD 2> /dev/null || echo unknown)"
if [ "$COMMIT" != unknown ] && [ -n "$(git -C "$KIT" status --porcelain)" ]; then
  COMMIT="$COMMIT-dirty"
fi
{
  echo "# platform-agent-kit: generated by install.sh, do not edit"
  echo "commit=$COMMIT"
  echo "profiles=${PROFILES[*]+"${PROFILES[*]}"}"
  echo "skills=${SKILLS[*]+"${SKILLS[*]}"}"
} > "$TMP/lock"
write_if_changed "$LOCK" "$TMP/lock"

echo "installed: core${PROFILES[*]+ ${PROFILES[*]}} -> $TARGET"
