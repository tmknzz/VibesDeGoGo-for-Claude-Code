#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

PRETOOL="$ROOT/skills/vibesdegogo/scripts/vdgg-hook-pretool.sh"
TMPDIR_VDGG=$(mktemp -d)
trap 'rm -rf "$TMPDIR_VDGG"' EXIT

write_state() {
    local phase="$1" step="$2" loop="${3:-0}"
    mkdir -p "$TMPDIR_VDGG/.claude" "$TMPDIR_VDGG/tasks/vdgg/test-id"
    echo "test-id" > "$TMPDIR_VDGG/.claude/.vdgg-active"
    cat > "$TMPDIR_VDGG/.claude/.vdgg-state-test-id" <<EOF
step=${step}
phase=${phase}
loop_count=${loop}
current_task=T
vdgg_id=test-id
last_updated=2026-05-25T00:00:00Z
EOF
}

run_hook() {
    local json="$1"
    set +e
    printf '%s' "$json" | bash "$PRETOOL" >/tmp/vdgg-test-pretool.out 2>/tmp/vdgg-test-pretool.err
    local status=$?
    set -e
    echo "$status"
}

write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"swift test"}}')
assert_exit_code 2 "$STATUS" "implementing blocks test commands"

write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 2 "$STATUS" "verified transition is blocked without simplify sentinel"

write_state reflection 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 6 Start] step=6, phase=implementing, loop=0\nvdgg_state_loop 6 implementing"}}')
assert_exit_code 2 "$STATUS" "reflection cannot return without retry investigation"

write_state commit 9
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"git push origin main"}}')
assert_exit_code 2 "$STATUS" "branch-pr blocks pushing main"

write_state investigating 3
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/.claude/.vdgg-active"}}')
assert_exit_code 2 "$STATUS" "direct active file edit is blocked"

write_state investigating 3
STATUS=$(run_hook '{"tool_name":"Grep","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"pattern":"x"}}')
assert_exit_code 0 "$STATUS" "read-like tools pass during investigation"

# Review gate: a clean review sentinel (vdgg_state_mark_reviewed) satisfies verified.
write_state testing 7
cat > "$TMPDIR_VDGG/.claude/.vdgg-review-sentinel-test-id-0" <<EOF
started=1
started_at=2026-06-11T00:00:00Z
modified=0
modified_files=
EOF
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 0 "$STATUS" "verified transition is allowed with clean review sentinel"
assert_file_not_exists "$TMPDIR_VDGG/.claude/.vdgg-review-sentinel-test-id-0" "review sentinel is consumed on verified"

# Review gate: a modified review sentinel blocks verified.
write_state testing 7
cat > "$TMPDIR_VDGG/.claude/.vdgg-review-sentinel-test-id-0" <<EOF
started=1
started_at=2026-06-11T00:00:00Z
modified=1
modified_files=src/foo.sh
EOF
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 2 "$STATUS" "verified transition is blocked when review modified code"
rm -f "$TMPDIR_VDGG/.claude/.vdgg-review-sentinel-test-id-0"

# Sentinel forgery: direct Write to a sentinel path is blocked.
write_state testing 7
STATUS=$(run_hook '{"tool_name":"Write","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/.claude/.vdgg-simplify-sentinel-test-id-0"}}')
assert_exit_code 2 "$STATUS" "direct sentinel write is blocked"

# Sentinel forgery: Bash heredoc write to a sentinel path is blocked.
write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"cat > .claude/.vdgg-simplify-sentinel-test-id-0 <<EOF\nmodified=0\nEOF"}}')
assert_exit_code 2 "$STATUS" "bash sentinel forgery is blocked"

# P1-Both-2: a `git commit` segment must not shield a sidecar-mutating segment
# in the same command line.
write_state commit 9
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"git commit -m x && rm -f .claude/.vdgg-active"}}')
assert_exit_code 2 "$STATUS" "git commit does not shield sidecar deletion in same command"

