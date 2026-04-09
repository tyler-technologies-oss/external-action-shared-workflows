#!/usr/bin/env bash
set -euo pipefail

# Create GitHub issues for manifest drift detections.
# Inputs via env:
#   GH_TOKEN           - GitHub token for gh CLI
#   DRIFT_DATA         - multiline drift details from verify-pinned-tags.sh
#   GITHUB_REPOSITORY  - owner/repo (auto-set by GHA)

while IFS= read -r LINE; do
  [ -z "${LINE}" ] && continue

  RAW_TAG=$(echo "${LINE}" | awk '{print $1}')
  MANIFEST_SHA=$(echo "${LINE}" | awk -F= '{print $2}' | awk '{print $1}')
  LIVE_SHA=$(echo "${LINE}" | awk -F= '{print $3}')

  # Sanitize tag name (attacker-controlled upstream input)
  TAG=$(echo "${RAW_TAG}" | tr -cd 'a-zA-Z0-9._+-')
  if [ "${TAG}" != "${RAW_TAG}" ]; then
    echo "::warning::Tag name sanitized: '${RAW_TAG}' -> '${TAG}'"
  fi

  ISSUE_TITLE="[SECURITY ALERT] Fork tag drift detected: ${TAG}"

  EXISTING=$(gh issue list \
    --repo "${GITHUB_REPOSITORY}" \
    --search "${ISSUE_TITLE}" \
    --state open \
    --limit 1 \
    --json title \
    --jq '.[].title' 2>/dev/null || true)

  if [ "${EXISTING}" = "${ISSUE_TITLE}" ]; then
    echo "Alert already exists for drifted tag ${TAG}, skipping"
    continue
  fi

  gh issue create \
    --repo "${GITHUB_REPOSITORY}" \
    --title "${ISSUE_TITLE}" \
    --label "security-alert,needs-security-review" \
    --body "## Fork Tag Drift Detected: ${TAG}

The fork's tag \`${TAG}\` no longer matches the SHA recorded in \`FORK_MANIFEST.json\`. This could indicate:

- **Fork-side tampering** (someone force-pushed a tag in the fork)
- **Manual tag recreation** without updating the manifest
- **Manifest corruption** from a bad merge

### Details

| Source | SHA |
|--------|-----|
| **FORK_MANIFEST.json (expected)** | \`${MANIFEST_SHA}\` |
| **Live fork tag** | \`${LIVE_SHA}\` |

### Required Actions

1. **Investigate** who changed the fork tag and why
2. **Verify** the current tag points to reviewed, safe code
3. **Update** FORK_MANIFEST.json if the change was intentional
4. **Revert** the tag if the change was unauthorized"

  echo "Created drift alert for tag ${TAG}"
done <<< "${DRIFT_DATA}"
