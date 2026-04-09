#!/usr/bin/env bash
set -euo pipefail

# Update FORK_MANIFEST.json with latest synced SHA
# Inputs via env: UPSTREAM_SHA_RAW
# Outputs to $GITHUB_OUTPUT: updated

SHA="$(echo "${UPSTREAM_SHA_RAW}" | tr -d '[:space:]')"
if ! echo "${SHA}" | grep -qE '^[0-9a-f]{40}$'; then
  echo "::error::Invalid upstream SHA format: '${SHA}'"
  exit 1
fi

if [ -f FORK_MANIFEST.json ]; then
  jq \
    --arg sha "${SHA}" \
    --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.sync.last_synced_sha = $sha | .sync.last_synced_date = $date' \
    FORK_MANIFEST.json > FORK_MANIFEST.json.tmp \
    && mv FORK_MANIFEST.json.tmp FORK_MANIFEST.json
  echo "updated=true" >> "$GITHUB_OUTPUT"
else
  echo "FORK_MANIFEST.json not found on upstream-tracking branch, skipping manifest update."
  echo "updated=false" >> "$GITHUB_OUTPUT"
fi
