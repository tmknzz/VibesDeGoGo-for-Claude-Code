#!/bin/bash
# vdgg-state.sh - VibesDeGoGo! state file helpers for Claude Code.
#
# state file: .claude/.vdgg-state-{id}
# active file: .claude/.vdgg-active  (stores the currently active id)
# tasks dir:   tasks/vdgg/{id}/

# Capture the working directory at source time; later `cd` calls should not
# silently move the state root.
: "${VDGG_CWD:=$(pwd)}"

VDGG_STATE_DIR="${VDGG_STATE_DIR:-${VDGG_CWD}/.claude}"
VDGG_TASKS_DIR="${VDGG_TASKS_DIR:-${VDGG_CWD}/tasks/vdgg}"

# --- Internal helpers ---

_vdgg_generate_id() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M)
    local random
    # Avoid SIGPIPE from `tr | head` under caller shells using `set -o pipefail`.
    random=$(LC_ALL=C od -An -N8 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-4)
    echo "${timestamp}-${random}"
}

_vdgg_active_file() {
    echo "${VDGG_STATE_DIR}/.vdgg-active"
}

_vdgg_state_file_for_id() {
    local id="$1"
    echo "${VDGG_STATE_DIR}/.vdgg-state-${id}"
}

_vdgg_review_file_for_id() {
    local id="$1"
    local loop="$2"
    echo "${VDGG_STATE_DIR}/.vdgg-review-sentinel-${id}-${loop}"
}

_vdgg_task_allowlist_file_for_id() {
    local id="$1"
    local loop="$2"
    echo "${VDGG_STATE_DIR}/.vdgg-task-allowlist-${id}-${loop}"
}

_vdgg_task_baseline_dir_for_id() {
    local id="$1"
    local loop="$2"
    echo "${VDGG_STATE_DIR}/.vdgg-task-baseline-${id}-${loop}"
}

_vdgg_task_baseline_status_for_id() {
    local id="$1"
    local loop="$2"
    echo "${VDGG_STATE_DIR}/.vdgg-task-baseline-status-${id}-${loop}"
}

_vdgg_task_gate_file_for_id() {
    local id="$1"
    local loop="$2"
    echo "${VDGG_STATE_DIR}/.vdgg-task-gate-${id}-${loop}"
}

