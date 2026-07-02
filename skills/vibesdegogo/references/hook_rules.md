# VibesDeGoGo! Reference: Hook Rules

This file documents the behavior implemented by the hooks.

## Common Guards

Sidecar files are protected. Edit/Write tools targeting any path matching:

```text
.claude/.vdgg-*
```

are blocked outright. Bash commands are split into shell segments (on `&&`, `||`,
`;`, `|`, newline) and each segment that mentions a sidecar path is checked with
a **whitelist** (fail-closed): the segment is allowed only if it is a `git commit`
(whose message may mention a sidecar path without writing it) or a genuine read —
a leading read-only verb (`cat`, `grep`, `test`, `ls`, `head`, `tail`, …) with no
output redirection or `tee`. Every other form — interpreters (`python`, `perl`),
`dd`, `install`, `truncate`, redirects, file ops — is denied. Segmenting means a
`git commit` cannot shield a sidecar-mutating segment in the same command line.

This covers state files, the active marker, and the simplify/review sentinels —
so the review gate cannot be satisfied by forging a sentinel. Use `vdgg_state_*`
helpers instead. The same write protection also applies to `.vdgg-target`
(reads stay allowed), so the agent cannot self-author `REVIEW_COMMAND` or a
`STEP*_EXECUTOR_COMMAND` to forge a passing review or run an arbitrary command.

Step declarations are validated for Bash commands that call:

```text
vdgg_state_advance
vdgg_state_loop
vdgg_state_write
```

The Bash command text must include the matching declaration:

```bash
# [VibesDeGoGo! Step 3 Start] step=3, phase=investigating, loop=0
source "$VDGG_SKILL_DIR/scripts/vdgg-state.sh" && vdgg_state_advance 3 investigating
```

For Step 2, `[VibesDeGoGo! Declaration]` is also accepted because it follows Step 1 initialization.

## Phase Behavior

| phase | Step | Edit/Write | Bash | Agent |
|---|---:|---|---|---|
| no state | none | allow | allow | allow |
| `declare` | 1 | only `tasks/vdgg/{id}/` | allow except state writes | block |
| `requirements` | 2 | only `tasks/vdgg/{id}/` | require `requirements.md` before Step 3 | block |
| `investigating` | 3 | only `tasks/vdgg/{id}/` | allow except state writes | allow |
| `planning` | 4 | only `tasks/vdgg/{id}/` | allow except state writes | allow |
| `task-selected` | 5 | block | allow except state writes | allow |
| `implementing` | 6 | only task-allowlisted files (task notes exempt) | block commits and test commands | allow |
| `testing` | 7 | only task-allowlisted files (task notes exempt) | block commits, direct testing to implementing, and verified without review gate + task gate | allow |
| `reflection` | 6-R | only `progress.md` and `investigation-r*.md` | block direct verified and require updated retry docs before implementing | allow |
| `verified` | 7 end | block | allow except state writes | allow |
| `progress` | 8 | only `progress.md` and configured version files | allow except state writes | allow |
| `commit` | 9 | only `progress.md` and configured version files | allow commit; block base branch commit/push in branch-pr | allow |

## Error Recognition

PostToolUse detects Bash failures and writes:

```text
.claude/.vdgg-error-pending
```

Before the next tool call, PreToolUse requires assistant text containing:

```text
[Error Acknowledged]
```

The agent should briefly state what failed and what it will do next.

Search commands such as `rg`, `grep`, `find`, `sed`, `awk`, `jq`, `test`, and `[` are treated specially: exit code 1 is allowed as "no matches".

## Review Gate (simplify or explicit review)

During `testing`, successful verification must be followed by a review pass.
Two sentinels can satisfy the gate:

```text
.claude/.vdgg-simplify-sentinel-{vdgg_id}-{loop_count}   created by PostToolUse when the simplify skill runs
.claude/.vdgg-review-sentinel-{vdgg_id}-{loop_count}     created by vdgg_state_mark_reviewed / vdgg_review_run
```

Fields (both sentinels):

```text
started=1
started_at=<UTC timestamp>
modified=0|1
modified_files=<comma-separated paths>
```

Verified transition behavior:

- no sentinel present: block verified transition,
- `modified=0`: allow verified transition and delete the sentinels,
- `modified=1`: block verified transition and require reflection plus re-test.

PostToolUse flips `modified=1` on whichever sentinel exists when Edit/Write
touches implementation files during `testing` (sidecar and `tasks/vdgg/` paths
are excluded). Sentinels cannot be written directly; see Common Guards.

## Known Limits

- The Stop hook depends on Claude Code providing `cwd` and `transcript_path` in hook JSON. If Claude Code changes that contract, the Stop hook may become a no-op rather than a blocker.
- The reflection gate compares whole-second file mtimes; if `progress.md` or `investigation-r*.md` is written in the same second as the state transition, the return to implementing can be blocked once — retrying a moment later succeeds.
- The sidecar write guard matches the literal `.claude/.vdgg-` path in the Bash command text. A segment that hides the path behind a shell variable or command substitution (e.g. `D=.claude; rm -f "$D/.vdgg-active"`) can evade the match. The hook raises the cost of forgery but is a guardrail, not a security boundary; it does not sandbox a determined agent.
