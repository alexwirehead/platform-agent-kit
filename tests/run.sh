#!/usr/bin/env bash
# shellcheck disable=SC2016 # обратные кавычки в строках — markdown, а не подстановка
# Тесты установщика: копия кита с тестовыми профилями, установка --offline во временные проекты.
# Запуск из любого каталога: tests/run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Копия кита без .git и тестовые профили: a, и b, который требует a.
KIT="$WORK/kit"
mkdir -p "$KIT"
(cd "$ROOT" && tar --exclude=.git -cf - .) | (cd "$KIT" && tar -xf -)
for p in a b; do
  mkdir -p "$KIT/profiles/test-$p/skills/test-$p-skill"
  printf '## Profile %s\n\nRule of %s.\n' "$p" "$p" > "$KIT/profiles/test-$p/rules.md"
  printf '| situation %s | `test-%s-skill` |\n' "$p" "$p" > "$KIT/profiles/test-$p/skills.md"
  printf -- '- check of %s\n' "$p" > "$KIT/profiles/test-$p/review.md"
  printf -- '---\nname: test-%s-skill\ndescription: test\n---\n' "$p" \
    > "$KIT/profiles/test-$p/skills/test-$p-skill/SKILL.md"
done
echo test-a > "$KIT/profiles/test-b/requires"

FAILED=0
PASSED=0

fail() {
  echo "  FAIL: $*"
  FAILED=$((FAILED + 1))
}

# Новый пустой проект под git; печатает путь.
new_project() {
  local dir
  dir="$(mktemp -d "$WORK/project.XXXX")"
  git -C "$dir" init -q
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  echo "$dir"
}

install() {
  "$KIT/install.sh" --offline "$@" > /dev/null
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" commit -q -m snapshot
}

assert_file() { [ -f "$1/$2" ] || fail "no file $2"; }
assert_no_path() { [ ! -e "$1/$2" ] && [ ! -L "$1/$2" ] || fail "path $2 must not exist"; }
assert_contains() { grep -qF -- "$3" "$1/$2" || fail "$2 has no '$3'"; }
assert_count() {
  local n
  n="$(grep -cF -- "$3" "$1/$2" || true)"
  [ "$n" = "$4" ] || fail "$2 has '$3' $n times, want $4"
}

test_core_install() {
  local p
  p="$(new_project)"
  install "$p"
  assert_contains "$p" AGENTS.md '<!-- platform-agent-kit:begin -->'
  assert_contains "$p" AGENTS.md '<!-- platform-agent-kit:end -->'
  assert_contains "$p" AGENTS.md 'Rules that must not be broken'
  assert_contains "$p" AGENTS.md '`change-workflow`'
  assert_contains "$p" AGENTS.md 'Decision log:'
  assert_contains "$p" CLAUDE.md '@AGENTS.md'
  for c in simplify code-review security-review; do
    assert_file "$p" ".opencode/commands/$c.md"
  done
  assert_file "$p" .agents/skills/change-workflow/SKILL.md
  [ -L "$p/.claude/skills/change-workflow" ] || fail "no symlink .claude/skills/change-workflow"
  assert_file "$p" .claude/skills/change-workflow/SKILL.md
  assert_file "$p" TASKS.md
  assert_file "$p" docs/specs/README.md
  assert_contains "$p" .gitignore '.agents/'
  assert_contains "$p" .agent-kit.lock 'profiles='
}

test_rerun_changes_nothing() {
  local p
  p="$(new_project)"
  install "$p" test-b
  commit_all "$p"
  install "$p" test-b
  [ -z "$(git -C "$p" status --porcelain)" ] || fail "rerun changed: $(git -C "$p" status --porcelain)"
  assert_count "$p" .gitignore '.agents/' 1
}

test_project_text_kept() {
  local p
  p="$(new_project)"
  printf '# My project\n\nMy own rule.\n' > "$p/AGENTS.md"
  install "$p"
  assert_contains "$p" AGENTS.md 'My own rule.'
  assert_contains "$p" AGENTS.md '<!-- platform-agent-kit:begin -->'
  # Текст после блока и ручная правка внутри блока: первый остаётся, вторая исчезает.
  printf '\nTail rule.\n' >> "$p/AGENTS.md"
  awk '{ sub(/Rules that must not be broken/, "Edited by hand"); print }' "$p/AGENTS.md" > "$p/tmp"
  mv "$p/tmp" "$p/AGENTS.md"
  install "$p"
  assert_contains "$p" AGENTS.md 'My own rule.'
  assert_contains "$p" AGENTS.md 'Tail rule.'
  assert_contains "$p" AGENTS.md 'Rules that must not be broken'
  assert_count "$p" AGENTS.md 'Edited by hand' 0
  assert_count "$p" AGENTS.md '<!-- platform-agent-kit:begin -->' 1
}

test_requires_and_order() {
  local p
  p="$(new_project)"
  install "$p" test-b
  assert_contains "$p" .agent-kit.lock 'profiles=test-a test-b'
  assert_contains "$p" AGENTS.md '| situation a | `test-a-skill` |'
  assert_contains "$p" AGENTS.md '- check of b'
  local a b
  a="$(grep -n 'Profile a' "$p/AGENTS.md" | cut -d: -f1)"
  b="$(grep -n 'Profile b' "$p/AGENTS.md" | cut -d: -f1)"
  [ "$a" -lt "$b" ] || fail "profile a must come before b"
}

test_dropped_profile_removed() {
  local p
  p="$(new_project)"
  mkdir -p "$p/.claude/skills/own-skill"
  install "$p" test-b
  assert_file "$p" .agents/skills/test-b-skill/SKILL.md
  install "$p" test-a
  assert_no_path "$p" .agents/skills/test-b-skill
  assert_no_path "$p" .claude/skills/test-b-skill
  assert_count "$p" AGENTS.md 'Profile b' 0
  assert_file "$p" .agents/skills/test-a-skill/SKILL.md
  [ -d "$p/.claude/skills/own-skill" ] || fail "project skill removed"
}

test_unknown_profile_fails() {
  local p
  p="$(new_project)"
  if "$KIT/install.sh" --offline "$p" no-such-profile > /dev/null 2>&1; then
    fail "unknown profile accepted"
  fi
  assert_no_path "$p" AGENTS.md
}

test_templates_not_overwritten() {
  local p
  p="$(new_project)"
  echo 'my tasks' > "$p/TASKS.md"
  install "$p"
  assert_count "$p" TASKS.md 'my tasks' 1
  assert_count "$p" TASKS.md 'Этап 0' 0
}

test_every_real_profile() {
  local p d name
  for d in "$KIT"/profiles/*/; do
    name="$(basename "$d")"
    case "$name" in test-*) continue ;; esac
    [ -f "$d/rules.md" ] || continue
    p="$(new_project)"
    install "$p" "$name" || fail "profile $name failed"
    assert_contains "$p" .agent-kit.lock "$name"
  done
}

for t in $(declare -F | awk '{ print $3 }' | grep '^test_'); do
  before=$FAILED
  echo "== $t"
  "$t"
  if [ "$FAILED" -eq "$before" ]; then PASSED=$((PASSED + 1)); fi
done

echo "passed: $PASSED, failed checks: $FAILED"
[ "$FAILED" -eq 0 ]
