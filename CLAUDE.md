# Global preferences

## Project setup

- Check for applicable project instructions, including those inherited from parent directories. Use `AGENTS.md`, falling back to `CLAUDE.md` if absent; an `AGENTS.md` that only holds Next's generated `nextjs-agent-rules` block doesn't count, so read `CLAUDE.md` too. If neither applies, remind me so I can decide whether to create one.
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
- Name a schema exactly like the type it defines — `const User = z.object(…)` with `interface User extends z.infer<typeof User> {}` — never `userSchema`. The schema is the type's runtime form, and TS keeps values and types apart. Schemas without a matching type are PascalCase too (`ServerEnv`).
- For object schemas, infer to an interface — `interface User extends z.infer<typeof User> {}` — not a type alias. Better error messages, and it stays declaration-mergeable/extendable. Falls back to a type alias where TS won't let an interface extend the inferred type — unions, intersections (`.and()`), index signatures, `z.record`.
- In new code, model failure in the return type — a union or discriminated union (e.g. `{ ok: true, value } | { ok: false, error }`), or zod's `safeParse` — rather than throwing. Errors then show up in the types and the compiler forces the caller to handle them, instead of hiding in a `throw` no signature mentions. In a codebase that already throws, match it — one consistent convention beats a better one applied halfway.
- Put `satisfies <Type>` on object literals you assemble and return, push or pass on — every arm of a `match`, an early return, a task event — even when the signature already declares the type. It checks each literal against its own type, so an excess or misspelled property fails at that spot instead of passing as part of a wider union. For a discriminated union, satisfy the specific member (name each member as its own interface), not the whole union.

## Git / PRs

