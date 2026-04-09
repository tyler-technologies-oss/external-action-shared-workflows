#!/usr/bin/env bash
set -euo pipefail

# Create GitHub issues for upstream tag mutations (SHA changed).
# Inputs via env:
#   GH_TOKEN           - GitHub token for gh CLI
#   MUTATED_DATA       - multiline mutation details from detect-tag-mutations.sh
#   GITHUB_REPOSITORY  - owner/repo (auto-set by GHA)
#   UPSTREAM_OWNER     - upstream repository owner
#   UPSTREAM_REPO      - upstream repository name

while IFS= read -r LINE; do
  [ -z "${LINE}" ] && continue

  RAW_TAG=$(echo "${LINE}" | awk '{print $1}')
  UPSTREAM_SHA=$(echo "${LINE}" | awk -F= '{print $2}' | awk '{print $1}')
  FORK_SHA=$(echo "${LINE}" | awk -F= '{print $3}')
  # Sanitize tag name (attacker-controlled upstream input)
  TAG=$(echo "${RAW_TAG}" | tr -cd 'a-zA-Z0-9._+-')

  ISSUE_TITLE="[SECURITY ALERT] Upstream tag mutated: ${TAG}"

  EXISTING=$(gh issue list \
    --repo "${GITHUB_REPOSITORY}" \
    --search "${ISSUE_TITLE}" \
    --state open \
    --limit 1 \
    --json title \
    --jq '.[].title' 2>/dev/null || true)

  if [ "${EXISTING}" = "${ISSUE_TITLE}" ]; then
    echo "Alert already exists for mutated tag ${TAG}, skipping"
    continue
  fi

  gh issue create \
    --repo "${GITHUB_REPOSITORY}" \
    --title "${ISSUE_TITLE}" \
    --label "upstream-sync,needs-security-review,security-alert" \
    --body "## Upstream Tag Mutation Detected: ${TAG}

The upstream tag \`${TAG}\` now points to a **different commit** than the fork's copy. This could indicate:

- A **supply chain attack** (tag force-pushed to malicious code)
- An upstream maintainer **re-tagging** a release (bad practice but sometimes benign)
- A **compromised upstream account**

### Details

| | SHA |
|---|---|
| **Fork (pinned)** | \`${FORK_SHA}\` |
| **Upstream (changed)** | \`${UPSTREAM_SHA}\` |

### Upstream comparison

[\`${FORK_SHA}...${UPSTREAM_SHA}\`](https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/compare/${FORK_SHA}...${UPSTREAM_SHA})

### Required Actions

1. **Do NOT update the fork tag** until investigation is complete
2. Review the diff between the two SHAs above
3. Check upstream release notes and issue tracker for explanations
4. Contact the upstream maintainer if no explanation is found
5. If benign: close this issue with a note explaining the change
6. If malicious: consider removing the fork tag and notifying dependent teams

> **The fork's tag is safe** -- it still points to the original reviewed commit."

  echo "Created mutation alert for tag ${TAG}"
done <<< "${MUTATED_DATA}"
