# Global preferences

## Project setup

- Check for applicable project instructions, including those inherited from parent directories. Use `AGENTS.md`, falling back to `CLAUDE.md` if absent. If neither applies, remind me so I can decide whether to create one.
- npm is the default package manager, but an existing project's convention wins — check the lockfile before running anything.
- Expect lint, typecheck and test scripts in `package.json`; use them to verify work rather than inventing commands. If one is missing, tell me instead of working around it.

## Code style

- Keep comments short, and skip them where the code already makes the intent clear — a comment should explain *why*, not restate the line below it.

## TypeScript

- Explicit, strict types. Never `any` — use `unknown` plus narrowing when the type genuinely isn't known.
- Import zod as a namespace — `import * as z from 'zod'` (`import type * as z` for type-only) — never `import { z }` or a default import. esbuild can't tree-shake the named form, and Turbopack ships every zod locale to the client unless all client-reachable imports are namespace imports.
- Namespace imports alone don't keep the locales out. Runtime `z.core.*` (e.g. `instanceof z.core.$ZodError`) or `z.locales.*` access and `import { da } from 'zod/locales'` pull in all of them. Use `import * as core from 'zod/v4/core'`, and `import da from 'zod/v4/locales/da.js'` with `z.config(da())`. Type-only `z.core.$ZodType` is fine. Enforce it with an ESLint `no-restricted-syntax` rule.
- A library built with tsdown/rolldown needs `outputOptions: { minifyInternalExports: false }`: a minified shared-chunk export that happens to share its name with the chunk's zod binding makes Turbopack bundle the whole zod namespace into consumers. To check a Next app, `grep -rl 'Ungültig' .next/static/chunks` should find nothing.
- Always validate data at a runtime boundary — user input, other systems, integrations, the database, env, parsed files — with zod. A hand-written type on unvalidated data is a lie the compiler can't catch; parse it so the type is earned.
- Derive types from the zod schema with `z.infer` rather than declaring the schema and the type separately — one source of truth, no drift.
- For object schemas, infer to an interface — `interface User extends z.infer<typeof userSchema> {}` — not a type alias. Better error messages, and it stays declaration-mergeable/extendable. Falls back to a type alias where TS won't let an interface extend the inferred type — unions, intersections (`.and()`), index signatures, `z.record`.
- In new code, model failure in the return type — a union or discriminated union (e.g. `{ ok: true, value } | { ok: false, error }`), or zod's `safeParse` — rather than throwing. Errors then show up in the types and the compiler forces the caller to handle them, instead of hiding in a `throw` no signature mentions. In a codebase that already throws, match it — one consistent convention beats a better one applied halfway.
- Put `satisfies <Type>` on object literals you assemble and return, push or pass on — every arm of a `match`, an early return, a task event — even when the signature already declares the type. It checks each literal against its own type, so an excess or misspelled property fails at that spot instead of passing as part of a wider union. For a discriminated union, satisfy the specific member (name each member as its own interface), not the whole union.

## Git / PRs

