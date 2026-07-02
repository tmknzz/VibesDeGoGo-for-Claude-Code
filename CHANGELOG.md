# Changelog

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

## [Unreleased]

### Added

- Step 7 now requires at least one falsifying verification check (boundary/error/regression) and scales the check count to the change surface instead of capping at three.
- Initial Claude-Code-only split from VibesDeGoGo!.
- Claude Code skill, hook scripts, references, and smoke tests.
- REVIEW_COMMAND guidance now recommends a security perspective for publicly shipped code, with an updated example; simplify explicitly does not cover security.
