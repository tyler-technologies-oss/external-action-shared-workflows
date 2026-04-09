#!/usr/bin/env bash
set -euo pipefail

# Create a pull request for upstream sync
# Inputs via env: GH_TOKEN (already set), REPO, DEFAULT_BRANCH,
#   UPSTREAM_OWNER, UPSTREAM_REPO, DIFF_STATS, SECURITY_FILES,
#   HAS_SECURITY_CHANGES, CURRENT_SHA, UPSTREAM_SHA
# Outputs to $GITHUB_OUTPUT: pr_created, pr_number

EXISTING_PR=$(gh pr list \
  --repo "${REPO}" \
  --base "${DEFAULT_BRANCH}" \
  --head upstream-tracking \
  --state open \
  --json number \
  --jq '.[0].number // empty')

if [ -n "${EXISTING_PR}" ]; then
  echo "Sync PR already exists (#${EXISTING_PR}), skipping creation."
  echo "pr_created=true" >> "$GITHUB_OUTPUT"
  echo "pr_number=${EXISTING_PR}" >> "$GITHUB_OUTPUT"
  exit 0
fi

cat > /tmp/pr_body.md << PR_BODY
## Upstream Sync

Syncing changes from [\`${UPSTREAM_OWNER}/${UPSTREAM_REPO}@${DEFAULT_BRANCH}\`](https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}).

### Diff Stats

\`\`\`
${DIFF_STATS}
\`\`\`

### Security-Relevant Files

\`\`\`
${SECURITY_FILES}
\`\`\`

### Upstream Comparison

[\`${CURRENT_SHA}...${UPSTREAM_SHA}\`](https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/compare/${CURRENT_SHA}...${UPSTREAM_SHA})

### Review Checklist

- [ ] Check \`action.yml\` / \`action.yaml\` for unexpected changes
- [ ] Check for new or modified dependencies
- [ ] Check for obfuscated or minified code changes
- [ ] Run security scan on changed files
- [ ] Verify no secrets or credentials exposed

#### Composite Action Checks (if applicable)
- [ ] Verify \`uses:\` references have not changed to untrusted actions
- [ ] Verify all \`uses:\` references are SHA-pinned (not tag-pinned)
- [ ] Check for new \`run:\` steps that execute shell commands
- [ ] Verify \`using:\` field has not changed (e.g., node20 to composite)
- [ ] Check for references to actions not forked into the org
PR_BODY

LABELS="upstream-sync,needs-security-review"
if [ "${HAS_SECURITY_CHANGES}" = "true" ]; then
  LABELS="${LABELS},security-alert"
fi

PR_URL=$(gh pr create \
  --repo "${REPO}" \
  --base "${DEFAULT_BRANCH}" \
  --head upstream-tracking \
  --title "chore: sync upstream ${UPSTREAM_OWNER}/${UPSTREAM_REPO}" \
  --label "${LABELS}" \
  --body-file /tmp/pr_body.md)

PR_NUM=$(echo "${PR_URL}" | grep -oE '[0-9]+$')
echo "pr_created=true" >> "$GITHUB_OUTPUT"
echo "pr_number=${PR_NUM}" >> "$GITHUB_OUTPUT"
echo "Created PR #${PR_NUM}"
