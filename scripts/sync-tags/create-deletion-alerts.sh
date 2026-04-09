#!/usr/bin/env bash
set -euo pipefail

# Create GitHub issues for tags deleted from upstream.
# Inputs via env:
#   GH_TOKEN           - GitHub token for gh CLI
#   GITHUB_REPOSITORY  - owner/repo (auto-set by GHA)
#   UPSTREAM_OWNER     - upstream repository owner
#   UPSTREAM_REPO      - upstream repository name

while IFS= read -r RAW_TAG; do
  [ -z "${RAW_TAG}" ] && continue
  # Sanitize tag name (attacker-controlled upstream input)
  TAG=$(echo "${RAW_TAG}" | tr -cd 'a-zA-Z0-9._+-')

  ISSUE_TITLE="[Security Notice] Upstream tag removed: ${TAG}"

  EXISTING=$(gh issue list \
    --repo "${GITHUB_REPOSITORY}" \
    --search "${ISSUE_TITLE}" \
    --state all \
    --limit 1 \
    --json title \
    --jq '.[].title' 2>/dev/null || true)

  if [ "${EXISTING}" = "${ISSUE_TITLE}" ]; then
    echo "Notice already exists for deleted tag ${TAG}, skipping"
    continue
  fi

  gh issue create \
    --repo "${GITHUB_REPOSITORY}" \
    --title "${ISSUE_TITLE}" \
    --label "upstream-sync,needs-security-review" \
    --body "## Upstream Tag Removed: ${TAG}

The tag \`${TAG}\` exists in this fork but is **no longer present** in the upstream repository.

This could indicate:

- Upstream maintainer **retracted a release** (e.g. due to a bug or vulnerability)
- Upstream repository **housekeeping** (removing old pre-releases)
- A **compromised upstream account** deleting tags before re-creating them

### Required Actions

- [ ] Check the upstream release page for context: [${UPSTREAM_OWNER}/${UPSTREAM_REPO} releases](https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases)
- [ ] Determine if the fork should continue using this tag
- [ ] If the tag was retracted due to a vulnerability, stop using it immediately

> **The fork's tag is unaffected** -- it still exists and points to the original commit."

  echo "Created deletion notice for tag ${TAG}"
done < /tmp/deleted_upstream_tags.txt
