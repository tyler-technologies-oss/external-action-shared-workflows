#!/usr/bin/env bash
set -euo pipefail

# Verify upstream repo identity against FORK_MANIFEST.json
# Inputs via env: GH_TOKEN (already set), UPSTREAM_OWNER, UPSTREAM_REPO

if [ -f FORK_MANIFEST.json ]; then
  # Validate manifest integrity
  SCHEMA_VER=$(jq -r '.schema_version // empty' FORK_MANIFEST.json)
  if [ -z "${SCHEMA_VER}" ]; then
    echo "::warning::FORK_MANIFEST.json missing schema_version"
  fi

  LAST_SHA=$(jq -r '.sync.last_synced_sha // empty' FORK_MANIFEST.json)
  if [ -n "${LAST_SHA}" ] && ! echo "${LAST_SHA}" | grep -qE '^[0-9a-f]{40}$'; then
    echo "::error::FORK_MANIFEST.json has invalid last_synced_sha: '${LAST_SHA}'. Manual correction required."
    exit 1
  fi

  EXPECTED_ID=$(jq -r '.upstream.repo_id // empty' FORK_MANIFEST.json)
  if [ -n "${EXPECTED_ID}" ]; then
    ACTUAL_ID=$(gh api "repos/${UPSTREAM_OWNER}/${UPSTREAM_REPO}" --jq '.id' 2>/dev/null || echo "")
    if [ -z "${ACTUAL_ID}" ]; then
      echo "::error::Upstream repo ${UPSTREAM_OWNER}/${UPSTREAM_REPO} is no longer accessible."
      exit 1
    elif [ "${ACTUAL_ID}" != "${EXPECTED_ID}" ]; then
      echo "::error::SECURITY ALERT: Upstream repo ID changed from ${EXPECTED_ID} to ${ACTUAL_ID}."
      echo "::error::This may indicate the repository was deleted and re-created (name squatting attack)."
      exit 1
    else
      echo "Upstream repo identity verified (ID: ${ACTUAL_ID})"
    fi
  else
    echo "No repo_id in manifest, skipping identity check."
  fi
fi
