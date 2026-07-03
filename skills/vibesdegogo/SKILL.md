---
name: "VibesDeGoGo!"
description: "A state-and-hook workflow for Claude Code that keeps coding agents moving until done while stopping only before constraint violations."
version: 0.3.0
---

# VibesDeGoGo!

VibesDeGoGo! is a serial, state-file-driven workflow for autonomous coding with Claude Code. It uses a state file plus Claude Code hooks to mechanically enforce the order of work. The agent does the work directly by default, and delegates to subagents only when parallel work is clearly useful.

## When To Use

Use VibesDeGoGo! for coding work: implementation, diagnosis, refactoring, or improvement work where the agent should carry the request through to verification and commit.

Do not use it for wording-only requests, open-ended discussion, or brainstorming where no code or repository workflow should be executed.

Trigger phrases include `/VibesDeGoGo!`, "use VibesDeGoGo!", and similar requests.

## Agent Role

- Declare before acting: output a Step declaration at the beginning of each Step.
- Update the state file: every Step start and completion must update state through `vdgg_state_*` helpers.
- Lead Steps 1, 2, 5, 8, and 9 directly.
- Execute Steps 3, 4, 6, and 7 directly unless delegation is clearly better.
- Delegate only when parallel execution helps or when multiple independent tasks can safely run at the same time.
- Do not delegate merely to save context, because the area is unfamiliar, or because the work may take time.
- Monitor subagents and correct direction if they drift.

### Delegated step executors

Steps 3, 4, and 6 communicate only through files under `tasks/vdgg/{id}/`, so their executor is swappable. When `.vdgg-target` sets `STEP3_EXECUTOR_COMMAND`, `STEP4_EXECUTOR_COMMAND`, or `STEP6_EXECUTOR_COMMAND` (see `references/target_schema.md`), run that command for the step instead of doing the work inline, using the matching prompt from `references/subagent_prompts.md` with paths filled in. Before advancing, validate the executor's artifacts yourself: the output file exists and contains the required headings; for Step 6, the task allowlist and `vdgg_task_gate` still apply, which catches any out-of-allowlist edits the executor made. Steps 1, 2, 5, 8, and 9 are never delegated.

### Formation (executor tiers)

Activation: when `.vdgg-target` sets `STEP6_EXECUTOR_TIERS` (see `references/target_schema.md`), Step 6 uses a tier ladder instead of a single executor. The value is an ordered `|`-separated list of executor commands, cheapest first; the reserved terminal tier `inline` means the agent implements the task itself. When `STEP6_EXECUTOR_TIERS` is unset, behavior is exactly as before (single `STEP6_EXECUTOR_COMMAND` or inline work). When both are set, `STEP6_EXECUTOR_TIERS` wins.

Start tier: each task starts at tier 1. Exception — the agent MAY start a task at a higher tier when the task is clearly heavyweight: contract changes (API, persistence, auth, security), changes spanning multiple modules, or concurrency-sensitive work. State the chosen start tier and the reason in the user-facing text.

Escalation rule: the first verification failure of a task stays on the same tier — go through reflection (Step 6-R) and retry on that tier. When the same task fails verification a second time (the re-implementation that would run at loop=2), escalate to the next tier: run `vdgg_task_rollback` to restore the baseline so the higher tier re-implements cleanly, and pass the accumulated `investigation-r*.md` notes to the next tier's prompt (the `failure notes` input in `references/subagent_prompts.md`). `inline` is the last tier and follows the normal flow with no further escalation. If the ladder does not end with `inline`, the last configured tier is treated the same way — its further failures do not escalate; stay on that tier and continue the normal reflection loop.

Review ordering: run the external review (`REVIEW_COMMAND` / `vdgg_review_run`) only after `vdgg_task_gate` verification has passed, so failed cheap-tier attempts never consume external review quota. On review findings (high/medium), the CURRENT tier applies the findings first; if the review rejects the work a second time, escalate one tier (same rollback-and-handoff procedure).

Record keeping: record in `progress.md`, per task, the settling tier and loop count (e.g. `T1: settled at tier 1, loop=0` / `T2: escalated to tier 2, loop=2`). The final completion report must include a one-line-per-task Formation summary in the same form.