- I often edit files in the same repo while you work. Inspect existing staged changes before staging explicit paths (`git add <path> …`), never `git add -A`. If we edited the same file, stage only your intended hunks. Review the staged diff before committing; keep unrelated edits out of your commit and preserve my staging choices.
- When a PR review comment is handled (Copilot's included), reply on that thread with what changed and the commit sha, then resolve it. Replying is `gh api repos/<o>/<r>/pulls/<n>/comments/<id>/replies`; resolving is GraphQL only — `resolveReviewThread` with the thread id from `pullRequest.reviewThreads`, which REST cannot do.
- Never squash-merge PRs. Preserve the individual commit history — use a regular merge commit (or rebase) instead. When running `gh pr merge`, do not pass `--squash`.
- When I ask you to merge a PR, merge it — that is my authorization, even when `main` auto-deploys. Run `gh pr merge` as its own Bash command, never chained with `;` or `&&`, so the `Bash(gh pr merge:*)` allow rule matches.
- To commit a file onto `main` while a feature branch is checked out (no checkout, no worktree): `GIT_INDEX_FILE=<tmp> git read-tree main`, `git hash-object -w <file>` + `update-index --cacheinfo 100644,<blob>,<path>`, `write-tree`, `commit-tree <tree> -p main`, push `<sha>:refs/heads/main`, then `git update-ref refs/heads/main <sha> <old>`. Only valid when the file's base on `main` is what you edited — otherwise build it from `git show main:<path>`.
- Never chain `git commit --amend` after another git command in one line (`git revert … && git commit --amend`, or with `;`): if the first step makes no commit, the amend rewrites the one before. Run it separately, after checking `git log -1`.

## Worktrees

- Don't use git worktrees (including any native worktree tool) for implementation work — work directly on a branch in the existing checkout instead. Only use a worktree when I explicitly ask for one.

## Docs / plans

- When a feature is done, keep its spec/design docs but delete only that feature's completed implementation plan. Preserve plans for unrelated or unfinished work. Do this as part of finishing the work.

## Dev servers / processes

- Never kill dev servers by name pattern (`pkill -f next` and friends) — I run several projects at once and it takes them all down. Find the listening process with `lsof -nP -iTCP:<port> -sTCP:LISTEN`, verify it belongs to the intended server, then kill that specific PID.

## Troubleshooting

- Playwright MCP needs `/Applications/Google Chrome.app`, which isn't installed. For headless browser checks, use the `playwright` npm package in a scratch dir with `chromium.launch({ executablePath })` pointing at the cached `~/Library/Caches/ms-playwright/chromium_headless_shell-*/…/chrome-headless-shell`, since the package's own browser revision may not match the cache.
- For GitHub authentication failures, check for stale/bad `GH_TOKEN` or `GITHUB_TOKEN` overrides; `GH_TOKEN` takes precedence. Check stored credentials with `env -u GH_TOKEN -u GITHUB_TOKEN gh auth status`. `gh auth token` retrieves the current token, not a fresh one, and can return the same bad override. Do not print tokens in tool output. Diagnose other GitHub failures from their actual errors.
- The tool shell's `GH_TOKEN` is a stale override (seen 2026-10-29): plain `gh` fails with errors that look like a missing repository ("Could not resolve to a Repository"), while the keyring login works. Run every `gh` command as `env -u GH_TOKEN -u GITHUB_TOKEN gh …` from the start. `git push` over SSH is unaffected.
- `gh pr merge` failing with "refusing to allow an OAuth App to create or update workflow … without `workflow` scope": the keyring token has only `repo`, and the PR changes a workflow file that also changed on the base since it branched, so GitHub would have to write the merged file. Merge the base into the branch locally, push over SSH, let CI pass, then merge again. (`gh auth refresh -s workflow` adds the scope instead, but needs a browser login.)

## Shell

- Avoid special shell variables as scratch variables; use task-specific names. In zsh, `status` is read-only, and assigning to `path` changes `PATH`, potentially breaking command lookup. Other special variables such as `argv` and `pipestatus` also have shell-defined meanings.
- Short names like `c` may be aliases in the tool shell. Defining a function with one (`c() { … }`) fails with `defining function based on alias`. Use descriptive function names, or put the script in a file and run it with `bash`.
- zsh expands a leading `=` in a word (`=cmd` → command path), so `echo ===` fails with `(eval):1: == not found`. Quote separators: `echo "---"`.
- `grep`'s `--include`/`--exclude` globs must be quoted (`--include='*.ts'`). Unquoted, zsh tries to expand them and the command dies with `(eval):1: no matches found: --include=*.ts`.
- A heredoc after a pipe feeds the **last** command in the pipeline: `gh pr create --body-file - 2>&1 | tail -3 <<'BODY'` gives the body to `tail`, leaving `gh` waiting on stdin until it times out. Write the body to a file and pass its path.
- `sed` may or may not resolve to GNU `gsed` in Claude's tool shell (`gsed` was `command not found` in one session, the alias loaded in another); for multi-file or in-place edits use a quoted `python3 - <<'PY'` heredoc rather than relying on either. Use `/usr/bin/sed` for BSD syntax.
- An **unquoted** heredoc (`python3 - <<PY`) command-substitutes backticks in its body, so an edit script containing a markdown `` `snippet` `` silently loses it or dies with "command not found". Always quote the delimiter: `<<'PY'`.
- A `\u0000`-style escape written inside a heredoc becomes a **real control character** in the tool call, and the Bash tool refuses the whole command ("command contains control characters"). Use the Write tool for that file, or build the character in code (`String.fromCharCode(0)`).
- Neither `timeout` nor `gtimeout` is installed on this machine (`command not found`), so a command needing a deadline must carry its own (`curl --max-time`, `AbortSignal.timeout`, the Bash tool's `timeout` param). BSD `cat` also has no `-A`.
- An unmatched glob aborts the whole command in zsh (`no matches found`), so `rm -f "$dir"/*.png && …` dies when no PNGs exist and the rest of the `&&` chain never runs. Use `find "$dir" -name '*.png' -delete`.
- zsh does not word-split unquoted `$var`: `F="a.ts b.ts"; npx eslint $F` passes ONE path ("No files matching the pattern"). Use an array — `F=(a.ts b.ts); npx eslint "${F[@]}"`.
- `?` is a glob too: an unquoted URL with a query string (`for u in https://…?lang=da`) dies with `no matches found`. Single-quote URLs.
- zsh treats `:r`, `:h`, `:t`, `:e` after a bare `$var` as filename modifiers, so `git push origin "$sha:refs/heads/main"` silently mangles the refspec (`…efs/heads/main does not match any`). Brace it: `"${sha}:refs/heads/main"`.
- In zsh, `local var` on a name already set in that scope **prints** `var=value` instead of redeclaring silently, so a loop that re-runs `local x; x=$(…)` leaks lines into the output. Declare locals once, before the loop.
- Under `bash -e` (GitHub Actions' default `run:` shell), a failure anywhere in an `&&` list except the last command does not stop the script: `test -n "$a" && test -n "$b"` lets an empty `$a` through. Put one guard per line.
- `git grep -E` has no `\b`: a pattern using it silently matches nothing. Use `-w` for whole words, or `([^A-Za-z]|$)` as the boundary.
- zsh-only parameter expansion (`${=var}`, `${(@f)$(…)}`) makes the Bash tool's safety check refuse the command as unparseable ("could not be checked for dangerous rm operations"). Use plain loops, `bash -c '…'`, or `git diff --name-only -z | xargs -0 git add --`.

## Subagents

- `feature-dev:code-reviewer` has no Bash: it cannot run `git diff` or tests. For a review that must read a branch diff or run tests, use `general-purpose`, or paste the diff into the prompt.
