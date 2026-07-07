# VibesDeGoGo! for Claude Code

A state-and-hook workflow for Claude Code. It keeps the agent moving through requirements, investigation, implementation, verification, and commit, but stops it before skipped steps, skipped verification, or scope drift.

One asymmetry runs the whole thing:

- Don't stop to ask permission — no "can I continue?", it keeps moving.
- Do stop before a constraint violation — a new dependency, touching auth / persistence / billing / security, a destructive op, or jumping a step: it halts and asks first.

The rules are enforced by hooks (`PreToolUse` / `PostToolUse` / `Stop`) plus a state file, not by prompt text, and a task gate cross-checks the actual file changes against the allowlist you declared. The hooks are a guardrail, not a sandbox — strong rails plus an audit trail, not proof of correctness.

bash + jq. No account, keys, or telemetry. MIT.

## Core Flow

1. Agree on Goal / Constraints / Acceptance criteria.
2. Write `tasks/vdgg/{id}/requirements.md`.
3. Investigate the codebase and write `investigation.md`.
4. Create `todo.md` and `progress.md`.
5. Implement one bounded task at a time.
6. Verify with concrete checks.
7. Pass the review gate (simplify or an external review).
8. Update progress and ask for validation when needed.
9. Commit, and for the default `branch-pr` workflow, create a PR and stop.
   (A PR — pull request — is GitHub's "review this change" page. Nothing
   reaches the main code until you approve the merge.)

## Layout

```text
.claude-plugin/
  plugin.json
  marketplace.json
hooks/
  hooks.json
skills/vibesdegogo/
  SKILL.md
  scripts/
    vdgg-state.sh
    vdgg-hook-pretool.sh
    vdgg-hook-posttool.sh
    vdgg-hook-stop.sh
  references/
    setup.md
    output_formats.md
    target_schema.md
    hook_rules.md
    state_helpers.md
    subagent_prompts.md
```

## Install

### As a plugin (recommended)

Inside Claude Code, run:

```text
/plugin marketplace add tmknzz/VibesDeGoGo-for-Claude-Code
/plugin install vibesdegogo@vibesdegogo
```

This registers the skill and activates the hooks automatically.

### Manual install

Copy the skill folder into Claude Code's skills directory:

```bash
mkdir -p "$HOME/.claude/skills"
cp -R skills/vibesdegogo "$HOME/.claude/skills/vibesdegogo"
```

Then register the hooks shown in:

```text
skills/vibesdegogo/references/setup.md
```

`jq` is required because the hooks parse Claude Code hook JSON:

```bash
brew install jq               # macOS
sudo apt-get install jq       # Debian / Ubuntu / WSL
apk add jq                    # Alpine
sudo dnf install jq           # Fedora / RHEL
```

Without `jq`, the hooks do nothing and stay out of the way in repositories
where no VibesDeGoGo! session is running.

## Test

```bash
bash tests/run-all.sh
```

## Optional: MAGI

If you also install **MAGI** (a small open-source 3-persona deliberation skill), VibesDeGoGo! uses it at two points — and silently skips it if you don't: **Step 0** to deliberate a genuinely split, high-stakes decision (it hands back material; you still decide), and **Step 7** as the review gate for subjective artifacts (docs, copy, design). MAGI judges desirability, not code correctness. → https://github.com/tmknzz/MAGI

## Status

This repository is the Claude Code-focused edition. The Codex edition lives separately at [VibesDeGoGo-for-Codex](https://github.com/tmknzz/VibesDeGoGo-for-Codex).