## Standard-First Contract

For code changes, Step 0 Constraints must include the following default policy unless the user explicitly overrides it:

- Prefer the target environment's standard features, components, APIs, and patterns.
- Do not add custom UI, custom components, custom state management, custom design systems, custom utilities, or external dependencies unless the need is clear.
- If the standard path is not enough, stop before implementation and report why, alternatives, impact, and whether the work can later return to the standard path.
- Do not silently solve the problem by adding custom implementation or dependencies.

If existing custom implementation is found, record in `investigation.md` whether it could be replaced with standard facilities and why it is or is not being replaced.

## Self-Maintenance Mode

Use this mode only when changing VibesDeGoGo! itself under `skills/vibesdegogo/`.

Rules:

- Fix the target files, purpose, and out-of-scope areas before editing.
- Read only files directly related to the change. Do not re-investigate the whole project.
- Use `rg` and targeted reads. Do not start broad researcher subagents.
- Keep the plan to at most 3 tasks.
- Preserve existing script, hook, and documentation structure.
- Do not add external dependencies.
- Escalate to full flow if hook I/O contracts, state file format, or Step transition contracts change.
- Verify with `bash -n`, `rg` sanity checks, and minimal hook simulation when needed.
- Skip Step 8 deployment.
- Stop only before constraint violations, destructive operations, or external dependency changes.

## Lightweight Mode

Lightweight mode is for small, closed changes in ordinary projects. It shortens ceremony, not discipline.

Use it only when all of these are true:

- The user explicitly asks for lightweight mode, or the agent briefly states why lightweight mode applies before starting.
- Target files, purpose, out-of-scope areas, and verification method are clear at the start.
- Existing standard patterns are enough.
- No dependency or custom implementation is needed.
- The change is small and the direct references/callers can be checked in a limited scope.

Do not use lightweight mode for API contracts, database or migration changes, persistence formats, auth, permissions, security, billing, analytics event names, user data deletion or migration, legal text, high-risk medical or financial text, compatibility decisions, state transition design, dependency additions, broad renames, or cross-module changes.

Minimum flow:

1. Declare target files, purpose, out-of-scope areas, and verification method in 1 to 5 lines.
2. Use `rg` and targeted reads to inspect the change site and direct references.
3. Make the smallest change that follows existing patterns.
4. Run the declared verification. Do not skip verification.
5. If the change will be built, deployed, or committed and `.vdgg-target` configures version files (`VERSION_FILE_*_PATH` / `_KEY`), bump each configured key to a value newer than `HEAD` before building/deploying. This is the only Step 8 obligation lightweight mode keeps; do not skip it just because the rest of Step 8 is omitted.
6. Report only changes, verification result, and residual risk.

Escalate to full flow if tests fail twice, scope expands, specification or compatibility judgment is needed, custom implementation looks necessary, verification is unclear, or the agent is about to proceed on a guess.

## State Layout

Each VibesDeGoGo! session has a unique ID in this format: `YYYYMMDD-HHMM-xxxx`.

```text
.claude/.vdgg-active              current VibesDeGoGo! ID
.claude/.vdgg-state-{id}          state file for that ID
tasks/vdgg/{id}/requirements.md   fixed Goal / Constraints / Acceptance criteria
tasks/vdgg/{id}/investigation.md  Step 3 investigation report
tasks/vdgg/{id}/todo.md           task list
tasks/vdgg/{id}/progress.md       progress and retry notes
```

State files are KEY=VALUE text files with these fields: `step`, `phase`, `loop_count`, `current_task`, `vdgg_id`, and `last_updated`.

See `references/state_helpers.md` for helper details.

## Phases

| phase | Step | Meaning |
|---|---:|---|
| `declare` | 1 | formation declaration |
| `requirements` | 2 | write requirements |
| `investigating` | 3 | deep investigation |
| `planning` | 4 | create plan and task files |
| `task-selected` | 5 | choose one task |
| `implementing` | 6 | implement and write tests |
| `testing` | 7 | verify and run review gate |
| `reflection` | 6-R | investigate failure and prepare one retry |
| `verified` | 7 end | verification complete |
| `progress` | 8 | update progress and request validation |
| `commit` | 9 | commit and optionally push/PR |

