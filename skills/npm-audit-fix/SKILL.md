---
name: npm-audit-fix
description: Runs a dependency security audit, applies only the safe (non-breaking, in-range) fixes, verifies them with the project's own lint/typecheck/test scripts, commits and pushes them straight onto main, monitors CI and deployments until green, and reports every advisory that could not be safely fixed together with whether a major bump, RC or dev-tag upgrade of the parent package would clear it. Works with npm, pnpm, yarn and bun lockfiles, and every lockfile in a monorepo. Use this whenever the user says "npm audit", "audit fix", "fix vulnerabilities", "dependabot/security alerts on dependencies", "bump vulnerable packages", "do the audit thing", or otherwise wants known-vulnerable dependencies patched and shipped — even if they don't name the skill or mention pushing.
---

# npm-audit-fix

Patch vulnerable dependencies the boring, safe way and ship it: only fixes that
stay inside every dependent's declared semver range, verified, pushed to main,
watched until deployed. Everything that would need a breaking change is
*reported*, never applied.

## Hard rules (and why)

- **Only non-breaking fixes.** For npm that means `npm audit fix`, never
  `--force`. `--force` happily installs a lower major (it once proposed
  `prisma@7 → 6`) — a "fix" that is a downgrade and a breaking change.
- **Never add overrides, resolutions or patches** (`overrides`, `resolutions`,
  `pnpm.overrides`, `patchedDependencies`, …). They pin a transitive version the
  parent never tested and silently outlive the reason they were added. If a fix
  can't happen within the declared ranges, it goes in the report instead.
  This rules out `pnpm audit --fix`, which works by writing overrides.
- **Never do the major bump yourself.** Analyse it, report it, let the user
  decide.
- **Push directly to the default branch** (main). Invoking this skill is the
  authorization for that push; it does not extend to anything else (no force
  push, no reverts, no workflow reruns, no branch-protection bypass).

## Workflow

### 1. Orient

- Read the project instructions (`AGENTS.md`, else `CLAUDE.md`, including
  nested ones like `frontend/CLAUDE.md`). They name the verify commands, env
  prerequisites (e.g. `direnv exec .`, a required localhost database) and how
  deploys work. Follow them over the defaults below.
- Find every lockfile tracked in the repo:
  `git ls-files | grep -E '(^|/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?)$'`.
  Each lockfile's directory is one project to audit. A workspace root lockfile
  covers its workspaces — don't audit workspace members separately.
- Pick the manager from each lockfile. npm is covered here; for pnpm, yarn or
  bun read `references/other-package-managers.md` for the equivalent audit and
  in-range update commands.
- Git state:
  - Must be on the default branch (`git symbolic-ref refs/remotes/origin/HEAD`).
    If not, stop and ask — this skill ships to main.
  - `git fetch` and fast-forward (`git pull --ff-only`) so the push won't be
    rejected. If main has diverged, stop and report.
  - If a target lockfile or its `package.json` already has uncommitted edits,
    skip that project and say so — a lockfile can't be split into "their hunks"
    and "my hunks", and the user's edits must never ride along in this commit.
    Other unrelated dirty files are fine; they are simply never staged.

### 2. Audit

Per project: `npm audit` for the human-readable report, `npm audit --json` for
counts (`metadata.vulnerabilities`). Record the before-state per severity.
Nothing to fix → skip to step 7 (report "clean").

### 3. Apply safe fixes

- `npm audit fix` (no flags beyond what the project's instructions require).
- npm may warn that install scripts were blocked (`allowScripts`); that is
  about lifecycle scripts, not the fix, and is not a failure. Mention it only if
  a changed package actually has install scripts.
- Inspect the result: `git diff --stat` and the version lines of the lockfile
  diff (`git diff <lockfile> | grep -E '^[-+]\s+"version"|node_modules/'`).
  The diff must touch only the lockfile — the non-force fix path never writes
  `package.json`. If `package.json` changed, `overrides`/`resolutions`
  appeared, or anything else moved, revert that project
  (`git checkout -- <files>`) and report it.
- **Keep lockstep families aligned.** `npm audit fix` bumps only what the
  advisory chain touches, so it can move `prisma` and leave `@prisma/client`
  behind. If it bumped any direct dependency in a family, move every direct
  member of that family to the same version with an in-range
  `npm update <pkg> …` (lockfile-only, like the fix), then confirm with
  `npm ls`. Prisma: `prisma` and every direct `@prisma/*` dependency
  (`client`, `adapter-*`, `instrumentation`, …) must land on one version.
  Exact pins *inside* those packages (e.g. `@prisma/dev` → `@prisma/get-platform@7.2.0`)
  aren't ours to align. Same idea for `next` + `eslint-config-next` and
  `@angular/*`. If the matching version isn't in range for a member, don't
  ship a split family — report it.
- Preview first with `npm audit fix --dry-run` if you want to see the plan.
- Re-run `npm audit` to get the after-state. No diff at all → nothing to ship
  for that project.

### 4. Verify

Run the project's own scripts — lint, typecheck, unit tests — using the
single-run test variant (never a `--watch` script, it never exits). Use the
names from the project instructions or `package.json`; if one is missing, say so
rather than inventing a substitute. Honour env prerequisites from the
instructions (e.g. assert `DATABASE_URL` points at localhost before
DB-touching tests). Run them in the background if they are slow.

If anything fails: don't push. Leave the change unstaged and report the failing
output. If it looks unrelated to the bump, you may check whether it also fails
on a clean `HEAD` and say which it is — but still don't push.

### 5. Commit and push

- Check `git diff --cached` first and preserve anything the user already
  staged; stage only the lockfile paths from step 3 by explicit
  path (never `git add -A`). Review the staged diff before committing.
- One commit per project, e.g.:

  ```
  chore: apply non-breaking npm audit fixes

  Bumps brace-expansion (1.1.21, 5.0.12) and fast-uri (3.1.8) in the
  lockfile. The remaining deepmerge-ts and mysql2 advisories come via the
  prisma CLI and have no stable fix yet.
  ```

  Add whatever attribution trailer the session requires.
- `git push origin <default-branch>`. If it's rejected (protected branch,
  required reviews, non-fast-forward after a race), stop and report — never
  force-push, and don't open a PR unless the user asks.

