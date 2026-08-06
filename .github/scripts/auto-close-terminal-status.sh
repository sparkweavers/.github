#!/usr/bin/env bash
#
# Close issues whose Sparkweaving Board status has reached a terminal value.
#
# The built-in "Auto-close issue" project workflow accepts exactly one status
# value and always closes as "completed". We need three values and two different
# close reasons, so the board is polled here instead.
#
#   Done, Published -> closed as COMPLETED
#   Cancelled       -> closed as NOT_PLANNED
#
# Requires GH_TOKEN with organization projects: read and issues: write.
# Set DRY_RUN=true to log what would happen without closing anything.

set -euo pipefail

ORG="${ORG:-sparkweavers}"
PROJECT_NUMBER="${PROJECT_NUMBER:-1}"
DRY_RUN="${DRY_RUN:-false}"

read -r -d '' ITEMS_QUERY <<'GRAPHQL' || true
query($org: String!, $number: Int!, $cursor: String) {
  organization(login: $org) {
    projectV2(number: $number) {
      items(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isArchived
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
          content {
            __typename
            ... on Issue {
              id
              number
              state
              title
              repository { nameWithOwner }
            }
          }
        }
      }
    }
  }
}
GRAPHQL

# Collect every open issue on the board that sits in a terminal status.
# jq maps the status to the close reason; anything else is dropped.
candidates="$(
  gh api graphql --paginate \
    -f query="$ITEMS_QUERY" \
    -F org="$ORG" \
    -F number="$PROJECT_NUMBER" \
    --jq '
      .data.organization.projectV2.items.nodes[]
      | select(.isArchived | not)
      | select(.content.__typename == "Issue")
      | select(.content.state == "OPEN")
      | {
          status: (.fieldValueByName.name // ""),
          id: .content.id,
          ref: "\(.content.repository.nameWithOwner)#\(.content.number)",
          title: .content.title
        }
      | . + {reason: (
          if .status == "Done" or .status == "Published" then "COMPLETED"
          elif .status == "Cancelled" then "NOT_PLANNED"
          else null end)}
      | select(.reason != null)
    '
)"

if [[ -z "$candidates" ]]; then
  echo "Nothing to close. Every open board item is in a non-terminal status."
  exit 0
fi

closed=0
failed=0

while IFS= read -r item; do
  [[ -z "$item" ]] && continue
  id="$(jq -r '.id' <<<"$item")"
  ref="$(jq -r '.ref' <<<"$item")"
  status="$(jq -r '.status' <<<"$item")"
  reason="$(jq -r '.reason' <<<"$item")"
  title="$(jq -r '.title' <<<"$item")"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "would close $ref as $reason (status $status) - $title"
    continue
  fi

  if gh api graphql \
    -f query='mutation($id: ID!, $reason: IssueClosedStateReason!) {
      closeIssue(input: {issueId: $id, stateReason: $reason}) {
        issue { number state stateReason }
      }
    }' \
    -F id="$id" \
    -F reason="$reason" >/dev/null; then
    echo "closed $ref as $reason (status $status) - $title"
    closed=$((closed + 1))
  else
    echo "::warning::failed to close $ref (status $status)"
    failed=$((failed + 1))
  fi
done <<<"$(jq -c '.' <<<"$candidates")"

echo "closed=$closed failed=$failed"

# A failure to close is worth surfacing, but it must not mask the successes.
[[ "$failed" -eq 0 ]]