## Step Declaration Format

Step 1 uses the formation declaration:

```text
[VibesDeGoGo! Declaration] id=<vdgg_get_id output>
```

Steps 2 and later use this one-line format:

```text
[VibesDeGoGo! Step N Start] step=N, phase=PHASE_NAME, loop=LOOP_COUNT
```

The hooks validate declarations inside Bash command text for state transitions. Use the exact strings above.

## Step 0: Agree On Requirements

Before starting the state machine, agree with the user on:

1. Goal: what state or user value should be achieved.
2. Constraints: what must not change and what boundaries apply.
3. Acceptance criteria: concrete checks that determine completion.

Draft these three items in chat. Ask questions only for ambiguity that cannot be safely resolved. Start Step 1 only after the user clearly accepts the draft.

Step 0 is not mechanically enforced because no state file exists yet.

## Step 0 Mode: Consultation (壁打ち)

When the requirements cannot yet be safely fixed, run Step 0 as a consultation (壁打ち) before drafting Goal / Constraints / Acceptance. Enter this mode when any of these hold: the goal is ambiguous; the work is subjective or creative — docs, naming, copy, design, a handbook, anything an AI can produce where "good" lives in the user's head, not only in code; the change is high-stakes or hard to reverse (public artifacts, contracts); or more than one defensible direction exists. For a clear, mechanical task with one obvious shape, skip this mode and draft the three items directly.

Consultation is a sounding board. It is none of its three failure modes:

- **Not guess-and-go:** do not silently pick one reading and start building.
- **Not option-dumping:** do not hand over a bare list ("A, B, or C?") and make the user do the thinking.
- **Not autonomous-finalize:** do not settle a subjective or scope question for the user behind a closed door.

Loop until the WHAT is agreed:

1. Name the decisions the result actually hinges on — real forks, not pseudo-choices. Raise a few at a time; do not flood.
2. For each, lay out the trade-offs (what each option wins and loses) and give a recommendation with its reasoning. Recommend; do not merely survey.
3. The user decides or redirects. On every subjective or scope question the user is the decider; the agent supplies the thinking, not the verdict.
4. For a genuinely split, high-stakes fork, escalate that one point to a deeper, multi-perspective deliberation: run the MAGI skill if it is installed; if not, get a second opinion another way (a different model, or a structured review). Bring the output back as material — still for the user to decide.

Do not relitigate a settled point, and do not stall: drive toward convergence. When the WHAT is agreed, leave consultation mode and write `requirements.md`. For subjective artifacts, record in Acceptance what "good" was agreed to mean, so completion stays checkable. Then proceed to Step 1.

## Step 0 Helper: Grill Me (optional)

The Consultation loop above is the baseline for resolving ambiguity. Grill Me is an optional third part — a question-driven interrogator that walks the decision tree one branch at a time — that can be slotted in **before** drafting Goal / Constraints / Acceptance, to pre-filter ambiguity through structured waves of questions, each with a recommended answer.

When Grill Me is engaged, Step 0 runs in three layers before drafting:

1. **Shallow consultation** — the baseline loop above raises real forks and gives recommendations.
2. **Grill Me pass** — sequential question waves drive the user through unresolved branches, each question carrying a recommended answer; the user accepts, redirects, or rejects per question.
3. **MAGI escalation** — for any remaining genuinely split, high-stakes fork, step 4 of the Consultation loop still applies (run MAGI if installed, else get a second opinion another way).

Then drafting `requirements.md` proceeds as usual.

Grill Me is a pre-filter, not a replacement for MAGI. Skipping Grill Me is safe because MAGI remains the deeper-deliberation backstop for high-stakes forks.

Control via `.vdgg-target` (`references/target_schema.md`):

- `GRILLME=off` (default): do not run Grill Me. Behavior is unchanged from the Consultation loop and MAGI escalation alone.
- `GRILLME=on`: always run Grill Me at Step 0 before drafting, even for clear-shape tasks.
- `GRILLME=auto`: run Grill Me when any of the Consultation entry conditions hold — the goal is ambiguous; the work is subjective or creative; the change is high-stakes; or more than one defensible direction exists. Same trigger list as Consultation itself, so they fire together.

