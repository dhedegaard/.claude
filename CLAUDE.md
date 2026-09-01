# Global preferences

## Project setup

- When working in a project (or subdirectory) that has no `CLAUDE.md` file, remind me that one is missing so I can decide whether to create one.
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

- Never squash-merge PRs. Preserve the individual commit history — use a regular merge commit (or rebase) instead. When running `gh pr merge`, do not pass `--squash`.

## Docs / plans

- When a feature is done, keep the spec/design docs around but remove the implementation plan (e.g. delete files under a `plans/` dir while leaving `specs/`). Do this as part of finishing the work.

## Dev servers / processes

- Never kill dev servers by name pattern (`pkill -f next` and friends) — I run several projects at once and it takes them all down. Find the one process by port with `lsof -ti:<port>` and kill that PID.

## Troubleshooting

- If GitHub operations fail (e.g. `gh` commands, pushes, API calls, auth errors), flag a stale/bad `GITHUB_TOKEN` env var as the likely cause. A fresh token can be obtained from the gh CLI (`gh auth token`).

## Shell

- zsh's `status` is a **read-only** variable (an alias for `$?`), so `status=$(...)` aborts the script with `read-only variable: status`. Verified that `path`, `argv` and `pipestatus` assign fine — only `status` bites.
- zsh expands a leading `=` in a word (`=cmd` → command path), so `echo ===` fails with `(eval):1: == not found`. Quote separators: `echo "---"`.
- `grep`'s `--include`/`--exclude` globs must be quoted (`--include='*.ts'`). Unquoted, zsh tries to expand them and the command dies with `(eval):1: no matches found: --include=*.ts`.
- A heredoc after a pipe feeds the **last** command in the pipeline: `gh pr create --body-file - 2>&1 | tail -3 <<'BODY'` gives the body to `tail`, leaving `gh` waiting on stdin until it times out. Write the body to a file and pass its path.
- `sed` is aliased to GNU `gsed` **interactively only** — the alias does not load in a non-interactive shell, so `sed -i <expr>` there hits BSD sed and fails ("bad flag in substitute command"). Call `gsed -i <expr>` explicitly, or use a `python3` heredoc for multi-file edits. Use `/usr/bin/sed` for BSD syntax.
