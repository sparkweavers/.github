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

# Walk the board one page at a time.
#
# This deliberately does not use `gh api graphql --paginate`: that flag only
# advances the cursor when the query declares a variable named exactly
# $endCursor. With any other name it silently refetches the first page over and
# over, which yields duplicates and never reaches later pages.
fetch_items() {
  local cursor="" after page

  while :; do
    if [[ -z "$cursor" ]]; then
      after="null"
    else
      after="\"$cursor\""
    fi

    page="$(gh api graphql -f query="
      query {
        organization(login: \"$ORG\") {
          projectV2(number: $PROJECT_NUMBER) {
            items(first: 100, after: $after) {
              pageInfo { hasNextPage endCursor }
              nodes {
                isArchived
                fieldValueByName(name: \"Status\") {
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
      }")"

    jq -c '
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
      | select(.reason != null)' <<<"$page"

    [[ "$(jq -r '.data.organization.projectV2.items.pageInfo.hasNextPage' <<<"$page")" == "true" ]] || break
    cursor="$(jq -r '.data.organization.projectV2.items.pageInfo.endCursor' <<<"$page")"
  done
}

candidates="$(fetch_items)"

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
done <<<"$candidates"

echo "closed=$closed failed=$failed"

# A failure to close is worth surfacing, but it must not mask the successes.
[[ "$failed" -eq 0 ]]
