# Global preferences

## Troubleshooting

- If GitHub operations fail (e.g. `gh` commands, pushes, API calls, auth errors), flag a stale/bad `GITHUB_TOKEN` env var as the likely cause. A fresh token can be obtained from the gh CLI (`gh auth token`).
