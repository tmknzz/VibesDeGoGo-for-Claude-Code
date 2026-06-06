# VibesDeGoGo! for Claude Code

VibesDeGoGo! for Claude Code is a state-and-hook workflow that keeps Claude
Code moving until coding work is actually done, while stopping before
constraint violations.

It exists because AI coding agents can skip the boring parts: requirements,
investigation, verification, and clear handoff. VibesDeGoGo! turns those parts
into rails.

## Core Flow

1. Agree on Goal / Constraints / Acceptance criteria.
2. Write `tasks/vdgg/{id}/requirements.md`.
3. Investigate the codebase and write `investigation.md`.
4. Create `todo.md` and `progress.md`.
5. Implement one bounded task at a time.
6. Verify with concrete checks.
7. Run the simplify gate.
8. Update progress and ask for validation when needed.
9. Commit and create a PR for the default `branch-pr` workflow.

## Layout

```text
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

## Test

```bash
bash tests/run-all.sh
```

## Status

This repository is the Claude Code-focused edition. The Codex edition lives
separately as `VibesDeGoGo-for-Codex`.
