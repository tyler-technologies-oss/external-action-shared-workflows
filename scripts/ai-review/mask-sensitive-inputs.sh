#!/usr/bin/env bash
set -euo pipefail

# Mask Bedrock/Anthropic API keys so GitHub's log scrubber redacts them.
# Env: _BEDROCK_KEY, _ANTHROPIC_KEY (passed by the calling step).

if [[ -n "$_BEDROCK_KEY" ]]; then
  echo "::add-mask::$_BEDROCK_KEY"
fi
if [[ -n "$_ANTHROPIC_KEY" ]]; then
  echo "::add-mask::$_ANTHROPIC_KEY"
fi
