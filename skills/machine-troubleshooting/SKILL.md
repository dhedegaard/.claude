---
name: machine-troubleshooting
description: Fixes for loud failures in this Mac's tool shell and dev tooling. Read when a command dies with a zsh error (`no matches found`, `== not found`, `defining function based on alias`, "could not be checked for dangerous rm operations", "command contains control characters", `timeout`/`gsed` not found), with `MODULE_NOT_FOUND` from a scratch script, with a GitHub auth error or a `gh pr merge` workflow-scope refusal, or before running checks under another Node, a headless browser check, or committing a file onto main while a feature branch is checked out.
---

# Machine troubleshooting

Silent-failure gotchas stay in `~/.claude/CLAUDE.md`; these are the ones whose error message tells you something went wrong.

## zsh / tool shell

- Short names like `c` may be aliases in the tool shell. Defining a function with one (`c() { … }`) fails with `defining function based on alias`. Use descriptive function names, or put the script in a file and run it with `bash`.
- zsh expands a leading `=` in a word (`=cmd` → command path), so `echo ===` fails with `(eval):1: == not found`. Quote separators: `echo "---"`.
- `grep`'s `--include`/`--exclude` globs must be quoted (`--include='*.ts'`). Unquoted, zsh tries to expand them and the command dies with `(eval):1: no matches found: --include=*.ts`.
- An unmatched glob aborts the whole command in zsh (`no matches found`), so `rm -f "$dir"/*.png && …` dies when no PNGs exist and the rest of the `&&` chain never runs. Use `find "$dir" -name '*.png' -delete`.
- `?` is a glob too: an unquoted URL with a query string (`for u in https://…?lang=da`) dies with `no matches found`. Single-quote URLs.
- zsh does not word-split unquoted `$var`: `F="a.ts b.ts"; npx eslint $F` passes ONE path ("No files matching the pattern"). Use an array — `F=(a.ts b.ts); npx eslint "${F[@]}"`.
- zsh-only parameter expansion (`${=var}`, `${(@f)$(…)}`) makes the Bash tool's safety check refuse the command as unparseable ("could not be checked for dangerous rm operations"). Use plain loops, `bash -c '…'`, or `git diff --name-only -z | xargs -0 git add --`.
- A `\u0000`-style escape written inside a heredoc becomes a **real control character** in the tool call, and the Bash tool refuses the whole command ("command contains control characters"). Use the Write tool for that file, or build the character in code (`String.fromCharCode(0)`).
- `sed` may or may not resolve to GNU `gsed` in Claude's tool shell (`gsed` was `command not found` in one session, the alias loaded in another); for multi-file or in-place edits use a quoted `python3 - <<'PY'` heredoc rather than relying on either. Use `/usr/bin/sed` for BSD syntax.
- Neither `timeout` nor `gtimeout` is installed on this machine (`command not found`), so a command needing a deadline must carry its own (`curl --max-time`, `AbortSignal.timeout`, the Bash tool's `timeout` param). BSD `cat` also has no `-A`.

## Node / browsers

- To run a project's checks under another installed Node without switching nvm: `PATH=~/.nvm/versions/node/v<x>/bin:$PATH npm test` (also `npm run build`).
- A scratch script outside a repo can't `require` that repo's packages (`MODULE_NOT_FOUND`); run it with `NODE_PATH=<repo>/node_modules node <script>` rather than installing them in the scratch dir.
- Playwright MCP needs `/Applications/Google Chrome.app`, which isn't installed. For headless browser checks, use the `playwright` npm package in a scratch dir with `chromium.launch({ executablePath })` pointing at the cached `~/Library/Caches/ms-playwright/chromium_headless_shell-*/…/chrome-headless-shell`, since the package's own browser revision may not match the cache.

## GitHub / git

- For GitHub authentication failures, check for stale/bad `GH_TOKEN` or `GITHUB_TOKEN` overrides; `GH_TOKEN` takes precedence. Check stored credentials with `env -u GH_TOKEN -u GITHUB_TOKEN gh auth status`. `gh auth token` retrieves the current token, not a fresh one, and can return the same bad override. Do not print tokens in tool output. Diagnose other GitHub failures from their actual errors.
- `gh pr merge` failing with "refusing to allow an OAuth App to create or update workflow … without `workflow` scope": the keyring token has only `repo`, and the PR changes a workflow file that also changed on the base since it branched, so GitHub would have to write the merged file. Merge the base into the branch locally, push over SSH, let CI pass, then merge again. (`gh auth refresh -s workflow` adds the scope instead, but needs a browser login.)
- To commit a file onto `main` while a feature branch is checked out (no checkout, no worktree): `GIT_INDEX_FILE=<tmp> git read-tree main`, `git hash-object -w <file>` + `update-index --cacheinfo 100644,<blob>,<path>`, `write-tree`, `commit-tree <tree> -p main`, push `<sha>:refs/heads/main`, then `git update-ref refs/heads/main <sha> <old>`. Only valid when the file's base on `main` is what you edited — otherwise build it from `git show main:<path>`.
