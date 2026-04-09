module.exports = async ({ github, context }) => {
  const prNumber = parseInt(process.env.PR_NUMBER, 10);
  let body = `## Security Diff Summary

| Metric | Count |
|--------|-------|
| Files changed | ${process.env.FILES_CHANGED} |
| Lines added | ${process.env.LINES_ADDED} |
| Lines removed | ${process.env.LINES_REMOVED} |

### Action Manifest Changes
\`${process.env.MANIFEST_CHANGES}\`

### Script Changes
\`${process.env.SCRIPT_CHANGES}\`

### Binary Files
\`${process.env.BINARY_CHANGES}\`
`;

  if (process.env.HAS_COMPOSITE === 'true') {
    body += `
### Composite Action Analysis

**Action type (\`using:\`) change:** \`${process.env.COMPOSITE_USING}\`

**Added \`uses:\` references:**
\`\`\`
${process.env.COMPOSITE_ADDED_USES}
\`\`\`

**Removed \`uses:\` references:**
\`\`\`
${process.env.COMPOSITE_REMOVED_USES}
\`\`\`

**SHA-changed \`uses:\` references (same action, different ref):**
\`\`\`
${process.env.COMPOSITE_CHANGED_REFS}
\`\`\`

**Added \`run:\` steps:**
\`\`\`
${process.env.COMPOSITE_ADDED_RUNS}
\`\`\`

**\`run:\` block content:** \`${process.env.COMPOSITE_RUN_MOD}\`

**Unpinned references (not SHA-pinned):**
\`\`\`
${process.env.COMPOSITE_UNPINNED}
\`\`\`
`;
  }

  const comments = await github.rest.issues.listComments({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: prNumber,
  });

  const marker = '## Security Diff Summary';
  const existing = comments.data.find(c =>
    c.user.type === 'Bot' && c.body.includes(marker)
  );

  if (existing) {
    await github.rest.issues.updateComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      comment_id: existing.id,
      body: body,
    });
  } else {
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: prNumber,
      body: body,
    });
  }
};
