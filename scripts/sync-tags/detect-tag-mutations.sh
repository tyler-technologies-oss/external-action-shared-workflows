#!/usr/bin/env bash
set -euo pipefail

# Detect tag mutations -- tags that exist in both upstream and fork but point
# to different commits.
# Reads from /tmp/ files written by fetch-tags.sh.
# Outputs to $GITHUB_OUTPUT: mutation_count, mutated_tags

# Compare dereferenced commit SHAs for tags that exist in BOTH upstream and fork
# Using commit SHAs (not tag object SHAs) avoids false positives when
# fork has annotated tags and upstream has lightweight tags
comm -12 /tmp/upstream_tags.txt /tmp/fork_tags.txt > /tmp/common_tags.txt

MUTATED_TAGS=""
MUTATION_COUNT=0

while IFS= read -r TAG; do
  [ -z "${TAG}" ] && continue

  UPSTREAM_SHA=$(awk -v tag="${TAG}" '$2 == tag {print $1}' /tmp/upstream_tag_commits.txt)
  FORK_SHA=$(awk -v tag="${TAG}" '$2 == tag {print $1}' /tmp/fork_tag_commits.txt)

  if [ -n "${UPSTREAM_SHA}" ] && [ -n "${FORK_SHA}" ] && [ "${UPSTREAM_SHA}" != "${FORK_SHA}" ]; then
    echo "TAG MUTATION DETECTED: ${TAG} upstream=${UPSTREAM_SHA} fork=${FORK_SHA}"
    MUTATED_TAGS="${MUTATED_TAGS}${TAG} upstream=${UPSTREAM_SHA} fork=${FORK_SHA}\n"
    MUTATION_COUNT=$((MUTATION_COUNT + 1))
  fi
done < /tmp/common_tags.txt

echo "mutation_count=${MUTATION_COUNT}" >> "$GITHUB_OUTPUT"
DELIMITER="MUTATED_$(head -c 16 /dev/urandom | xxd -p)"
echo "mutated_tags<<${DELIMITER}" >> "$GITHUB_OUTPUT"
echo -e "${MUTATED_TAGS}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER}" >> "$GITHUB_OUTPUT"

echo "Tag mutations detected: ${MUTATION_COUNT}"
