# Global preferences

## Project setup

- When working in a project (or subdirectory) that has no `CLAUDE.md` file, remind me that one is missing so I can decide whether to create one.

## Git / PRs

- Never squash-merge PRs. Preserve the individual commit history — use a regular merge commit (or rebase) instead. When running `gh pr merge`, do not pass `--squash`.

## Docs / plans

- When a feature is done, keep the spec/design docs around but remove the implementation plan (e.g. delete files under a `plans/` dir while leaving `specs/`). Do this as part of finishing the work.

## Troubleshooting

- If GitHub operations fail (e.g. `gh` commands, pushes, API calls, auth errors), flag a stale/bad `GITHUB_TOKEN` env var as the likely cause. A fresh token can be obtained from the gh CLI (`gh auth token`).

## Shell

- `sed` is aliased to GNU `gsed` **interactively only** — the alias does not load in a non-interactive shell, so `sed -i <expr>` there hits BSD sed and fails ("bad flag in substitute command"). Call `gsed -i <expr>` explicitly, or use a `python3` heredoc for multi-file edits. Use `/usr/bin/sed` for BSD syntax.
