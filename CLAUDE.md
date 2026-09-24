# Global preferences

## Project setup

- Check for applicable project instructions, including those inherited from parent directories. Use `AGENTS.md`, falling back to `CLAUDE.md` if absent. If neither applies, remind me so I can decide whether to create one.
- npm is the default package manager, but an existing project's convention wins — check the lockfile before running anything.
- Expect lint, typecheck and test scripts in `package.json`; use them to verify work rather than inventing commands. If one is missing, tell me instead of working around it.

## Code style

- Keep comments short, and skip them where the code already makes the intent clear — a comment should explain *why*, not restate the line below it.

## TypeScript

- Explicit, strict types. Never `any` — use `unknown` plus narrowing when the type genuinely isn't known.
- In new code, import zod as a namespace — `import * as z from 'zod'` — not `import { z } from 'zod'`; it's tree-shaking friendly, so bundlers can drop the unused parts. Leave existing imports alone.
- Always validate data at a runtime boundary — user input, other systems, integrations, the database, env, parsed files — with zod. A hand-written type on unvalidated data is a lie the compiler can't catch; parse it so the type is earned.
- Derive types from the zod schema with `z.infer` rather than declaring the schema and the type separately — one source of truth, no drift.
- For object schemas, infer to an interface — `interface User extends z.infer<typeof userSchema> {}` — not a type alias. Better error messages, and it stays declaration-mergeable/extendable. Falls back to a type alias where TS won't let an interface extend the inferred type — unions, intersections (`.and()`), index signatures, `z.record`.
- In new code, model failure in the return type — a union or discriminated union (e.g. `{ ok: true, value } | { ok: false, error }`), or zod's `safeParse` — rather than throwing. Errors then show up in the types and the compiler forces the caller to handle them, instead of hiding in a `throw` no signature mentions. In a codebase that already throws, match it — one consistent convention beats a better one applied halfway.

## Git / PRs

- I often edit files in the same repo while you work. Inspect existing staged changes before staging explicit paths (`git add <path> …`), never `git add -A`. If we edited the same file, stage only your intended hunks. Review the staged diff before committing; keep unrelated edits out of your commit and preserve my staging choices.
- When a PR review comment is handled (Copilot's included), reply on that thread with what changed and the commit sha, then resolve it. Replying is `gh api repos/<o>/<r>/pulls/<n>/comments/<id>/replies`; resolving is GraphQL only — `resolveReviewThread` with the thread id from `pullRequest.reviewThreads`, which REST cannot do.
- Never squash-merge PRs. Preserve the individual commit history — use a regular merge commit (or rebase) instead. When running `gh pr merge`, do not pass `--squash`.

## Worktrees

- Don't use git worktrees (including any native worktree tool) for implementation work — work directly on a branch in the existing checkout instead. Only use a worktree when I explicitly ask for one.

## Docs / plans

- When a feature is done, keep its spec/design docs but delete only that feature's completed implementation plan. Preserve plans for unrelated or unfinished work. Do this as part of finishing the work.

## Dev servers / processes

- Never kill dev servers by name pattern (`pkill -f next` and friends) — I run several projects at once and it takes them all down. Find the listening process with `lsof -nP -iTCP:<port> -sTCP:LISTEN`, verify it belongs to the intended server, then kill that specific PID.

## Troubleshooting

- For GitHub authentication failures, check for stale/bad `GH_TOKEN` or `GITHUB_TOKEN` overrides; `GH_TOKEN` takes precedence. Check stored credentials with `env -u GH_TOKEN -u GITHUB_TOKEN gh auth status`. `gh auth token` retrieves the current token, not a fresh one, and can return the same bad override. Do not print tokens in tool output. Diagnose other GitHub failures from their actual errors.

## Shell

- Avoid special shell variables as scratch variables; use task-specific names. In zsh, `status` is read-only, and assigning to `path` changes `PATH`, potentially breaking command lookup. Other special variables such as `argv` and `pipestatus` also have shell-defined meanings.
- zsh expands a leading `=` in a word (`=cmd` → command path), so `echo ===` fails with `(eval):1: == not found`. Quote separators: `echo "---"`.
- `grep`'s `--include`/`--exclude` globs must be quoted (`--include='*.ts'`). Unquoted, zsh tries to expand them and the command dies with `(eval):1: no matches found: --include=*.ts`.
- A heredoc after a pipe feeds the **last** command in the pipeline: `gh pr create --body-file - 2>&1 | tail -3 <<'BODY'` gives the body to `tail`, leaving `gh` waiting on stdin until it times out. Write the body to a file and pass its path.
- `sed` is aliased to GNU `gsed` **interactively only** — the alias does not load in a non-interactive shell, so `sed -i <expr>` there hits BSD sed and fails ("bad flag in substitute command"). Call `gsed -i <expr>` explicitly, or use a `python3` heredoc for multi-file edits. Use `/usr/bin/sed` for BSD syntax.
- An **unquoted** heredoc (`python3 - <<PY`) command-substitutes backticks in its body, so an edit script containing a markdown `` `snippet` `` silently loses it or dies with "command not found". Always quote the delimiter: `<<'PY'`.
- A `\u0000`-style escape written inside a heredoc becomes a **real control character** in the tool call, and the Bash tool refuses the whole command ("command contains control characters"). Use the Write tool for that file, or build the character in code (`String.fromCharCode(0)`).
- Neither `timeout` nor `gtimeout` is installed on this machine (`command not found`), so a command needing a deadline must carry its own (`curl --max-time`, `AbortSignal.timeout`, the Bash tool's `timeout` param). BSD `cat` also has no `-A`.
- An unmatched glob aborts the whole command in zsh (`no matches found`), so `rm -f "$dir"/*.png && …` dies when no PNGs exist and the rest of the `&&` chain never runs. Use `find "$dir" -name '*.png' -delete`.
- `?` is a glob too: an unquoted URL with a query string (`for u in https://…?lang=da`) dies with `no matches found`. Single-quote URLs.
- zsh treats `:r`, `:h`, `:t`, `:e` after a bare `$var` as filename modifiers, so `git push origin "$sha:refs/heads/main"` silently mangles the refspec (`…efs/heads/main does not match any`). Brace it: `"${sha}:refs/heads/main"`.
