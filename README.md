# VibesDeGoGo! for Claude Code

**Make Claude Code finish the job — without cutting corners.**

Claude Code is clever, but it doesn't always go the distance: it loses steam before the work is truly done, jumps ahead over steps it should have taken, and cuts corners that come back later as a nasty reversal. You think it's finished — then the whole thing unravels.

VibesDeGoGo! for Claude Code answers with one thing: **enforcement.** It's a state-and-hook workflow that won't let the agent skip the boring-but-load-bearing parts — requirements, investigation, one task at a time, verification — and physically blocks the moves that cause the unravel.

One asymmetry runs the whole thing:

- **Don't stop to ask permission** — no "can I continue?", it keeps moving.
- **Do stop before a constraint violation** — a new dependency, touching auth / persistence / billing / security, a destructive op, or jumping a step: it halts and asks first.

This isn't a polite request in a prompt — it's enforced by hooks (`PreToolUse` / `PostToolUse` / `Stop`) plus a state file, with a task gate that cross-checks the actual file changes against the allowlist you declared. Try to skip a step or bend the workflow and the hooks stop the tool call cold. (Honest caveat: treat this as strong rails plus an audit trail, not a sandbox or a proof of correctness.)

Just bash + jq. No SaaS, no account, no API key, no telemetry. MIT, and free.

> Where this comes from: I don't write code — I have never written or read a line of it. The tools in this repo are real, tested, and open source anyway, because the rails do the reading I can't: every step verified, tests must pass, nothing ships unreviewed. That's the point — VibesDeGoGo! is how someone who can't code keeps an agent honest.

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

## Test

```bash
bash tests/run-all.sh
```

## Optional: MAGI

If you also install **MAGI** (a small open-source 3-persona deliberation skill), VibesDeGoGo! uses it at two points — and silently skips it if you don't: **Step 0** to deliberate a genuinely split, high-stakes decision (it hands back material; you still decide), and **Step 7** as the review gate for subjective artifacts (docs, copy, design). MAGI judges desirability, not code correctness. → https://github.com/tmknzz/MAGI

## Status

This repository is the Claude Code-focused edition. The Codex edition lives separately at [VibesDeGoGo-for-Codex](https://github.com/tmknzz/VibesDeGoGo-for-Codex).

## Support

It's free, and it stays free. If it ever saves you a weekend, a coffee is welcome — never expected.
