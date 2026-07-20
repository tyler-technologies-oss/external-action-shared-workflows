# Follow-ups

Deferred work identified while building and live-testing the AI supply-chain reviewer
(PR #6). Nothing here blocks the reviewer shipping — it works today (findings post as PR
comments). These are enhancements and hardening.

---

## 1. GitHub App for event-firing sync PRs — unlocks inline AI review comments

### Why this is needed

The AI reviewer posts its findings as normal PR **comments**, not **inline** (line-anchored)
review comments. This is architectural, not a model or version limitation:

- `anthropics/claude-code-action` only registers its inline-comment MCP server
  (`mcp__github_inline_comment__create_inline_comment`) when the run is in a **real
  `pull_request` event context** (`context.isPR`). Confirmed in the action source
  (`src/mcp/install-mcp-server.ts`).
- Our security scan runs via `workflow_run` / `schedule`, and the sync PR is created with the
  workflow's **`GITHUB_TOKEN`**. GitHub deliberately does **not** fire `pull_request` (or
  `workflow_run`) events for anything `GITHUB_TOKEN` creates — loop prevention. So there is
  never a PR event context, the inline server never loads, and the model falls back to a
  regular comment.

To get inline comments we need **both**:
1. Sync PRs created by a credential that **does** fire events (a GitHub App installation token), and
2. The AI review triggered **on `pull_request`** (so `context.isPR` is true).

### Recommended: one org-owned GitHub App for all of OSS

A single App owned by `tyler-technologies-oss`, installed across the fork repos, is the clean
way to do this — better than per-repo PATs:

- Tied to the org (a bot), not a person; clean `app-name[bot]` attribution.
- Tokens are **minted per run and expire (~1h)** — no long-lived secret to rotate per repo.
- **Fine-grained** permissions; one private key to protect instead of many PATs.
- App-created PRs are **not** the `GITHUB_TOKEN`, so they **fire `pull_request`** events.

### Setup steps

1. **Create the App** (org `tyler-technologies-oss`). Repository permissions:
   - Contents: **Read & write** (push the `upstream-tracking` branch)
   - Pull requests: **Read & write** (open + comment)
   - Issues: **Read & write** (security-alert issues)
   - Workflows: **Read & write** — required if a sync ever updates files under
     `.github/workflows/` (neither `GITHUB_TOKEN` nor a token lacking this can push workflow
     changes). No webhook/event subscriptions are needed for token minting.
2. **Generate a private key** and note the **App ID**.
3. **Install the App** on the org (all repos, or the fork set).
4. **Add org secrets** (once, visible to the fork repos): `FORK_SYNC_APP_ID`,
   `FORK_SYNC_APP_PRIVATE_KEY`.
5. **Mint an installation token in the sync workflow** and use it for the branch push + PR
   creation (SHA-pin the action per repo convention):
   ```yaml
   - uses: actions/create-github-app-token@<pinned-sha>  # pin latest
     id: app-token
     with:
       app-id: ${{ secrets.FORK_SYNC_APP_ID }}
       private-key: ${{ secrets.FORK_SYNC_APP_PRIVATE_KEY }}
   # then, in scripts/sync-upstream/create-sync-pr.sh, use:
   #   GH_TOKEN: ${{ steps.app-token.outputs.token }}
   ```
   The checkout that pushes `upstream-tracking` must also use this token.
6. **Add a `pull_request`-triggered AI review.** Keep the deterministic scans
   (dependency-review, diff-summary, unicode, codeql) on `workflow_run`/schedule as-is. Add a
   separate review path triggered `on: pull_request` (head `upstream-tracking`). Running in a
   PR event context makes `context.isPR` true → the inline MCP server loads → inline comments
   post. No prompt changes needed (the prompt already instructs inline-first).
7. **Verify:** trigger a sync so the App opens/updates the PR → confirm a `pull_request` run
   fires → confirm inline comments appear on the changed lines.

### Loop prevention

- Now that App-created PRs fire events, ensure the `pull_request` review job **only comments**
  — it must not push commits that would re-fire `pull_request`. The cron-driven sync stays the
  only creator of branches/PRs. Add a `concurrency` group if needed.

### Security notes

- The App private key is a powerful **org-wide** credential — store it as an org secret with
  limited repo visibility and rotate periodically. It is one secret to guard instead of many
  PATs (the security win).
- Grant **least privilege** — only the four permissions above.
- The `pull_request` review reads the **synced (untrusted) upstream content** in PR context. It
  is read-only (Read/Grep + the model, no execution), so low risk — but it is a conscious shift
  from fork-sync's "minimize workflows on synced content" posture. **Do NOT use
  `pull_request_target`** for this: that runs with repository secrets against the untrusted head
  and is a classic exfiltration vector.

### Recommended alongside

- Set `ai_supplychain_model_id: us.anthropic.claude-sonnet-4-6` for the security-critical
  supplychain review. Sonnet 4.6 is serverless/auto-enabled on Bedrock and reviews noticeably
  better than the Haiku default (which is fine as the baseline for the other types). Note:
  Sonnet 4.5 and Opus 4.1 are AWS-Marketplace-gated in the account and return 403 in the action.

---

## 2. Caller template (`external-action-setup`)

The per-fork caller template must:
- **Pass secrets explicitly** — `secrets: inherit` does **not** cross organizations, so a fork
  in another org gets no `BEDROCK_API_KEY`/`ANTHROPIC_API_KEY` and the AI review silently skips.
  Use:
  ```yaml
  secrets:
    BEDROCK_API_KEY: ${{ secrets.BEDROCK_API_KEY }}
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  ```
- Add a **`workflow_dispatch`** trigger so maintainers can re-run the scan on demand.
- Optionally set `ai_supplychain_model_id` (see above).

## 3. Deterministic checks (not the AI's job)

- **Dependency-provenance / typosquat linter** — flag new git/URL deps, changed registries,
  install-time scripts, and edit-distance-close package names. Complements `dependency-review`
  (which covers known-vuln, not provenance).
- **`dist/` rebuild-and-diff** — rebuild the JS action bundle from source and diff against the
  committed `dist/` to catch a bundle that doesn't match its source. Hardest item (per-fork
  build command); the AI reviewer only flags a suspected mismatch today.

## 4. CI hygiene

- Add **shellcheck** to CI for `scripts/**/*.sh`.
