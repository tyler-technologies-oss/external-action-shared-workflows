#!/usr/bin/env bash
set -euo pipefail

PR_NUM=$(gh pr list \
  --repo "${REPO}" \
  --base "${DEFAULT_BRANCH}" \
  --head upstream-tracking \
  --state open \
  --json number \
  --jq '.[0].number // empty')

if [ -n "${PR_NUM}" ]; then
  echo "Found sync PR #${PR_NUM}"
  echo "pr_number=${PR_NUM}" >> "$GITHUB_OUTPUT"
  echo "has_pr=true" >> "$GITHUB_OUTPUT"
else
  echo "No open sync PR found. Skipping security scan."
  echo "has_pr=false" >> "$GITHUB_OUTPUT"
fi
