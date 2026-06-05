# Global preferences

## Project setup

- When working in a project (or subdirectory) that has no `CLAUDE.md` file, remind me that one is missing so I can decide whether to create one.

## Troubleshooting

- If GitHub operations fail (e.g. `gh` commands, pushes, API calls, auth errors), flag a stale/bad `GITHUB_TOKEN` env var as the likely cause. A fresh token can be obtained from the gh CLI (`gh auth token`).
