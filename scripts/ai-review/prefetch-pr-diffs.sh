#!/usr/bin/env bash
# Fetch PR file patches from the GitHub API and filter them by review type.
# Env: GITHUB_TOKEN, PR_NUMBER, REPO, REVIEW_SCOPE.
set -euo pipefail
echo "Fetching PR #${PR_NUMBER} file patches..."

gh api "repos/${REPO}/pulls/${PR_NUMBER}/files?per_page=100" \
  --paginate --jq '.[]' \
  | jq -s '.' > /tmp/pr_all_files.json

total=$(jq 'length' /tmp/pr_all_files.json)
echo "Total files in PR: ${total}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "${SCRIPT_DIR}/filter_diffs.py"