# P1-CC-1: interpreter/tool-based sentinel forgery (not in the old blacklist) is blocked.
write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"dd of=.claude/.vdgg-simplify-sentinel-test-id-0"}}')
assert_exit_code 2 "$STATUS" "dd sentinel forgery is blocked"

write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"install -m 644 /dev/null .claude/.vdgg-simplify-sentinel-test-id-0"}}')
assert_exit_code 2 "$STATUS" "install sentinel forgery is blocked"

# Regression: a genuine sidecar read stays allowed.
write_state investigating 3
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"cat .claude/.vdgg-state-test-id"}}')
assert_exit_code 0 "$STATUS" "genuine sidecar read is allowed"

# P1-Both-3: an unknown phase must fail closed for mutating tools.
write_state impl 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/src/whatever.sh"}}')
assert_exit_code 2 "$STATUS" "unknown phase fails closed for edits"

write_state_with_allowlist() {
    local phase="$1" step="$2" loop="${3:-0}"
    write_state "$phase" "$step" "$loop"
    printf 'src/app.sh\n' > "$TMPDIR_VDGG/.claude/.vdgg-task-allowlist-test-id-${loop}"
    cat > "$TMPDIR_VDGG/.claude/.vdgg-state-test-id" <<EOF
step=${step}
phase=${phase}
loop_count=${loop}
current_task=T
task_allowlist_file=$TMPDIR_VDGG/.claude/.vdgg-task-allowlist-test-id-${loop}
task_base_ref=
vdgg_id=test-id
last_updated=2026-06-11T00:00:00Z
EOF
}

# Task allowlist: implementing edits are blocked without vdgg_task_begin.
write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/src/app.sh"}}')
assert_exit_code 2 "$STATUS" "implementing edit without allowlist is blocked"

# Task allowlist: allowlisted path is editable, others are not.
write_state_with_allowlist implementing 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/src/app.sh"}}')
assert_exit_code 0 "$STATUS" "allowlisted edit passes"
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/src/other.sh"}}')
assert_exit_code 2 "$STATUS" "non-allowlisted edit is blocked"

# Task allowlist: task notes stay editable without allowlisting.
write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/tasks/vdgg/test-id/progress.md"}}')
assert_exit_code 0 "$STATUS" "task notes edit passes without allowlist"

# Task gate: verified is blocked when the allowlist is active but the gate has not passed.
write_state_with_allowlist testing 7
cat > "$TMPDIR_VDGG/.claude/.vdgg-review-sentinel-test-id-0" <<EOF
started=1
started_at=2026-06-11T00:00:00Z
modified=0
modified_files=
EOF
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 2 "$STATUS" "verified is blocked without task gate pass"

# Task gate: verified passes once the gate file exists alongside a clean sentinel.
printf 'passed=1\n' > "$TMPDIR_VDGG/.claude/.vdgg-task-gate-test-id-0"
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 0 "$STATUS" "verified passes with task gate and clean sentinel"
rm -f "$TMPDIR_VDGG/.claude/.vdgg-task-gate-test-id-0" "$TMPDIR_VDGG/.claude/.vdgg-task-allowlist-test-id-0"

# jq missing: hooks stay out of the way when no VDGG session is active.
FAKEBIN=$(mktemp -d)
for tool in cat grep sed head; do
    ln -s "$(command -v $tool)" "$FAKEBIN/$tool"
done
BASH_BIN="$(command -v bash)"
NO_VDGG_DIR=$(mktemp -d)
set +e
printf '%s' '{"tool_name":"Bash","cwd":"'"$NO_VDGG_DIR"'","tool_input":{"command":"echo hi"}}' \
    | env PATH="$FAKEBIN" "$BASH_BIN" "$PRETOOL" >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 0 "$STATUS" "jq missing + inactive session does not block"

# jq missing: an active session still fails closed.
write_state implementing 6
set +e
printf '%s' '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"echo hi"}}' \
    | env PATH="$FAKEBIN" "$BASH_BIN" "$PRETOOL" >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 2 "$STATUS" "jq missing + active session fails closed"
rm -rf "$FAKEBIN" "$NO_VDGG_DIR"
