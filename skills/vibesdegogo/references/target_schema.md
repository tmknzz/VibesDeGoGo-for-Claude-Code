# VibesDeGoGo! Reference: .vdgg-target Schema

`.vdgg-target` is an optional project-root file. It is a Bash-sourceable KEY=VALUE file that tells Step 8 and Step 9 how to update versions, validate changes, and push work.

## Fields

```bash
# Version files. Multiple entries are allowed.
VERSION_FILE_1_PATH=<path from project root>
VERSION_FILE_1_KEY=<key in that file>
VERSION_FILE_2_PATH=...
VERSION_FILE_2_KEY=...

# Human guidance for version generation.
VERSION_FORMAT="<description>"
VERSION_EXAMPLE="<example>"

# Validation/deployment guidance.
DEPLOY_COMMAND="<slash command or manual procedure>"
DEPLOY_TARGET="<device, local app, dev server, etc.>"
VERIFY_TYPE="<device preview, browser check, curl check, etc.>"

# Workflow. Default is branch-pr.
WORKFLOW=branch-pr

# Base branch for PRs. Optional; default is origin default branch, then main.
BASE_BRANCH=main

# Only used when WORKFLOW=trunk.
AUTO_PUSH=false

# Extra test command regex blocked during implementing phase.
TEST_COMMAND_PATTERN="<extended regex>"

# Optional external review gate for Step 7. The command must be read-only
# (findings only, no edits) and exit 0 only when the review passes. Run it
# with `vdgg_review_run` (no arguments), which writes the review sentinel on
# success. Use a different vendor than the implementing model when possible.
REVIEW_COMMAND="codex exec --sandbox read-only 'review the working tree diff; exit non-zero on blocking findings'"

# Optional delegated step executors. When set, the agent runs the command for
# that step instead of doing the step inline, then validates the artifacts
# (file exists + required headings) before advancing. Placeholders the agent
# substitutes: {TASKS_DIR}, {REQUIREMENTS}, {INVESTIGATION}, {TODO}, {TASK}.
# Step 6 delegation requires an active task allowlist; out-of-allowlist edits
# by the executor are caught by vdgg_task_gate.
STEP3_EXECUTOR_COMMAND="qwen -p '<investigation prompt from subagent_prompts.md with paths filled in>'"
STEP4_EXECUTOR_COMMAND=""
STEP6_EXECUTOR_COMMAND=""
```

## Example: iOS Or macOS App

```bash
VERSION_FILE_1_PATH=project.yml
VERSION_FILE_1_KEY=CURRENT_PROJECT_VERSION
VERSION_FORMAT="yyyymmdd plus two-letter sequence, starting at AA"
VERSION_EXAMPLE="20260527AA"
DEPLOY_COMMAND="/deploy-device"
DEPLOY_TARGET="physical device"
VERIFY_TYPE="device preview"
AUTO_PUSH=false
```

## Example: Web Backend Without Version Files

```bash
DEPLOY_COMMAND="npm run dev"
DEPLOY_TARGET="dev server"
VERIFY_TYPE="browser check"
AUTO_PUSH=false
```

## Workflow Behavior

`branch-pr` is the default:

1. Step 1 creates a feature branch named from the Step 0 Goal, in `{type}/{slug}` form (e.g., `feat/japanese-readme`). See Step 1 in `SKILL.md`.
2. Step 9 commits there.
3. Step 9 pushes the branch and creates a PR.
4. The agent stops. A human decides whether to merge.

`AUTO_PUSH` is ignored in `branch-pr` because pushing the feature branch is required to create a PR.

`trunk` is opt-in:

1. Work stays on the current branch.
2. Step 9 commits there.
3. Step 9 pushes only when `AUTO_PUSH=true`.
