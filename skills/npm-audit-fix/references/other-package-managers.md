# pnpm, yarn and bun equivalents

Same rules as SKILL.md: stay inside every declared range, change only the
lockfile, never write overrides/resolutions/patches, no major bumps. Check the
installed version (`<pm> --version`) first — several of these are
version-gated. Items marked *unconfirmed* came from common practice, not docs;
verify with `<pm> help <cmd>` before relying on them.

The workflow otherwise is identical: audit → in-range update → diff must be
lockfile-only → re-audit → verify → commit → push → monitor → analyse.

## pnpm (`pnpm-lock.yaml`)

- Audit: `pnpm audit` / `pnpm audit --json`. In v11+, `patched_versions: null`
  means no fixed version exists.
- **Never plain `pnpm audit --fix`** — it always writes overrides
  (`pnpm.overrides` in `package.json`, or `overrides` in `pnpm-workspace.yaml`
  on v10 when there's no `pnpm` field).
- v11+: `pnpm audit --fix=update` updates the lockfile instead of adding
  overrides — allowed. Still inspect the diff for any `overrides` key.
- v9/v10 (and fallback): for each vulnerable package name from the audit,
  `pnpm update <name> --depth Infinity --no-save` (in a workspace:
  `pnpm -r update <name> --depth Infinity --no-save`). Updates direct and
  transitive copies within range; `--no-save` keeps `package.json` ranges
  untouched. Use the bare name — `<name>@<ver>` on an indirect dep errors
  (`ERR_PNPM_UPDATE_VERSION_ON_INDIRECT_DEP`) and would be a pin anyway.
- Upgrade-path analysis: `pnpm view <pkg> dist-tags`,
  `pnpm view <pkg>@<ver> dependencies --json` (native in v11; on v9/v10 just
  use `npm view`, which reads the same registry).
- Chain: `pnpm why <pkg>` (`-r` in workspaces).

## Yarn Berry v2–v4 (`yarn.lock` with a `__metadata:` header, `.yarnrc.yml`)

- Audit: `yarn npm audit --all --recursive` (`--json` gives NDJSON — one
  advisory per line).
- No auto-fix exists. For each vulnerable package: `yarn up -R <pkg>` — re-resolves
  every range matching `<pkg>` in the lockfile to the highest version it allows,
  manifests untouched. `-R` can't be combined with other flags. Never add
  `resolutions`.
- Info: `yarn npm info <pkg> --fields dist-tags --json`,
  `yarn npm info <pkg>@<ver> --fields dependencies --json`.
- Chain: `yarn why <pkg>`.

## Yarn classic v1 (`yarn.lock` without `__metadata:`)

- Audit: `yarn audit` / `yarn audit --json` (NDJSON). No fix flag.
- `yarn upgrade <pkg>` upgrades within range — safe for **direct** deps.
- Transitive deps (*unconfirmed*): `yarn upgrade <transitive>` may add it as a
  direct dependency — don't use it for those. The usual in-range method is to
  delete that package's entry block(s) from `yarn.lock` and run `yarn install`,
  which re-resolves to the highest in-range version. Verify the diff: only that
  package's entries (and its own new sub-deps) should change, and `package.json`
  must not.
- Info: `yarn info <pkg> dist-tags`, `yarn info <pkg>@<ver> dependencies`
  (*unconfirmed*; `npm view` works as a fallback).
- Chain: `yarn why <pkg>`.

## Bun (`bun.lock`, older `bun.lockb`)

- Audit: `bun audit` (v1.2.15+), `--json`, `--audit-level=`.
- v1.4.0+: `bun audit fix --dry-run` to preview, then `bun audit fix` — moves
  each vulnerable package to the lowest safe version every dependent range
  allows and re-audits. **Never `--latest`** (allows major bumps). Caveat: an
  exact pin in the project's own `package.json` is treated as `^ver` and gets
  rewritten — if `package.json` shows up in the diff, revert that project and
  report it rather than shipping a changed pin.
- Older bun: `bun update <pkg>` updates within range; before 1.4 it probably
  only touched direct deps (*unconfirmed*), so transitive advisories may just
  go in the report.
- Info: `bun info <pkg> dist-tags`, `bun info <pkg>@<ver> dependencies --json`
  (`bun pm view` on 1.2.15–1.2.x).
- Chain: `bun why <pkg>` (*unconfirmed* on older versions; read `bun.lock`
  directly otherwise — it's text JSONC since 1.2).
