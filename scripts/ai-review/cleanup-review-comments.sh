#!/usr/bin/env bash
# Delete previous github-actions[bot] inline and summary comments before a new review.
# Env: GITHUB_TOKEN, PR_NUMBER, REPO.
set -euo pipefail

echo "Removing previous github-actions[bot] inline review comments..."
INLINE_IDS=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
  --paginate --jq '.[] | select(.user.login == "github-actions[bot]") | .id')
for id in $INLINE_IDS; do
  gh api -X DELETE "repos/${REPO}/pulls/comments/${id}"
  echo "  Deleted inline comment ${id}"
done

echo "Removing previous github-actions[bot] summary comments..."
ISSUE_IDS=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --paginate --jq '.[] | select(.user.login == "github-actions[bot]") | .id')
for id in $ISSUE_IDS; do
  gh api -X DELETE "repos/${REPO}/issues/comments/${id}"
  echo "  Deleted summary comment ${id}"
done

echo "Cleanup complete."