# NOTE: never declare `local path` in these helpers — when the script is
# sourced into zsh, `path` is tied to $PATH and localizing it empties PATH.
# Strip the project prefix (or ./) so allowlist entries are repo-relative.
_vdgg_normalize_path() {
    local entry="$1"
    case "$entry" in
        "$VDGG_CWD"/*) entry="${entry#"$VDGG_CWD"/}" ;;
        ./*) entry="${entry#./}" ;;
    esac
    printf '%s\n' "$entry"
}

_vdgg_path_is_safe_relative() {
    local entry
    entry=$(_vdgg_normalize_path "$1")
    [ -n "$entry" ] || return 1
    case "$entry" in
        /*|../*|*/../*|..|.) return 1 ;;
    esac
    return 0
}

_vdgg_task_loop() {
    local state_file loop
    state_file=$(_vdgg_get_state_file)
    loop=$(grep '^loop_count=' "$state_file" | cut -d= -f2)
    printf '%s\n' "${loop:-0}"
}

# Remove matched state sidecar files without requiring a shell glob to expand.
# This keeps cleanup quiet when no matching files exist.
_vdgg_rm_glob() {
    [ -d "$1" ] || return 0
    find "$1" -maxdepth 1 -name "$2" -type f -exec rm -f {} + 2>/dev/null || true
}

_vdgg_rm_dir_glob() {
    [ -d "$1" ] || return 0
    find "$1" -maxdepth 1 -name "$2" -type d -exec rm -rf {} + 2>/dev/null || true
}

# Append VibesDeGoGo!'s own sidecar patterns to the project .gitignore if it
# exists and doesn't already contain them. Idempotent (uses a marker comment).
# Skips silently when no .gitignore is present (we don't create one).
# This prevents Step 9 from being blocked by surprise untracked .claude/ files
# at commit time.
_vdgg_ensure_gitignore() {
    local gitignore="${VDGG_CWD}/.gitignore"
    [ -f "$gitignore" ] || return 0
    if grep -qF '# Claude Code / VibesDeGoGo!' "$gitignore"; then
        return 0
    fi
    # One glob covers every sidecar type (state, active, error, sentinels, and
    # any future .vdgg-* files) so new types never need a second update here.
    cat >> "$gitignore" <<'EOF'

# Claude Code / VibesDeGoGo!
.claude/.vdgg-*
EOF
    echo "vdgg-state: appended VibesDeGoGo! patterns to ${gitignore}" >&2
}

_vdgg_get_active_id() {
    local active_file
    active_file=$(_vdgg_active_file)
    if [ -f "$active_file" ]; then
        cat "$active_file"
    else
        echo ""
    fi
}

_vdgg_get_state_file() {
    local id
    id=$(_vdgg_get_active_id)
    if [ -z "$id" ]; then
        echo ""
        return 1
    fi
    _vdgg_state_file_for_id "$id"
}

# Step continuity check.
# Allowed: +0, +1, 8->5 for selecting the next task, and 7->6 for retry loops.
_vdgg_check_step_transition() {
    local current="$1"
    local next="$2"

    if ! [[ "$next" =~ ^[0-9]+$ ]] || ! [[ "$current" =~ ^[0-9]+$ ]]; then
        echo "vdgg-state: invalid or blocked state transition" >&2
        return 1
    fi

    if [ "$next" -eq "$current" ] || [ "$next" -eq $((current + 1)) ]; then
        return 0
    fi
    # progress(8) -> task-selected(5): continue with remaining tasks.
    if [ "$current" -eq 8 ] && [ "$next" -eq 5 ]; then
        return 0
    fi
    # testing(7) -> implementing(6): retry through reflection.
    if [ "$current" -eq 7 ] && [ "$next" -eq 6 ]; then
        return 0
    fi

    echo "vdgg-state: invalid or blocked state transition" >&2
    return 1
}

# --- Public functions ---

vdgg_state_init() {
    local id
    id=$(_vdgg_generate_id)
    local active_file
    active_file=$(_vdgg_active_file)
    local state_file
    state_file=$(_vdgg_state_file_for_id "$id")
    local tasks_dir="${VDGG_TASKS_DIR}/${id}"

    # Refuse to start if a previous VibesDeGoGo! session is still active so its
    # state is not silently overwritten.
    if [ -f "$active_file" ]; then
        local old_id
        old_id=$(cat "$active_file")
        echo "vdgg-state: active VibesDeGoGo! session already exists (id=${old_id})" >&2
        return 1
    fi

    mkdir -p "$(dirname "$state_file")"
    mkdir -p "$tasks_dir"

    # Self-manage project .gitignore so Step 9 commit isn't blocked by our
    # own sidecar files. No-op if .gitignore is absent or already includes us.
    _vdgg_ensure_gitignore

    # Clear stale sidecars from previous sessions before creating the new state.
    rm -f "${VDGG_STATE_DIR}/.vdgg-error-pending" 2>/dev/null || true
    _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-simplify-sentinel-*'
    _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-review-sentinel-*'
    _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-task-*'
    _vdgg_rm_dir_glob "${VDGG_STATE_DIR}" '.vdgg-task-baseline-*'

    # Store the active id before writing the state file.
    echo "$id" > "$active_file"

    # Initialize the state file in KEY=VALUE format for hook parsing.
    cat > "$state_file" << EOF
step=1
phase=declare
loop_count=0
current_task=
task_allowlist_file=
task_base_ref=
vdgg_id=${id}
last_updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
    echo "vdgg-state: initialized id=${id}, state=${state_file}, tasks=${tasks_dir}" >&2
}

vdgg_state_read() {
    local state_file
    state_file=$(_vdgg_get_state_file)
    if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
        echo "step=0"
        echo "phase=none"
        echo "loop_count=0"
        echo "current_task="
        echo "task_allowlist_file="
        echo "task_base_ref="
        echo "vdgg_id="
        echo "last_updated="
        return 1
    fi
    cat "$state_file"
}

vdgg_state_write() {
    local new_step="$1"
    local new_phase="$2"
    local new_loop_count="$3"
    local new_current_task="${4:-}"
    local new_task_allowlist_file="${5:-}"
    local new_task_base_ref="${6:-}"

    if [ -z "$new_step" ] || [ -z "$new_phase" ] || [ -z "$new_loop_count" ]; then
        echo "vdgg-state: invalid or blocked state transition" >&2
        return 1
    fi

    if ! [[ "$new_step" =~ ^[0-9]+$ ]]; then
        echo "vdgg-state: invalid or blocked state transition" >&2
        return 1
    fi
    # Phase must be one of the known workflow phases. An open regex would let a
    # same-step transition move into an arbitrary phase name that no pretool
    # case arm matches, silently disabling every edit/commit/test guard.
    case "$new_phase" in
        declare|requirements|investigating|planning|task-selected|implementing|testing|reflection|verified|progress|commit) ;;
        *)
            echo "vdgg-state: invalid or blocked state transition" >&2
            return 1
            ;;
    esac
    if ! [[ "$new_loop_count" =~ ^[0-9]+$ ]]; then
        echo "vdgg-state: invalid or blocked state transition" >&2
        return 1
    fi

    local state_file
    state_file=$(_vdgg_get_state_file)
    if [ -z "$state_file" ]; then
        echo "vdgg-state: invalid or blocked state transition" >&2
        return 1
    fi

    if [ -f "$state_file" ]; then
        local current_step
        current_step=$(grep "^step=" "$state_file" | cut -d= -f2)
        current_step="${current_step:-0}"
        if ! _vdgg_check_step_transition "$current_step" "$new_step"; then
            return 1
        fi
    fi

    local id
    id=$(_vdgg_get_active_id)

    # Preserve current_task and task gate fields when callers omit them.
    # A literal `-` clears a task field explicitly (used at the 8->5 boundary).
    if [ -f "$state_file" ]; then
        if [ -z "$new_current_task" ]; then
            new_current_task=$(grep "^current_task=" "$state_file" | cut -d= -f2-)
        fi
        if [ "$new_task_allowlist_file" = "-" ]; then
            new_task_allowlist_file=""
        elif [ -z "$new_task_allowlist_file" ]; then
            new_task_allowlist_file=$(grep "^task_allowlist_file=" "$state_file" | cut -d= -f2- || true)
        fi
        if [ "$new_task_base_ref" = "-" ]; then
            new_task_base_ref=""
        elif [ -z "$new_task_base_ref" ]; then
            new_task_base_ref=$(grep "^task_base_ref=" "$state_file" | cut -d= -f2- || true)
        fi
    fi

    cat > "$state_file" << EOF
step=${new_step}
phase=${new_phase}
loop_count=${new_loop_count}
current_task=${new_current_task}
task_allowlist_file=${new_task_allowlist_file}
task_base_ref=${new_task_base_ref}
vdgg_id=${id}
last_updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
    echo "vdgg-state: -> step=$new_step, phase=$new_phase, loop=$new_loop_count (id=$id)" >&2
}

vdgg_state_advance() {
    local next_step="$1"
    local next_phase="$2"

    local state_file
    state_file=$(_vdgg_get_state_file)
    if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
        echo "vdgg_state_advance: state file not found" >&2
        return 1
    fi

    local current_step
    current_step=$(grep "^step=" "$state_file" | cut -d= -f2)
    current_step="${current_step:-0}"

    # Guard 1: every state transition must obey the allowed step graph.
    if ! _vdgg_check_step_transition "$current_step" "$next_step"; then
        return 1
    fi

    local current_loop
    current_loop=$(grep "^loop_count=" "$state_file" | cut -d= -f2)
    current_loop="${current_loop:-0}"

    local current_task
    current_task=$(grep "^current_task=" "$state_file" | cut -d= -f2-)

    # When Step 8 continues to Step 5, start the next task with a fresh loop
    # and clear the previous task's allowlist/baseline so vdgg_task_begin is
    # required again before any new-task edits.
    if [ "$current_step" -eq 8 ] && [ "$next_step" -eq 5 ]; then
        vdgg_state_write "$next_step" "$next_phase" 0 "$current_task" - -
        return
    fi

    vdgg_state_write "$next_step" "$next_phase" "$current_loop" "$current_task"
}

vdgg_state_loop() {
    local loop_step="$1"
    local loop_phase="$2"

    local state_file
    state_file=$(_vdgg_get_state_file)
    if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
        echo "vdgg_state_loop: state file not found" >&2
        return 1
    fi

    local current_step
    current_step=$(grep "^step=" "$state_file" | cut -d= -f2)
    current_step="${current_step:-0}"

    # Guard 1: every retry loop must still obey the allowed step graph.
    if ! _vdgg_check_step_transition "$current_step" "$loop_step"; then
        return 1
    fi

    local current_loop
    current_loop=$(grep "^loop_count=" "$state_file" | cut -d= -f2)
    current_loop="${current_loop:-0}"
    local new_loop=$((current_loop + 1))

    local current_task
    current_task=$(grep "^current_task=" "$state_file" | cut -d= -f2-)

    # Drop the previous loop's simplify sentinel so review cannot leak forward.
    local vdgg_id
    vdgg_id=$(_vdgg_get_active_id)
    if [ -n "$vdgg_id" ]; then
        rm -f "${VDGG_STATE_DIR}/.vdgg-simplify-sentinel-${vdgg_id}-${current_loop}" 2>/dev/null || true
        rm -f "${VDGG_STATE_DIR}/.vdgg-review-sentinel-${vdgg_id}-${current_loop}" 2>/dev/null || true
    fi

    vdgg_state_write "$loop_step" "$loop_phase" "$new_loop" "$current_task"
}

vdgg_state_mark_reviewed() {
    local state_file
    state_file=$(_vdgg_get_state_file)
    if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
        echo "vdgg_state_mark_reviewed: state file not found" >&2
        return 1
    fi

    local id
    id=$(_vdgg_get_active_id)
    local loop
    loop=$(grep "^loop_count=" "$state_file" | cut -d= -f2)
    loop="${loop:-0}"

    local review_file
    review_file=$(_vdgg_review_file_for_id "$id" "$loop")
    cat > "$review_file" << EOF
started=1
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
modified=0
modified_files=
EOF
    echo "vdgg-state: review gate marked for id=${id}, loop=${loop}" >&2
}

# Run an explicit review pass and mark the review gate only when it succeeds.
# With arguments, runs them as the review command. Without arguments, runs
# REVIEW_COMMAND from .vdgg-target via bash -c. Exit status of a failing
# review is propagated and no sentinel is written.
vdgg_review_run() {
    if [ "$#" -gt 0 ]; then
        "$@" || return $?
    else
        local review_command=""
        if [ -f "${VDGG_CWD}/.vdgg-target" ]; then
            review_command=$(grep '^REVIEW_COMMAND=' "${VDGG_CWD}/.vdgg-target" | head -1 | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/')
        fi
        if [ -z "$review_command" ]; then
            echo "vdgg_review_run: no command given and no REVIEW_COMMAND in .vdgg-target" >&2
            return 1
        fi
        bash -c "$review_command" || return $?
    fi
    vdgg_state_mark_reviewed
}

# Begin one task: record its title, an allowlist of files it may change, and a
# baseline snapshot used by vdgg_task_gate / vdgg_task_rollback.
vdgg_task_begin() {
    local task_title="${1:-}"
    shift || true

    if [ -z "$task_title" ]; then
        echo "vdgg_task_begin: task title is required" >&2
        return 1
    fi
    if [ "$#" -eq 0 ]; then
        echo "vdgg_task_begin: at least one allowlist path is required" >&2
        return 1
    fi

    local id
    id=$(_vdgg_get_active_id)
    if [ -z "$id" ]; then
        echo "vdgg_task_begin: active session not found" >&2
        return 1
    fi

    # Refuse BEFORE any side effect: (re)arming is only legal where a state
    # write to step 5 is (Step 4/5/8 per _vdgg_check_step_transition). Called
    # from implementing/reflection it would otherwise clobber the active
    # loop's allowlist/baseline and then fail the state write anyway, leaving
    # the hook enforcing a stale (or, same-loop, a deleted) allowlist while
    # still printing a success message.
    local current_step state_file
    state_file=$(_vdgg_state_file_for_id "$id")
    if [ -f "$state_file" ]; then
        current_step=$(grep "^step=" "$state_file" | cut -d= -f2)
        if ! _vdgg_check_step_transition "${current_step:-0}" 5 2>/dev/null; then
            echo "vdgg_task_begin: blocked — cannot (re)arm a task outside Step 5 (current step=${current_step})." >&2
            echo "vdgg_task_begin: fit the change to the current allowlist, or take the extra scope as a new task via Step 8 -> Step 5." >&2
            return 1
        fi
    fi

    local loop allowlist_file baseline_dir baseline_status gate_file entry normalized
    loop=$(_vdgg_task_loop)
    allowlist_file=$(_vdgg_task_allowlist_file_for_id "$id" "$loop")
    baseline_dir=$(_vdgg_task_baseline_dir_for_id "$id" "$loop")
    baseline_status=$(_vdgg_task_baseline_status_for_id "$id" "$loop")
    gate_file=$(_vdgg_task_gate_file_for_id "$id" "$loop")

    rm -rf "$baseline_dir"
    rm -f "$gate_file"
    mkdir -p "$baseline_dir"
    : > "$allowlist_file"

    for entry in "$@"; do
        if ! _vdgg_path_is_safe_relative "$entry"; then
            echo "vdgg_task_begin: unsafe allowlist path: $entry" >&2
            return 1
        fi
        normalized=$(_vdgg_normalize_path "$entry")
        printf '%s\n' "$normalized" >> "$allowlist_file"
        if [ -e "${VDGG_CWD}/$normalized" ]; then
            mkdir -p "$(dirname "$baseline_dir/$normalized")"
            cp -R "${VDGG_CWD}/$normalized" "$baseline_dir/$normalized"
        fi
    done
    sort -u "$allowlist_file" -o "$allowlist_file"
    git -C "$VDGG_CWD" status --porcelain=v1 --untracked-files=all > "$baseline_status"

    # Single state write records the task and both gate fields atomically.
    # The transition was pre-checked above, so a failure here is unexpected —
    # still, never report success on a failed write: roll the side effects
    # back so no half-armed gate survives.
    if ! vdgg_state_write 5 task-selected "$loop" "$task_title" "$allowlist_file" "$baseline_status"; then
        rm -rf "$baseline_dir"
        rm -f "$allowlist_file" "$gate_file" "$baseline_status"
        echo "vdgg_task_begin: state write failed; task gate not armed." >&2
        return 1
    fi
    echo "vdgg-task: began '${task_title}' with allowlist ${allowlist_file}" >&2
}

# List files changed since vdgg_task_begin, excluding VibesDeGoGo!'s own
# sidecars and the session's task notes under tasks/vdgg/.
vdgg_task_changed_files() {
    local id loop baseline_status current_status
    id=$(_vdgg_get_active_id)
    if [ -z "$id" ]; then
        echo "vdgg_task_changed_files: active session not found" >&2
        return 1
    fi
    loop=$(_vdgg_task_loop)
    # Prefer the baseline recorded at vdgg_task_begin so the comparison stays
    # anchored to the task even after vdgg_state_loop increments the loop.
    baseline_status=$(grep '^task_base_ref=' "$(_vdgg_get_state_file)" | cut -d= -f2- || true)
    if [ -z "$baseline_status" ]; then
        baseline_status=$(_vdgg_task_baseline_status_for_id "$id" "$loop")
    fi
    current_status=$(mktemp)
    git -C "$VDGG_CWD" status --porcelain=v1 --untracked-files=all > "$current_status"
    { [ -f "$baseline_status" ] && cat "$baseline_status"; cat "$current_status"; } \
        | sort | uniq -u \
        | sed -E 's/^...//; s/^"//; s/"$//; s/.* -> //' \
        | grep -v '^\.claude/\.vdgg-' \
        | grep -v "^tasks/vdgg/${id}/" \
        | sort -u || true
    rm -f "$current_status"
}

vdgg_task_check_allowlist() {
    local id loop allowlist_file changed file
    id=$(_vdgg_get_active_id)
    if [ -z "$id" ]; then
        echo "vdgg_task_check_allowlist: active session not found" >&2
        return 1
    fi
    loop=$(_vdgg_task_loop)
    allowlist_file=$(grep '^task_allowlist_file=' "$(_vdgg_get_state_file)" | cut -d= -f2- || true)
    if [ -z "$allowlist_file" ] || [ ! -f "$allowlist_file" ]; then
        echo "vdgg_task_check_allowlist: allowlist not found" >&2
        return 1
    fi
    changed=$(vdgg_task_changed_files)
    [ -n "$changed" ] || return 0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if ! grep -qxF "$file" "$allowlist_file"; then
            echo "vdgg-task: allowlist violation: $file" >&2
            return 1
        fi
    done <<EOF
$changed
EOF
}

# Run the verification command through the task gate: the allowlist must hold
# and the command must succeed before the per-loop gate file is written.
vdgg_task_gate() {
    local id loop gate_file
    vdgg_task_check_allowlist || return 1
    if [ "$#" -gt 0 ]; then
        "$@" || return $?
    fi
    id=$(_vdgg_get_active_id)
    loop=$(_vdgg_task_loop)
    gate_file=$(_vdgg_task_gate_file_for_id "$id" "$loop")
    cat > "$gate_file" << EOF
passed=1
passed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
    echo "vdgg-task: gate passed for id=${id}, loop=${loop}" >&2
}

# Revert the current task's changes back to the vdgg_task_begin baseline.
vdgg_task_rollback() {
    local id loop base_ref baseline_dir gate_file changed file
    id=$(_vdgg_get_active_id)
    if [ -z "$id" ]; then
        echo "vdgg_task_rollback: active session not found" >&2
        return 1
    fi
    loop=$(_vdgg_task_loop)
    # Derive the baseline dir from the stored task_base_ref so rollback survives
    # vdgg_state_loop increments; fall back to the current-loop derivation.
    base_ref=$(grep '^task_base_ref=' "$(_vdgg_get_state_file)" | cut -d= -f2- || true)
    if [ -n "$base_ref" ]; then
        baseline_dir="${base_ref/baseline-status-/baseline-}"
    else
        baseline_dir=$(_vdgg_task_baseline_dir_for_id "$id" "$loop")
    fi
    gate_file=$(_vdgg_task_gate_file_for_id "$id" "$loop")
    if [ ! -d "$baseline_dir" ]; then
        echo "vdgg_task_rollback: baseline dir not found" >&2
        return 1
    fi

    vdgg_task_check_allowlist || return 1
    rm -f "$gate_file"
    changed=$(vdgg_task_changed_files)
    [ -n "$changed" ] || return 0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        if [ -e "$baseline_dir/$file" ]; then
            rm -rf "${VDGG_CWD:?}/$file"
            mkdir -p "$(dirname "${VDGG_CWD}/$file")"
            cp -R "$baseline_dir/$file" "${VDGG_CWD}/$file"
        else
            rm -rf "${VDGG_CWD:?}/$file"
        fi
    done <<EOF
$changed
EOF
    echo "vdgg-task: rolled back current task changes" >&2
}

vdgg_state_clear() {
    local active_file
    active_file=$(_vdgg_active_file)
    local id
    id=$(_vdgg_get_active_id)

    if [ -n "$id" ]; then
        local state_file
        state_file=$(_vdgg_state_file_for_id "$id")
        if [ -f "$state_file" ]; then
            rm "$state_file"
        fi
    fi

    if [ -f "$active_file" ]; then
        rm "$active_file"
    fi

    # Remove sidecars that should never survive into the next session.
    rm -f "${VDGG_STATE_DIR}/.vdgg-error-pending" 2>/dev/null || true
    _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-simplify-sentinel-*'
    _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-review-sentinel-*'
    _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-task-*'
    _vdgg_rm_dir_glob "${VDGG_STATE_DIR}" '.vdgg-task-baseline-*'

    echo "vdgg-state: cleared (id=$id)" >&2
}

# --- Utilities ---

vdgg_get_tasks_dir() {
    local id
    id=$(_vdgg_get_active_id)
    if [ -z "$id" ]; then
        echo "${VDGG_CWD}/tasks/vdgg"
        return 1
    fi
    echo "${VDGG_TASKS_DIR}/${id}"
}

vdgg_get_id() {
    _vdgg_get_active_id
}
