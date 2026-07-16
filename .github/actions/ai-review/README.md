# AI Supply-Chain Code Review Action

An AI-powered code review composite action that uses Claude (via Amazon Bedrock or the Anthropic API) to review the changes an untrusted upstream introduces when a fork is synced. It is the AI reviewer for the fork-sync security tooling: it reads the sync PR diff, posts inline comments on specific issues, and posts a summary comment with an overall assessment.

Its default review scope, `supplychain`, treats every change as potentially hostile and looks for the ways an upstream could exfiltrate secrets, execute unexpected code, or escalate privileges in CI.

This action is invoked by the reusable `security-scan.yml` workflow, which discovers the open sync PR and passes its number in via the `PR_NUMBER` input.

---

## How It Works

For a given PR number, the action:

1. **Masks auth secrets** so GitHub's log scrubber redacts them in all output.
2. **Builds one prompt per enabled review type** with type-specific standards.
3. **Cleans up previous bot review comments** from the prior run before posting new ones.
4. **Fetches the PR diff** for `PR_NUMBER` from the GitHub API and filters files by review type (`scripts/ai-review/filter_diffs.py`).
5. **Annotates line numbers** — each added/context diff line is tagged with its file line number so Claude posts accurate inline comments.
6. **Runs a Claude agent per review type** — each enabled type gets its own isolated session.
7. **Posts inline comments** on specific issues and a **summary comment** with issue counts and an approval status.

The composite `action.yml` is a thin orchestrator — each step invokes a standalone script in `scripts/security-scan/`, following this repo's no-inline-shell convention:

- `mask-sensitive-inputs.sh` — masks the auth secrets.
- `build-review-prompts.sh` — the per-type prompt builder.
- `detect-auth-mode.sh` — auth mode detection and model resolution.
- `cleanup-review-comments.sh` — removes previous bot review comments.
- `prefetch-pr-diffs.sh` — fetches the PR diff, then runs `filter_diffs.py`.
- `filter_diffs.py` — filters PR files by review type and annotates line numbers.

---

## Invocation Context (Important)

Unlike a typical `pull_request`-triggered reviewer, this action does **not** read the PR number from event context. The fork-sync security scan runs on a schedule, discovers the open sync PR itself, and passes the number explicitly. You **must** supply the `PR_NUMBER` input.

The action runs entirely from inputs — the calling job checks out the fork, checks out this action, and calls it with the discovered PR number.

---

## Authentication

You must provide **exactly one** authentication method. Providing zero or more than one is a validation error.

### Option 1: Bedrock via OIDC Role (`AWS_ROLE_ARN`)

Assume an IAM role via GitHub's OIDC provider. Most secure — no long-lived credentials stored. Requires an IAM role trusting GitHub OIDC with `bedrock:InvokeModel` permission, and `id-token: write` on the calling job. The action's OIDC credential step is `aws-actions/configure-aws-credentials` (SHA-pinned).

```yaml
with:
  AWS_ROLE_ARN: "arn:aws:iam::123456789012:role/my-bedrock-role"
  AWS_REGION: "us-east-1"
```

### Option 2: Bedrock API Key (`BEDROCK_API_KEY`)

A Bedrock long-term API key (bearer token). Simpler than OIDC — no IAM trust policy required — at the cost of a long-lived credential. Pass as a secret.

### Option 3: Anthropic API Key (`ANTHROPIC_API_KEY`)

The Anthropic API directly. When this mode is used the action auto-converts the Bedrock default model ID to the Anthropic format (e.g. `us.anthropic.claude-haiku-4-5-20251001-v1:0` → `claude-haiku-4-5-20251001`); override with `MODEL_ID`.

---

## Review Scope

`REVIEW_SCOPE` controls which file types are reviewed. Comma-separated type names, or `all`. **Default is `supplychain`.**

| Value | Files Reviewed |
|-------|---------------|
| `supplychain` (default) | `.github`/`workflows`/`actions`, `*.sh`, `*.js`/`*.ts`, `*.yml`/`*.yaml`, `package.json`, `Dockerfile`, `action.yml`/`action.yaml`, `CODEOWNERS`, `SECURITY.md` (lockfiles skipped) |
| `bash` | `*.sh`, `*.bash`, `Makefile` |
| `javascript` | `*.js`, `*.ts`, `*.mjs`, `*.cjs`, `package.json` |
| `docker` | `Dockerfile`, `*.dockerfile` |
| `python` | `*.py`, `requirements.txt`, `pyproject.toml`, `setup.py` |
| `go` | `*.go`, `go.mod` (`go.sum` skipped) |
| `powershell` | `*.ps1`, `*.psm1`, `*.psd1` |
| `general` | Everything not claimed by another active type |
| `all` | All of the above |

The language types (`javascript`, `docker`, `python`, `go`, `powershell`) match the shapes a
forked GitHub Action can take; `supplychain` is the default security lens and runs across all of
them. Set `SUPPLYCHAIN_MODEL_ID` (action) / `ai_supplychain_model_id` (workflow) to run the
security-critical `supplychain` review on a stronger model than the other types.

### Supply-Chain Standards

The `supplychain` reviewer specifically flags:

