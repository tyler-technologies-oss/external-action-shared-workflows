#!/usr/bin/env bash
# Detect auth mode (bedrock vs anthropic) and resolve the model ID.
# Env: AWS_ROLE_ARN, BEDROCK_API_KEY, ANTHROPIC_API_KEY, MODEL_ID, BEDROCK_MODEL_ID.
# Writes auth_mode/use_bedrock/resolved_model to $GITHUB_OUTPUT and API keys to $GITHUB_ENV.
set -euo pipefail

# Validate: exactly one auth method must be provided
AUTH_COUNT=0
[[ -n "$AWS_ROLE_ARN" ]] && AUTH_COUNT=$((AUTH_COUNT + 1))
[[ -n "$BEDROCK_API_KEY" ]] && AUTH_COUNT=$((AUTH_COUNT + 1))
[[ -n "$ANTHROPIC_API_KEY" ]] && AUTH_COUNT=$((AUTH_COUNT + 1))

if [[ "$AUTH_COUNT" -eq 0 ]]; then
  echo "::error::No authentication method provided. Set exactly one of: AWS_ROLE_ARN (Bedrock OIDC), BEDROCK_API_KEY (Bedrock API key), or ANTHROPIC_API_KEY (Anthropic API)."
  exit 1
fi
if [[ "$AUTH_COUNT" -gt 1 ]]; then
  echo "::error::Multiple authentication methods provided. Use exactly one of: AWS_ROLE_ARN, BEDROCK_API_KEY, or ANTHROPIC_API_KEY."
  exit 1
fi

# Determine auth mode
if [[ -n "$AWS_ROLE_ARN" ]]; then
  AUTH_MODE="bedrock-role"
  USE_BEDROCK="true"
elif [[ -n "$BEDROCK_API_KEY" ]]; then
  AUTH_MODE="bedrock-key"
  USE_BEDROCK="true"
else
  AUTH_MODE="anthropic"
  USE_BEDROCK="false"
fi

# Resolve model: MODEL_ID > BEDROCK_MODEL_ID (with auto-conversion for Anthropic path)
if [[ -n "$MODEL_ID" ]]; then
  RESOLVED_MODEL="$MODEL_ID"
elif [[ "$AUTH_MODE" == "anthropic" && "$BEDROCK_MODEL_ID" == us.anthropic.* ]]; then
  # Caller left MODEL_ID empty and BEDROCK_MODEL_ID has the Bedrock default.
  # Auto-convert: strip region prefix (us.) and Bedrock suffix (-v1:0 or -v2:0 etc.)
  RESOLVED_MODEL=$(echo "$BEDROCK_MODEL_ID" | sed 's/^us\.//; s/^anthropic\.//; s/-v[0-9][0-9]*:[0-9]*$//')
  echo "::notice::No MODEL_ID set for Anthropic API auth. Auto-converted Bedrock default to: ${RESOLVED_MODEL}"
else
  RESOLVED_MODEL="$BEDROCK_MODEL_ID"
fi

# Warn if model format looks wrong for the chosen auth mode
if [[ "$AUTH_MODE" == bedrock-* && "$RESOLVED_MODEL" == claude-* ]]; then
  echo "::warning::Model '${RESOLVED_MODEL}' looks like Anthropic API format but auth mode is Bedrock. Expected format: us.anthropic.claude-*"
elif [[ "$AUTH_MODE" == "anthropic" ]] && [[ "$RESOLVED_MODEL" == *anthropic.* || "$RESOLVED_MODEL" == us.* || "$RESOLVED_MODEL" == eu.* ]]; then
  echo "::warning::Model '${RESOLVED_MODEL}' looks like Bedrock format but auth mode is Anthropic API. Expected format: claude-*"
fi

echo "auth_mode=${AUTH_MODE}" >> "$GITHUB_OUTPUT"
echo "use_bedrock=${USE_BEDROCK}" >> "$GITHUB_OUTPUT"
echo "resolved_model=${RESOLVED_MODEL}" >> "$GITHUB_OUTPUT"

# Export API keys via GITHUB_ENV so all subsequent steps inherit them.
# Values are already masked by the 'Mask Sensitive Inputs' step.
# Always write both vars (empty when unused) to clear any stale values
# left by previous runs on persistent/self-hosted runners.
if [[ "$AUTH_MODE" == "bedrock-key" ]]; then
  echo "AWS_BEARER_TOKEN_BEDROCK=${BEDROCK_API_KEY}" >> "$GITHUB_ENV"
fi
# Do NOT write AWS_BEARER_TOKEN_BEDROCK= for non-bedrock-key modes.
# Claude Code treats the env var being present (even empty) as a signal
# to use bearer token auth, sending "Authorization: Bearer" with no token.
if [[ "$AUTH_MODE" == "anthropic" ]]; then
  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> "$GITHUB_ENV"
fi
# Do NOT write ANTHROPIC_API_KEY= for non-anthropic modes — setting the
# env var to any value (even empty) causes Claude Code to attempt Anthropic
# API auth instead of Bedrock Sig V4.
