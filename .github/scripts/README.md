# Org automation scripts

## `auto-close-terminal-status.sh`

Closes issues whose status on the Sparkweaving Board has reached a terminal value.

| Board status | Issue is closed as |
| --- | --- |
| Done | `COMPLETED` |
| Published | `COMPLETED` |
| Cancelled | `NOT_PLANNED` |

Any other status is left alone, as are archived items, draft items and pull requests.

### Why this exists instead of the built-in workflow

GitHub Projects ships an "Auto-close issue" workflow, but it accepts exactly one
status value and always closes as "completed". Three terminal statuses and two
close reasons do not fit into it. Selecting several status values has been an
open feature request since the workflow shipped in April 2024.

The script polls on a schedule because `projects_v2_item` is an organization-level
event and cannot trigger an Actions workflow.

### Running it by hand

```bash
GH_TOKEN=<token with org projects: read + issues: write> \
DRY_RUN=true \
./.github/scripts/auto-close-terminal-status.sh
```

`DRY_RUN=true` prints what would be closed and changes nothing. The scheduled
workflow exposes the same switch through its `workflow_dispatch` input.

### Configuration

| Variable | Meaning |
| --- | --- |
| `ORG` | Organization login, defaults to `sparkweavers` |
| `PROJECT_NUMBER` | Project number, defaults to `1` |
| `DRY_RUN` | `true` to log without closing |
| `GH_TOKEN` | Token used for both the query and the mutation |

The workflow supplies `GH_TOKEN` from a GitHub App installation token. The app
needs organization permission `projects: read` and repository permission
`issues: read and write`.