If the Grill Me skill is not installed, the setting is treated as `off` and Step 0 continues with Consultation. The orchestrating agent invokes the installed Grill Me skill directly; there is no shell helper for this (the same convention as MAGI escalation).

## Step 1: Formation Declaration

Initialize state. Source the state helpers in every Bash command that calls `vdgg_*` functions (shells do not persist between commands). For manual installs the helpers live at `$HOME/.claude/skills/vibesdegogo`; for plugin installs use this skill's base directory as announced when the skill loads:

```bash
VDGG_SKILL_DIR="${VDGG_SKILL_DIR:-$HOME/.claude/skills/vibesdegogo}"
# Plugin install: replace the default above with this skill's announced base directory.
source "$VDGG_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_init
```

For the default `branch-pr` workflow, create a feature branch after `vdgg_state_init` and before any code editing. The branch name MUST describe the change, not the workflow.

Branch name is derived from the Step 0 Goal, not from the VibesDeGoGo! id. Pick a name in the form `{type}/{slug}` where:

- `{type}` is one of `feat`, `fix`, `refactor`, `docs`, `test`, `chore` (same vocabulary as the Step 9 commit type).
- `{slug}` is a short kebab-case summary of the change (3-5 words, lowercase, ASCII, hyphen-separated). Drop articles and filler.
- Examples: `feat/japanese-readme`, `fix/init-portability`, `refactor/state-helpers`.

```bash
WORKFLOW=branch-pr; BASE_BRANCH=""
# Never `source` .vdgg-target: it is a repository-controlled file, and sourcing
# it would execute any code an untrusted repo places there (e.g. WORKFLOW=x with
# a trailing `$(...)`). Read only the needed keys and validate them.
if [ -f "$(pwd)/.vdgg-target" ]; then
    WORKFLOW=$(grep -m1 '^WORKFLOW=' "$(pwd)/.vdgg-target" | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/')
    BASE_BRANCH=$(grep -m1 '^BASE_BRANCH=' "$(pwd)/.vdgg-target" | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/')
    case "$WORKFLOW" in trunk|branch-pr) ;; *) WORKFLOW=branch-pr ;; esac
    # Reject anything that is not a plausible branch name.
    case "$BASE_BRANCH" in ''|*[!A-Za-z0-9._/-]*) BASE_BRANCH="" ;; esac
fi
WORKFLOW=${WORKFLOW:-branch-pr}
if [ "${WORKFLOW:-branch-pr}" != "trunk" ]; then
    if [ -z "${BASE_BRANCH:-}" ]; then
        BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
        BASE_BRANCH=${BASE_BRANCH:-main}
    fi
    CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    # Stay on the current branch if it's already a non-base feature branch
    # (e.g. continuing or bundling another task onto the same branch).
    if [ "$CUR" = "$BASE_BRANCH" ]; then
        # On base branch -> create a new feature branch. The agent MUST pick
        # the {type}/{slug} name from the Step 0 Goal; this snippet does not
        # auto-generate one. Do NOT use `vibesdegogo/` as a prefix — that
        # names the workflow, not the change, and is useless to anyone
        # reading the PR list.
        echo "vdgg: on base branch ($BASE_BRANCH). Run:" >&2
        echo "  git checkout -b <type>/<kebab-slug-derived-from-Step-0-Goal>" >&2
        echo "Types: feat | fix | refactor | docs | test | chore" >&2
    fi
fi
```

If the current branch is already a feature branch, stay on it when this session continues or bundles work onto that change; create a new nested `{type}/{slug}` branch only when the session starts a genuinely separate change. The Step 1 block runs once per session because `vdgg_state_init` refuses a second initialization.

Then output the Step 1 declaration from `references/output_formats.md`.

## Step 2: Write Requirements

Write Step 0's agreed content to `tasks/vdgg/{id}/requirements.md` with exactly these headings:

```markdown
## Goal
...

## Constraints
...

## Acceptance criteria
...
```

Then advance:

