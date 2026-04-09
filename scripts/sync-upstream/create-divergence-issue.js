module.exports = async ({ github, context }) => {
  const UPSTREAM_OWNER = process.env.UPSTREAM_OWNER;
  const UPSTREAM_REPO = process.env.UPSTREAM_REPO;
  const DEFAULT_BRANCH = process.env.DEFAULT_BRANCH;

  await github.rest.issues.create({
    owner: context.repo.owner,
    repo: context.repo.repo,
    title: '[Action Required] Upstream divergence detected',
    labels: ['upstream-sync', 'needs-security-review'],
    body: [
      '## Upstream Divergence Detected',
      '',
      `The \`upstream-tracking\` branch has diverged from \`${UPSTREAM_OWNER}/${UPSTREAM_REPO}@${DEFAULT_BRANCH}\` and cannot be fast-forward merged.`,
      '',
      '> **Security Note:** A non-fast-forward divergence may indicate that the upstream repository had its history rewritten (force-push). This is unusual for maintained projects and should be investigated before resolving.',
      '',
      '### Investigation Steps',
      '',
      '1. Check if the upstream repo was recently transferred, renamed, or recreated.',
      '2. Review the upstream commit history for signs of force-push or rebase.',
      '3. Compare the `FORK_MANIFEST.json` `repo_id` against the current upstream repo ID.',
      '',
      '### Manual Resolution Steps',
      '',
      '1. Fetch the upstream changes locally:',
      '   ```bash',
      `   git remote add upstream https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}.git`,
      `   git fetch upstream ${DEFAULT_BRANCH}`,
      '   ```',
      '2. Check out the `upstream-tracking` branch:',
      '   ```bash',
      '   git checkout upstream-tracking',
      '   ```',
      '3. Rebase or merge manually:',
      '   ```bash',
      `   git rebase upstream/${DEFAULT_BRANCH}`,
      '   ```',
      '4. Resolve any conflicts and push:',
      '   ```bash',
      '   git push origin upstream-tracking',
      '   ```',
    ].join('\n')
  });
};
