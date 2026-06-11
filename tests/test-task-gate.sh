#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

TMPDIR_VDGG=$(mktemp -d)
trap 'rm -rf "$TMPDIR_VDGG"' EXIT

cd "$TMPDIR_VDGG" || exit 1
git init -q .
git config user.email "vdgg-test@example.com"
git config user.name "vdgg-test"
mkdir -p src
echo "v1" > src/app.sh
git add -A
git commit -qm "init"

VDGG_CWD="$TMPDIR_VDGG"
source "$ROOT/skills/vibesdegogo/scripts/vdgg-state.sh"

vdgg_state_init >/tmp/vdgg-test-task-init.out 2>/tmp/vdgg-test-task-init.err
ID=$(vdgg_get_id)
vdgg_state_advance 2 requirements >/dev/null 2>&1
vdgg_state_advance 3 investigating >/dev/null 2>&1
vdgg_state_advance 4 planning >/dev/null 2>&1
vdgg_state_advance 5 task-selected >/dev/null 2>&1

vdgg_task_begin "T1: demo" src/app.sh >/dev/null 2>&1
assert_file_exists ".claude/.vdgg-task-allowlist-${ID}-0" "task_begin creates allowlist"
STATE_ALLOWLIST=$(grep '^task_allowlist_file=' ".claude/.vdgg-state-${ID}" | cut -d= -f2-)
assert_ne "" "$STATE_ALLOWLIST" "task_begin records allowlist in state"

# Allowlisted change passes the check.
echo "v2" > src/app.sh
set +e
vdgg_task_check_allowlist >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 0 "$STATUS" "allowlisted change passes check"

# Out-of-allowlist change fails the check.
echo "x" > src/other.sh
set +e
vdgg_task_check_allowlist >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 1 "$STATUS" "out-of-allowlist change fails check"
rm -f src/other.sh

# Gate passes with a clean allowlist and a succeeding command.
set +e
vdgg_task_gate true >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 0 "$STATUS" "task gate passes"
assert_file_exists ".claude/.vdgg-task-gate-${ID}-0" "gate file recorded"

# Gate fails when the verification command fails.
set +e
vdgg_task_gate false >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 1 "$STATUS" "task gate propagates command failure"

# Rollback restores the baseline content and removes the gate file.
echo "v3" > src/app.sh
vdgg_task_rollback >/dev/null 2>&1
assert_eq "v1" "$(cat src/app.sh)" "rollback restores baseline content"
assert_file_not_exists ".claude/.vdgg-task-gate-${ID}-0" "rollback removes gate file"

# Task notes changes are ignored by changed-files (no allowlist violation).
mkdir -p "tasks/vdgg/${ID}"
echo "note" > "tasks/vdgg/${ID}/progress.md"
set +e
vdgg_task_check_allowlist >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 0 "$STATUS" "task notes are exempt from the allowlist"

vdgg_state_clear >/dev/null 2>&1
assert_file_not_exists ".claude/.vdgg-task-allowlist-${ID}-0" "clear removes task allowlist"