### 6. Monitor until green

Find everything the push triggers, then watch it to a terminal state:

- **GitHub Actions**: `gh run list --commit <sha> --json name,status,conclusion,databaseId`.
  Runs can appear a little after the push, and the sha also collects runs you
  didn't trigger directly (Dependabot `npm_and_yarn` updates reacting to the
  lockfile change, "Code Quality"/CodeQL), so work out the expected workflows
  from `.github/workflows/*` push triggers and poll until each exists and every
  run is `completed`. Use the Monitor tool with a poll loop that
  emits one line per completed run (success *and* failure) and exits when all
  are done; don't sleep-poll in the foreground.
- **Deployments**: use what the project instructions describe. Common cases:
  - Vercel (`.vercel/project.json` has `projectId`/`orgId`): list deployments
    filtered by the commit sha, then wait with
    `vercel inspect <url> --wait --timeout 15m`; confirm `Ready` and that the
    production alias points at it.
  - Container platforms (Azure Container Apps, etc.) deployed by Actions: a
    green workflow isn't proof of rollout — confirm the running image/revision
    carries the new sha if the instructions say how.
- **Green**: every run succeeded and every deployment is live on the new sha.
- **Red**: send a PushNotification (failures only — a green result doesn't need
  one), pull the failure (`gh run view <id> --log-failed`, deployment build
  logs), and report the cause. Don't revert, re-run or push a fix without asking.

### 7. Analyse what's left

For every advisory still open after the safe fix, work out whether *any*
upgrade could clear it, so the user can decide:

1. **Chain**: `npm ls <vuln-pkg>` / `npm explain <vuln-pkg>` → which direct
   dependency pulls it in, and is that a runtime `dependency` or a
   `devDependency`/CLI-only tool.
2. **What `--force` would do**: read `npm audit`'s "Will install X@Y" line and
   flag it if it is a downgrade or a jump that isn't really a fix.
3. **Upgrade paths**: `npm view <direct-dep> dist-tags --json` (latest, next,
   rc, beta, dev, …). For each newer tag, walk down the chain with
   `npm view <pkg>@<version> dependencies --json` until you reach the
   vulnerable package, and check whether that version is at or past the
   advisory's patched version (`npm view <vuln-pkg> versions`/`time` and the
   GHSA link give the fixed version). A newer major may also have dropped the
   dependency entirely.
4. **Companions**: packages that must move in lockstep (e.g. `prisma` with
   `@prisma/client` and its adapters, `next` with `eslint-config-next`,
   `@angular/*`) — check the same tag exists for each; an upgrade path that
   only exists for one of them isn't usable yet.
5. **Exposure**: is the vulnerable code reachable? Dev-only CLI vs shipped to
   runtime, and whether the vulnerable feature is used (e.g. a MySQL driver
   pulled in by a CLI while the app talks to SQL Server).

Classify each: *fixable now by a major bump* (name the bump and what it
touches), *fixed only in a prerelease* (name the tag, say what's blocking it),
*no fix upstream yet*, or *not reachable / accept for now*.

## Report

Keep it short and lead with the outcome:

```
Shipped <sha> to main — <n> advisories fixed, CI + deploys green.

Fixed (safe, in-range):
- <pkg> <old> → <new> (<severity>, <via>)

Still open (<n>, <severities>):
- <pkg> via <chain> — <classification>. <one-line upgrade-path finding>.
  Exposure: <dev-only/runtime, reachable?>.

<Skipped projects / failures / blocked install scripts, if any>
```

If nothing was pushed (clean audit, no diff, failed verification, rejected
push), say that in the first line instead.
