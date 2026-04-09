module.exports = async ({ github, context }) => {
  const findings = [];

  if (process.env.CHANGED_REFS && process.env.CHANGED_REFS !== 'None') {
    findings.push({
      severity: 'CRITICAL',
      title: 'SHA-changed `uses:` references',
      detail: process.env.CHANGED_REFS.trim(),
      why: 'A `uses:` reference points to the same action but a different commit SHA. This is the primary vector for supply-chain attacks on composite actions — an attacker replaces a pinned SHA with one containing malicious code.'
    });
  }

  if (process.env.RUN_MOD && process.env.RUN_MOD.includes('MODIFIED')) {
    findings.push({
      severity: 'HIGH',
      title: 'Modified `run:` block content',
      detail: process.env.RUN_MOD,
      why: 'Shell commands within existing `run:` blocks have been changed. Review the diff carefully for injected commands (e.g., `curl | bash`, encoded payloads, exfiltration of secrets).'
    });
  }

  if (process.env.UNPINNED && process.env.UNPINNED !== 'None') {
    findings.push({
      severity: 'HIGH',
      title: 'Unpinned `uses:` references',
      detail: process.env.UNPINNED.trim(),
      why: 'New action references are not pinned to a full commit SHA. Tag-pinned or branch-pinned references can be silently replaced by the action owner.'
    });
  }

  if (process.env.USING_CHANGE && process.env.USING_CHANGE !== 'None') {
    findings.push({
      severity: 'HIGH',
      title: 'Action type (`using:`) changed',
      detail: process.env.USING_CHANGE.trim(),
      why: 'The action runtime type has changed (e.g., `node20` to `composite`). A switch to `composite` introduces `run:` and `uses:` capabilities that did not previously exist.'
    });
  }

  if (findings.length === 0) return;

  const prRef = `#${process.env.PR_NUMBER}`;
  const findingsBody = findings.map(f =>
    `### ${f.severity}: ${f.title}\n\n` +
    `**Why this matters:** ${f.why}\n\n` +
    `\`\`\`\n${f.detail}\n\`\`\``
  ).join('\n\n---\n\n');

  const body = [
    `## Composite Action Security Alert`,
    ``,
    `The upstream sync PR (${prRef}) contains changes to \`action.yml\` that require security review before merge.`,
    ``,
    `**Findings: ${findings.length}**`,
    ``,
    findingsBody,
    ``,
    `---`,
    ``,
    `### Required Actions`,
    ``,
    `1. **Do not merge** the sync PR until all findings are reviewed`,
    `2. Verify each changed SHA against the upstream action's release history`,
    `3. Review all modified shell content for malicious commands`,
    `4. If any finding is unexplained, treat it as a potential compromise`,
  ].join('\n');

  await github.rest.issues.create({
    owner: context.repo.owner,
    repo: context.repo.repo,
    title: `[Security Alert] Composite action changes in upstream sync`,
    labels: ['security-alert', 'needs-security-review'],
    body: body,
  });
};
