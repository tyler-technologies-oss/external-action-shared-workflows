#!/usr/bin/env bash
set -euo pipefail

# Create GitHub issues for new upstream tags that need security review.
# Inputs via env:
#   GH_TOKEN           - GitHub token for gh CLI
#   GITHUB_REPOSITORY  - owner/repo (auto-set by GHA)
#   UPSTREAM_OWNER     - upstream repository owner
#   UPSTREAM_REPO      - upstream repository name
# Outputs to $GITHUB_OUTPUT: issues_created

ISSUES_CREATED=0

while IFS= read -r RAW_TAG; do
  [ -z "${RAW_TAG}" ] && continue
  # Sanitize tag name (attacker-controlled upstream input)
  TAG=$(echo "${RAW_TAG}" | tr -cd 'a-zA-Z0-9._+-')

  ISSUE_TITLE="[Security Review] New upstream release: ${TAG}"

  EXISTING=$(gh issue list \
    --repo "${GITHUB_REPOSITORY}" \
    --search "${ISSUE_TITLE}" \
    --state all \
    --limit 1 \
    --json title \
    --jq '.[].title' 2>/dev/null || true)

  if [ "${EXISTING}" = "${ISSUE_TITLE}" ]; then
    echo "Issue already exists for tag ${TAG}, skipping"
    continue
  fi

  TAG_SHA=$(awk -v ref="refs/tags/${TAG}" '$2 == ref {print $1}' /tmp/upstream_tag_shas.txt)
  if [ -z "${TAG_SHA}" ]; then
    TAG_SHA="unknown"
  fi

  gh issue create \
    --repo "${GITHUB_REPOSITORY}" \
    --title "${ISSUE_TITLE}" \
    --label "upstream-release,needs-security-review" \
    --body "## New Upstream Release: ${TAG}

A new tag \`${TAG}\` has been detected in the upstream repository.

- **Upstream Release:** [${TAG}](https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases/tag/${TAG})
- **Tag:** \`${TAG}\`
- **Commit SHA:** \`${TAG_SHA}\`

### Security Review Checklist

- [ ] Review the changelog and release notes
- [ ] Diff against the previous tag for unexpected changes
- [ ] Check for new or modified dependencies
- [ ] Run CodeQL or static analysis scan on the release
- [ ] Check for added or modified binary files

### After Review: Create the Tag

Once the security review is complete, create and push the tag:

\`\`\`bash
git tag -a ${TAG} ${TAG_SHA} -m \"Reviewed: \$(date -u +%Y-%m-%dT%H:%M:%SZ) by @reviewer\"
git push origin ${TAG}
\`\`\`

> **Do NOT create the tag until the security review is complete.**"

  ISSUES_CREATED=$((ISSUES_CREATED + 1))
  echo "Created issue for tag ${TAG}"
done < /tmp/new_tags.txt

echo "issues_created=${ISSUES_CREATED}" >> "$GITHUB_OUTPUT"
