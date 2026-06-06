**English** | [日本語](CONTRIBUTING.ja.md)

# Contributing

Thanks for improving VibesDeGoGo!. This project is intentionally small: shell
scripts, Markdown docs, and no test framework dependency.

## Requirements

- `bash`
- `jq`
- standard Unix tools: `date`, `tr`, `grep`, `sed`, `find`, `awk`

On macOS, install `jq` with:

```bash
brew install jq
```

## Repository Layout

- `skills/vibesdegogo/`: Claude Code skill.
- `skills/vibesdegogo/scripts/`: Claude Code hook and state helpers.
- `skills/vibesdegogo/references/`: workflow references.
- `tests/`: zero-dependency smoke tests.

## Running Tests

Run the full smoke suite:

```bash
bash tests/run-all.sh
```

Run one file:

```bash
bash tests/test-state.sh
bash tests/test-hook-pretool.sh
bash tests/test-hook-posttool.sh
bash tests/test-hook-stop.sh
```

Run syntax checks when editing scripts:

```bash
bash -n skills/vibesdegogo/scripts/*.sh
```

## Editing Hook Scripts

Do not use broad `sed -i` rewrites for hook or state script comments. A previous
rename damaged meaningful comments by replacing them with a generic placeholder.
When changing names or comments:

- inspect the diff by file;
- keep behavior changes separate from comment-only changes;
- keep the Claude Code hook JSON contract aligned with the setup docs.

## Commit Style

Use:

```text
{type}: {summary}
```

Common types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.

## Pull Requests

Before opening a PR:

- run `bash tests/run-all.sh`;
- run syntax checks for changed script sets;
- note whether the change affects hooks, state helpers, or workflow docs.

## Versioning

The `version` field inside a skill file tracks the workflow specification for
that edition. Repository releases use separate SemVer tags, starting at `0.1.0`
for the first public OSS release.