- I often edit files in the same repo while you work. Inspect existing staged changes before staging explicit paths (`git add <path> …`), never `git add -A`. If we edited the same file, stage only your intended hunks. Review the staged diff before committing; keep unrelated edits out of your commit and preserve my staging choices.
- When a PR review comment is handled (Copilot's included), reply on that thread with what changed and the commit sha, then resolve it. Replying is `gh api repos/<o>/<r>/pulls/<n>/comments/<id>/replies`; resolving is GraphQL only — `resolveReviewThread` with the thread id from `pullRequest.reviewThreads`, which REST cannot do.
- To request a fresh Copilot review (e.g. after pushing fixes): `gh pr edit <n> --add-reviewer "@copilot"`. `requested_reviewers` won't list it; the PR timeline's `review_requested` event confirms it. It does nothing while an earlier request is still pending (no new `review_requested` event), and the timeline API is paginated, so check it with `gh api --paginate …/timeline`. A Copilot verdict may cover an older commit: compare the review's `commit_id` on `…/pulls/<n>/reviews` with the head before acting on it.
- Codex's PR verdict is the hidden `codex-review-state:v1` JSON in its latest issue comment (`gh api repos/<o>/<r>/issues/<n>/comments`, author `chatgpt-codex-connector[bot]`): check `code_review.commit_sha` against the head and `has_unresolved_findings`.
- Copilot's review counts as the required approval on DIGISENSE-AS repos: its verdict "🟢 Approved" is submitted as `APPROVED`, while "🔵 Needs a closer look" is only `COMMENTED`. To get an approval, address its concern (or, for dependency PRs, state in the PR body why each risky move is safe), then re-request a Copilot review. Check `gh pr view <n> --json reviewDecision`.
- Never squash-merge PRs. Preserve the individual commit history — use a regular merge commit (or rebase) instead. When running `gh pr merge`, do not pass `--squash`.
- When I ask you to merge a PR, merge it — that is my authorization, even when `main` auto-deploys. Run `gh pr merge` as its own Bash command, never chained with `;` or `&&`, so the `Bash(gh pr merge:*)` allow rule matches.
- `git push` failing with `cannot lock ref 'refs/heads/<b>': is at <X> but expected <Y>` can mean the push itself landed. Run `git fetch` and compare `git rev-parse HEAD` with `origin/<b>` before retrying; never force-push over it.
- Copilot reviews the PR description too, and flags it when it disagrees with the diff. When a docs or design PR changes substance, update the body in the same pass, before re-requesting review.
- Never chain `git commit --amend` after another git command in one line (`git revert … && git commit --amend`, or with `;`): if the first step makes no commit, the amend rewrites the one before. Run it separately, after checking `git log -1`.

## Worktrees

- Don't use git worktrees (including any native worktree tool) for implementation work — work directly on a branch in the existing checkout instead. Only use a worktree when I explicitly ask for one.

## Docs / plans

- When a feature is done, keep its spec/design docs but delete only that feature's completed implementation plan. Preserve plans for unrelated or unfinished work. Do this as part of finishing the work.

## Dev servers / processes

- Never kill dev servers by name pattern (`pkill -f next` and friends) — I run several projects at once and it takes them all down. Find the listening process with `lsof -nP -iTCP:<port> -sTCP:LISTEN`, verify it belongs to the intended server, then kill that specific PID.
- Never edit `.envrc` in any project — only I change it. Reading it is fine. When a task needs a different env (prod vs test vs localhost), tell me what it must point at and wait for me to switch it.

## Troubleshooting

- Fixes for loud failures (zsh errors, missing `timeout`/`gsed`, `MODULE_NOT_FOUND` in scratch scripts, GitHub auth and workflow-scope merge errors, Playwright/Chrome, checks under another Node, committing onto `main` without checkout) live in the `machine-troubleshooting` skill — load it when one of those comes up.
- The tool shell's `GH_TOKEN` is a stale override (seen 2026-10-29): plain `gh` fails with errors that look like a missing repository ("Could not resolve to a Repository"), while the keyring login works. Run every `gh` command as `env -u GH_TOKEN -u GITHUB_TOKEN gh …` from the start. `git push` over SSH is unaffected.
- To inspect a downloaded or untrusted `.git`, read its `config`/`hooks` first and run git as `GIT_CONFIG_NOSYSTEM=1 git --git-dir=<dir> -c core.hooksPath=/dev/null -c core.fsmonitor= …` (an array in zsh), so its config can't execute anything.

## Shell

- Avoid special shell variables as scratch variables; use task-specific names. In zsh, `status` is read-only, and assigning to `path` changes `PATH`, potentially breaking command lookup. Other special variables such as `argv` and `pipestatus` also have shell-defined meanings.
- A heredoc after a pipe feeds the **last** command in the pipeline: `gh pr create --body-file - 2>&1 | tail -3 <<'BODY'` gives the body to `tail`, leaving `gh` waiting on stdin until it times out. Write the body to a file and pass its path.
- An **unquoted** heredoc (`python3 - <<PY`) command-substitutes backticks in its body, so an edit script containing a markdown `` `snippet` `` silently loses it or dies with "command not found". Always quote the delimiter: `<<'PY'`.
- zsh treats `:r`, `:h`, `:t`, `:e` after a bare `$var` as filename modifiers, so `git push origin "$sha:refs/heads/main"` silently mangles the refspec (`…efs/heads/main does not match any`). Brace it: `"${sha}:refs/heads/main"`.
- In zsh, `local var` on a name already set in that scope **prints** `var=value` instead of redeclaring silently, so a loop that re-runs `local x; x=$(…)` leaks lines into the output. Declare locals once, before the loop.
- Under `bash -e` (GitHub Actions' default `run:` shell), a failure anywhere in an `&&` list except the last command does not stop the script: `test -n "$a" && test -n "$b"` lets an empty `$a` through. Put one guard per line.
- `git grep -E` has no `\b`: a pattern using it silently matches nothing. Use `-w` for whole words, or `([^A-Za-z]|$)` as the boundary.
- `${PIPESTATUS[0]}` is empty in zsh, so an exit code checked through a pipe reads as blank. Run the command unpiped (`cmd >/dev/null 2>&1; echo "x=$?"`).
- Bash calls sent in the same response can share a working directory, so a `cd` in one can leak into the other. Use `git -C`/absolute paths, or run per-repo commands one after another.

## Subagents

- `feature-dev:code-reviewer` has no Bash: it cannot run `git diff` or tests. For a review that must read a branch diff or run tests, use `general-purpose`, or paste the diff into the prompt.