```bash
# [VibesDeGoGo! Step 2 Start] step=2, phase=requirements, loop=0
vdgg_state_advance 2 requirements
```

The hook blocks Step 3 until `requirements.md` exists.

## Step 3: Deep Investigation

Investigate existing code related to the requirements and write `tasks/vdgg/{id}/investigation.md`.

Investigation rules:

- Do not guess. Read actual code.
- Do not stop at a single file. Trace callers and impact.
- Consider recent git history, lessons, and project notes when relevant.
- Mark unknowns explicitly.

Then advance:

```bash
# [VibesDeGoGo! Step 3 Start] step=3, phase=investigating, loop=0
vdgg_state_advance 3 investigating
```

Use subagents only when parallel investigation clearly helps.

## Step 4: Planning

Use `investigation.md` to create `tasks/vdgg/{id}/todo.md` and `tasks/vdgg/{id}/progress.md`.

Task sizing:

- One or two methods and one to three files: keep as one task.
- Four or more files, or independent changes: split tasks.
- Ask whether one implementation cycle can reasonably finish it.

Then advance:

```bash
# [VibesDeGoGo! Step 4 Start] step=4, phase=planning, loop=0
vdgg_state_advance 4 planning
```

## Step 5: Select One Task

Choose one task from `todo.md`. The task must be small enough to complete implementation, tests, and verification in one Step 6 to Step 8 loop; split it before Step 6 if it is not. Declare an allowlist of every implementation/test/documentation file this task is allowed to change; keep it narrow and task-specific. Task notes under `tasks/vdgg/{id}/` never need allowlisting. If the task changes an interface, enum, type, or signature, also include the test file(s) that assert it in the allowlist, so a needed test update does not hit the re-arm wall mid-task.

```bash
# [VibesDeGoGo! Step 5 Start] step=5, phase=task-selected, loop=0
vdgg_state_advance 5 task-selected
vdgg_task_begin "T1: title" path/to/file1 path/to/file2
```

`vdgg_task_begin` records the task in state, snapshots a baseline of the allowlisted files, and arms the task gate. The hook blocks implementation edits until it has run.

## Step 6: Implement

Implement the selected task and write tests where appropriate.

```bash
# [VibesDeGoGo! Step 6 Start] step=6, phase=implementing, loop=0
vdgg_state_advance 6 implementing
```

Do not run tests in `implementing`; the hook blocks test commands until Step 7. Edit/Write outside the task allowlist is blocked. `vdgg_task_begin` can only (re)arm at Step 5 — the state machine rejects it from `implementing`/`reflection` (6 -> 5 is not a legal transition). If the scope legitimately grew mid-task, either narrow the change to fit the current allowlist, or finish this task through Step 8 and select the extra scope as a new task at Step 5 (8 -> 5) with the right allowlist.

## Step 7: Verify

Before running verification, state the concrete checks you will run. Scale the count to the change's surface — roughly 1 to 3 for a small, localized change, more when it spans multiple files or touches a contract; do not stop at three if the surface is larger. At least one check must be one that would FAIL if the change were wrong — a boundary, error, or regression case, not only a happy-path confirmation. Then run them through the task gate, which re-checks the allowlist and records a pass only when the command succeeds. Pass the command as separate shell words, for example `vdgg_task_gate npm test`, or use `vdgg_task_gate bash -lc 'set -o pipefail; command with pipes'`.

A verification command with a pipe that omits `set -o pipefail` can hide a failure in an earlier pipeline stage behind a successful final stage, so the gate records a false pass.

```bash
# [VibesDeGoGo! Step 7 Start] step=7, phase=testing, loop=0
vdgg_state_advance 7 testing
vdgg_task_gate <verification-command> [args...]
```

After all checks pass, run the `simplify` skill as a quality gate. The PostToolUse hook records a sentinel file:

```text
.claude/.vdgg-simplify-sentinel-{vdgg_id}-{loop_count}
```

Outcomes:

- Sentinel missing: `vdgg_state_advance 7 verified` is blocked.
- `modified=0`: verified transition is allowed.
- `modified=1`: verified transition is blocked; go through reflection and re-test.

