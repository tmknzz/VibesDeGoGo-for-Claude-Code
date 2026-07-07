# Changelog

## [Unreleased]

## [0.4.0] - 2026-07-08

### Added

- Step 0 consultation mode (wall-bounce) with an escalation trigger into MAGI for ambiguous or high-risk requirements.
- Step 0 now integrates GrillMe, a question-driven pre-filter (`GRILLME=on/off/auto`, default off) that runs before MAGI.
- Formation (executor tiers): optional `STEP6_EXECUTOR_TIERS` in `.vdgg-target` declares a cheapest-first executor ladder for Step 6, escalating automatically on repeated failure. Unset means unchanged behavior. Claude Code edition only — the Codex edition has no delegated executor mechanism.
- Step 7 now requires at least one falsifying verification check (boundary/error/regression) and scales the check count to the change surface instead of capping at three.
- REVIEW_COMMAND guidance now recommends a security perspective for publicly shipped code, with an updated example; simplify explicitly does not cover security.
- `VDGG_REQUIRED` entry gate: mechanically rejects edits/commits from unarmed sessions.
- Step 8 followup sweep: a loop that reclaims deferred low-severity findings instead of leaving them stranded.
- Step reporting: `STEP_REPORT=quiet` and a Delegate declaration line make the delegated-executor model and chat output controllable.
- Initial Claude-Code-only split from VibesDeGoGo!.
- Claude Code skill, hook scripts, references, and smoke tests.
- Docs: README repositioned to a plain, fact-based description with a new "Optional: MAGI" section; English README synced to the Japanese version (review-gate wording, PR explainer, jq-fallback note).

### Changed

- Operational tuning from dogfooding (commit 4f7dcbd): verification-gate pipefail guidance, the simplify full-panel-vs-collapse criterion narrowed to unresolved high/medium findings that still apply to this round's changed code, a lightweight reflection branch for review-triggered retries, allowlist companion-test guidance, and clearer stop messaging.

### Fixed

- `vdgg_task_begin` now rejects re-arming from outside Step 5, before any side effect can occur.
- `_vdgg_mtime` hardened for correct behavior on GNU/Linux, with a reflection regression test.
- zsh PATH safety when sourcing the helpers (`local path` no longer empties `$PATH`), the task-notes exemption scoped to the active session id, and rollback fixed to use the stored task base ref across reflection retries.

### Security

- Sidecar guard rewritten with segment splitting and a whitelist, closing forgery/RCE paths.
- Unknown-phase requests no longer wipe all gates; phases are enumerated and the pretool hook defaults to deny.
- `.vdgg-target` sourcing in SKILL.md replaced with safe extraction, closing an RCE path (P0-1).
- `.vdgg-target` is now write-protected, closing a gate-forgery path via a self-authored REVIEW_COMMAND (P0-2).
- NotebookEdit and other unknown tools can no longer bypass the gate (P1-CC-2).

## [0.3.0] - 2026-06-11

### Added

- Plugin packaging: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `hooks/hooks.json` — installing the plugin registers the skill and activates the hooks automatically.
- Task gate (ported from the Codex edition, with fixes): `vdgg_task_begin` / `vdgg_task_gate` / `vdgg_task_rollback` / `vdgg_task_changed_files` / `vdgg_task_check_allowlist`. The pretool hook enforces the task allowlist during implementing/testing and requires a task-gate pass before `verified`. Task notes under `tasks/vdgg/{id}/` are exempt.
- External review gate: `vdgg_review_run` runs `REVIEW_COMMAND` from `.vdgg-target` (or an explicit command) and writes the review sentinel only on success. The verified gate now accepts the simplify sentinel OR the review sentinel.
- Delegated step executors (documented contract): `STEP3/4/6_EXECUTOR_COMMAND` in `.vdgg-target`; subagent prompts double as executor prompt templates.
- `.gitignore` self-management: `vdgg_state_init` appends a `.claude/.vdgg-*` ignore block (marker-guarded, idempotent).
- Operational guidance ported from v1.7.x: simplify subagent consolidation rules, severity-based findings response (low-only findings go to `followup-r{loop}.md`), lightweight-mode version-bump obligation, goal-based branch naming with stay-on-feature-branch behavior.
- CI: GitHub Actions workflow running syntax checks and the test suite on ubuntu and macos.
- Japanese README (`README.ja.md`).
- Tests: task-gate suite, plugin-manifest suite, review-sentinel/forgery/jq-fallback/8-to-5 cases.

### Changed

- State file gains `task_allowlist_file` and `task_base_ref` fields; `vdgg_state_write` accepts them as optional args 5/6 (omit = preserve, `-` = clear).
- The 8→5 transition clears the previous task's allowlist/baseline, so `vdgg_task_begin` is mechanically required for every task. **Behavior change:** Edit/Write during implementing/testing is now blocked until `vdgg_task_begin` declares an allowlist.
- Sidecar write-protection generalized: Edit/Write/Bash writes to any `.claude/.vdgg-*` path are blocked (sentinel forgery closed).
- `vdgg_state_mark_reviewed` writes `modified=0`/`modified_files=` (same sentinel schema as the simplify sentinel; Codex-edition parity).
- jq-missing behavior: hooks now stay out of the way when no VDGG session is active in the repository; active sessions keep failing closed with install hints.

### Removed

- Dead `.vdgg-step-block-*` cleanup remnants and the dead `*/${TASKS_DIR}/*` glob alternatives.