- GitHub Actions `uses:` references not pinned to a full 40-character commit SHA (and SHA changes on already-pinned actions that must be re-audited).
- Suspicious `run:` blocks: network egress (`curl`, `wget`, `nc`, `Invoke-WebRequest`), pipe-to-shell, base64/hex decode piped into an interpreter, `eval` on dynamic data, writes to system paths.
- Privilege escalation: increases in workflow `permissions:` (`write-all`, `contents: write`, `id-token: write`) and switches to the `pull_request_target` trigger.
- Secret handling: new secret references, environment dumping (`env`/`printenv`/`set`), credentials sent to external endpoints.
- Dependency changes: new deps, changed registries/install sources, `postinstall` scripts, unpinned version ranges.
- Obfuscation: minified/encoded blobs outside vendored/build dirs, unusual unicode/homoglyphs in identifiers.
- Fork tooling integrity: changes under `scripts/` (the fork-sync security tooling itself) get extra scrutiny.
- Manifest drift: changes to `FORK_MANIFEST.json`, `CODEOWNERS`, or `SECURITY.md` that reduce oversight.

---

## Inputs Reference

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `PR_NUMBER` | **Yes** | — | PR number to review. Supplied by the security scan that discovers the sync PR (no `pull_request` event context). |
| `AWS_ROLE_ARN` | One of three auth inputs | `""` | IAM role ARN for Bedrock via OIDC. |
| `BEDROCK_API_KEY` | One of three auth inputs | `""` | Bedrock long-term API key (bearer token). |
| `ANTHROPIC_API_KEY` | One of three auth inputs | `""` | Anthropic API key for direct API access. |
| `AWS_REGION` | No | `us-east-1` | AWS region for the Bedrock endpoint. |
| `MODEL_ID` | No | `""` | Model ID (Bedrock or Anthropic format). Falls back to `BEDROCK_MODEL_ID`. |
| `BEDROCK_MODEL_ID` | No | `us.anthropic.claude-haiku-4-5-20251001-v1:0` | Legacy model input. Prefer `MODEL_ID`. |
| `GITHUB_TOKEN` | **Yes** | — | Token with `pull-requests: write` and `contents: read`. |
| `MAX_TURNS` | No | `100` | Max Claude agent turns per review type (cap: 200). |
| `CUSTOM_REVIEW_INSTRUCTIONS` | No | `""` | Additional rules. Supports `[type]` section headers (e.g. `[supplychain]`, `[general]`). |
| `REVIEW_SCOPE` | No | `supplychain` | Comma-separated review types, or `all`. |
| `ENABLE_REVIEW` | No | `1` | Set to `0` to disable reviews without removing the workflow. |
| `CONTEXT_FILES` | No | `""` | Comma/newline-separated file paths injected as project context. Each capped at 200 lines. `CLAUDE.md` is auto-loaded. |

---

## Usage from `security-scan.yml`

The reusable `security-scan.yml` workflow includes an `ai-review` job that checks out the fork and this action, verifies at least one auth method is configured, then calls the action with the discovered PR number:

```yaml
      - name: AI code review
        if: steps.authcheck.outputs.have == 'true'
        uses: ./.shared-workflows/.github/actions/ai-review
        with:
          PR_NUMBER: ${{ needs.find-pr.outputs.pr_number }}
          REVIEW_SCOPE: ${{ inputs.ai_review_scope }}
          AWS_ROLE_ARN: ${{ inputs.ai_aws_role_arn }}
          BEDROCK_API_KEY: ${{ secrets.BEDROCK_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          MODEL_ID: ${{ inputs.ai_model_id }}
          GITHUB_TOKEN: ${{ github.token }}
```

The calling job must have these permissions:

```yaml
permissions:
  id-token: write       # required for Bedrock OIDC auth
  contents: read
  pull-requests: write
  issues: write
```

The `security-scan.yml` `workflow_call` interface exposes:

- Inputs: `enable_ai_review` (default `'true'`), `ai_review_scope` (default `'supplychain'`), `ai_model_id` (default `''`), `ai_aws_role_arn` (default `''`).
- Secrets (both optional): `BEDROCK_API_KEY`, `ANTHROPIC_API_KEY`.

If no auth is configured, the `ai-review` job emits a notice and skips — the scan does not fail.

---

## Pinned Actions

Every third-party action used by this composite is pinned to a full commit SHA:

- `aws-actions/configure-aws-credentials@7474bc4690e29a8392af63c5b98e7449536d5c3a # v4`
- `anthropics/claude-code-action@6e2bd52842c65e914eba5c8badd17560bd26b5de # v1.0.89`

`claude-code-action` is pinned to `v1.0.89` because `v1.0.90` breaks Bedrock SigV4 auth (see anthropics/claude-code-action#1193).

---

## Disabling Reviews Temporarily

Set `enable_ai_review: 'false'` on the `security-scan.yml` call, or `ENABLE_REVIEW: "0"` when calling the action directly.

---

## Troubleshooting

- **No AI review ran:** the `ai-review` job skips when no Bedrock/Anthropic auth is configured — check the `authcheck` step's notice.
- **`No authentication method provided` / `Multiple authentication methods provided`:** provide exactly one of `AWS_ROLE_ARN`, `BEDROCK_API_KEY`, `ANTHROPIC_API_KEY`.
- **Inline comments missing or in the summary instead:** only lines present in the PR diff range can receive inline comments; anything else is reported in the summary by design.
- **No comments posted:** verify `GITHUB_TOKEN` has `pull-requests: write` and the job has `issues: write`.
- **Model format warnings:** the action warns when the model ID format does not match the auth mode (Bedrock `us.anthropic.claude-*-v1:0` vs Anthropic `claude-*`).