When a task allowlist is active, `vdgg_state_advance 7 verified` is also blocked until `vdgg_task_gate` has passed for the current loop. If verification fails and the work must be redone from the baseline, `vdgg_task_rollback` reverts the allowlisted changes.

For environments that cannot use the `simplify` skill, or when `.vdgg-target` configures an external reviewer, run the review through `vdgg_review_run`:

```bash
vdgg_review_run                      # runs REVIEW_COMMAND from .vdgg-target
vdgg_review_run <command> [args...]  # runs an explicit review command
```

It writes the review sentinel only when the command exits 0. A purely manual review can still be recorded with `vdgg_state_mark_reviewed`. The verified gate accepts either sentinel — simplify or explicit review — and both are subject to the same rule: implementation edits after the review flip `modified=1` and route through reflection. Prefer the simplify skill when it is available; prefer a different vendor than the implementing model for external review. For code that ships to other machines or handles user data, the review prompt must include a security perspective (injection, secrets exposure, unsafe file/network/exec operations) — simplify does not cover security. Sentinel files cannot be written directly; the hooks block Edit/Write/Bash writes to `.claude/.vdgg-*` paths.

For a **subjective artifact** (docs, copy, naming, design — where quality is a judgment, not something a test can decide), the review gate can be the `MAGI` skill when it is installed: run MAGI as the review and record the gate with `vdgg_state_mark_reviewed` only when MAGI passes. If MAGI is not installed, skip it and use the standard `simplify`/review gate above. MAGI judges desirability, not code correctness — correctness still rides on tests and `simplify`.

### simplify subagent consolidation

The simplify skill's default Phase 1 (5 parallel angle finders, up to 8 candidates each) is the right call when ANY of these hold:

- This is the FIRST simplify round (`loop_count=0`) on this feature.
- The diff is large (>500 LOC), spans multiple files/layers, or touches contracts (API, persistence, concurrency, auth, security).
- An unresolved high or medium finding from the previous round still applies to code being changed in this round (recall still matters there).

You MAY collapse the 5 angles into ONE comprehensive agent (or do the review inline without a subagent) when ALL of these hold:

- This is a follow-up round (`loop_count` ≥ 1).
- No unresolved high or medium finding from the previous round still applies to code being changed in this round.
- The diff in this round is small (≤200 LOC) AND localized (1–2 files, 1–2 functions).
- No concurrency, pasteboard, pointer, lifecycle, or contract surface is touched.

When collapsing, state the reason in the user-facing text (e.g. "collapsing to 1 agent because loop=3 and no unresolved high/medium finding touches this round's diff"). Do not collapse silently to save tokens or time.

### simplify findings: severity-based response

After simplify returns findings, classify each one and decide before editing:

- **high**: correctness bug, data loss, race condition, security, contract regression.
- **medium**: real bug with a narrow trigger, or a design that will break under reasonable use.
- **low**: cosmetic, stale doc, log message wording, naming, dead branch, style.

Response:

- Any **high or medium** finding → fix it in implementation files. The sentinel will flip to `modified=1`, routing you through reflection — this is correct.
- **All findings are low (or `[]`)** → DO NOT edit implementation files. Instead, write the findings to `tasks/vdgg/{id}/followup-r{loop_count}.md` and advance directly to `verified`. Low items become candidates for a separate followup PR.

This stops convergence-loops on cosmetic findings while keeping the hook discipline intact: any implementation edit during testing still flips `modified=1`, so there is no escape hatch for high/medium.

When listing findings, always assign an explicit `severity` field per finding so the classification is auditable. If simplify's own output omits severity, classify each finding yourself before deciding the response.

After successful verification and simplify review:

```bash
# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0
vdgg_state_advance 7 verified
```

If testing fails, or simplify changed code, go to reflection:

```bash
# [VibesDeGoGo! Step 6 Start] step=6, phase=reflection, loop=<same loop>
vdgg_state_advance 6 reflection
```

## Step 6-R: Reflection

Reflection is mandatory after failed verification or simplify changes.

At the beginning of reflection, start a researcher subagent for root-cause investigation unless self-maintenance mode explicitly allows skipping it for a mechanical typo/path issue.

