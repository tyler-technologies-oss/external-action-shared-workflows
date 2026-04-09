#!/usr/bin/env bash
set -euo pipefail

# Verify pinned tags in FORK_MANIFEST.json against live fork tag SHAs.
# Reads FORK_MANIFEST.json and /tmp/ files written by fetch-tags.sh.
# Outputs to $GITHUB_OUTPUT: drift_count, drift_details

DRIFT_COUNT=0
DRIFT_DETAILS=""

if [ ! -f FORK_MANIFEST.json ]; then
  echo "No FORK_MANIFEST.json found, skipping pinned tag verification."
  echo "drift_count=0" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Fail closed: if fork tag data is unavailable, drift detection cannot run
if [ ! -s /tmp/fork_tag_commits.txt ]; then
  echo "::error::Fork tag commit data not available. Cannot perform drift detection."
  exit 1
fi

# Validate pinned_tags is a well-formed array
if ! jq -e '.pinned_tags | type == "array"' FORK_MANIFEST.json > /dev/null 2>&1; then
  echo "::warning::FORK_MANIFEST.json has missing or malformed pinned_tags field"
  echo "drift_count=0" >> "$GITHUB_OUTPUT"
  exit 0
fi

PINNED_COUNT=$(jq '.pinned_tags | length' FORK_MANIFEST.json)
echo "Pinned tags in manifest: ${PINNED_COUNT}"

for i in $(seq 0 $((PINNED_COUNT - 1))); do
  TAG=$(jq -r ".pinned_tags[${i}].tag // empty" FORK_MANIFEST.json)
  MANIFEST_SHA=$(jq -r ".pinned_tags[${i}].fork_sha // empty" FORK_MANIFEST.json)

  [ -z "${TAG}" ] && continue
  [ -z "${MANIFEST_SHA}" ] && continue

  # Validate manifest SHA format
  if ! echo "${MANIFEST_SHA}" | grep -qE '^[0-9a-f]{40}$'; then
    echo "::warning::Manifest has invalid SHA for tag ${TAG}: '${MANIFEST_SHA}'"
    continue
  fi

  # Get live fork tag SHA (deref-first for annotated tags)
  LIVE_SHA=$(awk -v tag="${TAG}" '$2 == tag {print $1}' /tmp/fork_tag_commits.txt)

  if [ -z "${LIVE_SHA}" ]; then
    echo "::warning::Pinned tag ${TAG} not found in fork (may have been deleted)"
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    DRIFT_DETAILS="${DRIFT_DETAILS}${TAG} manifest=${MANIFEST_SHA} live=MISSING\n"
    continue
  fi

  if [ "${LIVE_SHA}" != "${MANIFEST_SHA}" ]; then
    echo "FORK TAG DRIFT: ${TAG} manifest=${MANIFEST_SHA} live=${LIVE_SHA}"
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    DRIFT_DETAILS="${DRIFT_DETAILS}${TAG} manifest=${MANIFEST_SHA} live=${LIVE_SHA}\n"
  else
    echo "Pinned tag ${TAG} verified: ${LIVE_SHA:0:12}"
  fi
done

echo "drift_count=${DRIFT_COUNT}" >> "$GITHUB_OUTPUT"
DELIMITER="DRIFT_$(head -c 16 /dev/urandom | xxd -p)"
echo "drift_details<<${DELIMITER}" >> "$GITHUB_OUTPUT"
echo -e "${DRIFT_DETAILS}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER}" >> "$GITHUB_OUTPUT"
