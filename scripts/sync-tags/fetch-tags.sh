#!/usr/bin/env bash
set -euo pipefail

# Parameterized tag fetcher -- called once for upstream and once for fork.
# Inputs via env:
#   REMOTE_URL     - git URL to ls-remote (e.g. https://github.com/owner/repo.git)
#   OUTPUT_PREFIX  - file prefix: "upstream" or "fork"

# Fetch full tag+SHA listing (all entries including ^{} dereferences)
git ls-remote --tags "${REMOTE_URL}" \
  > "/tmp/${OUTPUT_PREFIX}_tag_raw.txt"

# Tag object SHAs (excluding ^{})
grep -v '\^{}' "/tmp/${OUTPUT_PREFIX}_tag_raw.txt" > "/tmp/${OUTPUT_PREFIX}_tag_shas.txt"

# Extract tag names only
awk '{print $2}' "/tmp/${OUTPUT_PREFIX}_tag_shas.txt" | \
  sed 's|refs/tags/||' | \
  sort -V > "/tmp/${OUTPUT_PREFIX}_tags.txt"

# Build dereferenced SHA map: for each tag, prefer ^{} SHA (commit) over tag object SHA
# This resolves annotated tags to their underlying commit
> "/tmp/${OUTPUT_PREFIX}_tag_commits.txt"
while IFS= read -r TAG; do
  [ -z "${TAG}" ] && continue
  DEREF_SHA=$(awk -v ref="refs/tags/${TAG}^{}" '$2 == ref {print $1}' "/tmp/${OUTPUT_PREFIX}_tag_raw.txt")
  if [ -z "${DEREF_SHA}" ]; then
    DEREF_SHA=$(awk -v ref="refs/tags/${TAG}" '$2 == ref {print $1}' "/tmp/${OUTPUT_PREFIX}_tag_raw.txt")
  fi
  echo "${DEREF_SHA} ${TAG}" >> "/tmp/${OUTPUT_PREFIX}_tag_commits.txt"
done < "/tmp/${OUTPUT_PREFIX}_tags.txt"

echo "${OUTPUT_PREFIX^} tags found: $(wc -l < "/tmp/${OUTPUT_PREFIX}_tags.txt")"
cat "/tmp/${OUTPUT_PREFIX}_tags.txt"