Lightweight branch: when reflection was triggered by review/simplify findings rather than a test failure, skip the researcher subagent — write `investigation-r{loop_count}.md` directly from the review findings (classify each finding, then state the one fix) instead. A test-failure-triggered reflection still requires the researcher subagent as above. Either way, `investigation-r{loop_count}.md` and `progress.md` must still be written; the hook checks apply the same regardless of which path produced them.

The researcher (or, on the lightweight branch, the agent itself) must write:

```text
tasks/vdgg/{id}/investigation-r{loop_count}.md
```

Then append four items to `progress.md`:

1. Root Cause Investigation.
2. Pattern Analysis.
3. Hypothesis: exactly one hypothesis.
4. Implementation plan: exactly one fix.

Forbidden in reflection:

- skipping root-cause investigation,
- trying multiple fixes at once,
- patching symptoms without understanding cause,
- going directly to `verified`,
- editing implementation files.

Return to implementation with loop increment:

```bash
# [VibesDeGoGo! Step 6 Start] step=6, phase=implementing, loop=<next loop>
vdgg_state_loop 6 implementing
```

The hook checks that `progress.md` and `investigation-r{loop_count}.md` were updated during reflection.

If the revised hypothesis needs files outside the current allowlist, do not try to widen the allowlist in place — `vdgg_task_begin` cannot re-arm outside Step 5 and will fail loudly. Adapt the fix to the current allowlist (e.g. downgrade an optional cleanup to a followup note), or complete/close this task and take the wider scope as a new task via Step 8 -> Step 5. The task gate must pass again for the new loop before `verified`.

## Step 8: Progress And Validation Request

Advance:

```bash
# [VibesDeGoGo! Step 8 Start] step=8, phase=progress, loop=0
vdgg_state_advance 8 progress
```

Read `.vdgg-target` if it exists. If version files are configured, update their configured keys and make the new value newer than `HEAD`.

Ask the user for validation according to `DEPLOY_COMMAND`, `DEPLOY_TARGET`, and `VERIFY_TYPE`. If no target is configured, ask how they want to validate.

Update `progress.md` and check whether all tasks are complete:

- unfinished tasks: go back to Step 5,
- all tasks complete: continue to Step 9.

## Step 9: Commit

Advance:

```bash
# [VibesDeGoGo! Step 9 Start] step=9, phase=commit, loop=0
vdgg_state_advance 9 commit
```

Commit on the feature branch. Include version files if Step 8 changed them.

Commit message format:

```text
{type}: {summary}
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.

### branch-pr workflow

Default behavior:

1. push the feature branch,
2. create a PR,
3. report the PR URL,
4. stop for human merge approval.

Do not merge automatically just because CI is green.

### trunk workflow

Only when `.vdgg-target` explicitly sets `WORKFLOW=trunk`, commit directly on the current branch. Push only when `AUTO_PUSH=true`.

## Clear State And Finish

After PR creation or trunk commit/push decision:

```bash
vdgg_state_clear
```

Then provide a friendly completion report: what finished, what was verified, what the user needs to do next, build/version numbers if any, and short technical details.

## Stop Conditions

Do not stop for progress confirmation. Do stop before:

- violating Step 0 constraints,
- adding or changing dependencies,
- changing API, persistence, auth, permissions, security, billing, analytics, or user data contracts,
- destructive operations,
- broad renames,
- inability to satisfy or verify acceptance criteria.

When stopping intentionally, include `[Intentional Stop]` in assistant text and explain why.

## Checklist

- [ ] Step 0: agree on Goal / Constraints / Acceptance criteria.
- [ ] Step 1: initialize state and declare formation.
- [ ] Step 2: write `requirements.md`.
- [ ] Step 3: write `investigation.md`.
- [ ] Step 4: write `todo.md` and `progress.md`.
- [ ] Step 5: select one task and record `current_task`.
- [ ] Step 6: implement.
- [ ] Step 7: verify, run simplify, and only then mark verified.
- [ ] Step 6-R: if needed, investigate failure, record one hypothesis, and retry.
- [ ] Step 8: update progress/version and request validation.
- [ ] Step 9: commit, push/PR according to workflow, clear state, and report.
