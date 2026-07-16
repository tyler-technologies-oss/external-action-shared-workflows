#!/usr/bin/env bash
# Build one Claude review prompt per enabled review type.
# Prompt text is loaded from prompts/*.md (base.md + one file per review type)
# and assembled here with dynamic substitutions.
# Env: REVIEW_SCOPE, CUSTOM_REVIEW_INSTRUCTIONS, CONTEXT_FILES, PR_NUMBER.
# Writes per-type {type}_enabled flags and {type}_prompt heredocs to $GITHUB_OUTPUT.
set -euo pipefail

# Locate the prompt markdown files relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"

# ── Type registry ──────────────────────────────────────────────────────
declare -A TYPE_LABEL

TYPE_LABEL[supplychain]='Supply-Chain'
TYPE_LABEL[bash]='Bash/Shell'
TYPE_LABEL[javascript]='JavaScript'
TYPE_LABEL[docker]='Docker'
TYPE_LABEL[python]='Python'
TYPE_LABEL[go]='Go'
TYPE_LABEL[powershell]='PowerShell'
TYPE_LABEL[general]='General'

ALL_KNOWN_TYPES=("supplychain" "bash" "javascript" "docker" "python" "go" "powershell" "general")

# ── Parse REVIEW_SCOPE ────────────────────────────────────────────────
SCOPE_LOWER="${REVIEW_SCOPE,,}"
SCOPE_LOWER="${SCOPE_LOWER// /}"

if [[ "$SCOPE_LOWER" == "all" ]]; then
  ACTIVE_TYPES=("${ALL_KNOWN_TYPES[@]}")
else
  IFS=',' read -ra ACTIVE_TYPES <<< "$SCOPE_LOWER"
fi

# Validate types
for type in "${ACTIVE_TYPES[@]}"; do
  [[ -z "$type" ]] && continue
  if [[ -z "${TYPE_LABEL[$type]+isset}" ]]; then
    echo "ERROR: Unknown review type '${type}'. Valid types: supplychain, bash, javascript, docker, python, go, powershell, general, all" >&2
    exit 1
  fi
done

# ── Parse CUSTOM_REVIEW_INSTRUCTIONS into per-type buckets ────────────
declare -A CUSTOM_INSTRUCTIONS

if [[ -n "$CUSTOM_REVIEW_INSTRUCTIONS" ]]; then
  if echo "$CUSTOM_REVIEW_INSTRUCTIONS" | grep -qE '^\[.+\]'; then
    # Sectioned format: split by [type] headers
    current_section="general"
    while IFS= read -r line; do
      if [[ "$line" =~ ^\[([a-zA-Z]+)\]$ ]]; then
        current_section="${BASH_REMATCH[1],,}"
      else
        CUSTOM_INSTRUCTIONS[$current_section]+="${line}"$'\n'
      fi
    done <<< "$CUSTOM_REVIEW_INSTRUCTIONS"
  else
    # Legacy / no headers: apply to all types
    CUSTOM_INSTRUCTIONS[general]="$CUSTOM_REVIEW_INSTRUCTIONS"
  fi
fi

# ── Read CONTEXT_FILES and build project context block ────────────────
PROJECT_CONTEXT=""
MAX_CONTEXT_LINES=200

if [[ -n "${CONTEXT_FILES:-}" ]]; then
  # Normalize: replace commas with newlines, then iterate
  NORMALIZED_PATHS="${CONTEXT_FILES//,/$'\n'}"
  while IFS= read -r filepath; do
    filepath="$(echo "$filepath" | xargs)"   # trim whitespace
    [[ -z "$filepath" ]] && continue

    # Resolve relative to the checked-out repo root
    full_path="${GITHUB_WORKSPACE}/${filepath}"

    if [[ ! -s "$full_path" ]]; then
      echo "::warning::CONTEXT_FILES: '${filepath}' not found or empty (resolved to: ${full_path}) — skipping."
      continue
    fi

    file_line_count="$(wc -l < "$full_path")"
    if (( file_line_count > MAX_CONTEXT_LINES )); then
      content="$(head -n "$MAX_CONTEXT_LINES" "$full_path")"
      echo "::warning::CONTEXT_FILES: '${filepath}' has ${file_line_count} lines; truncated to ${MAX_CONTEXT_LINES}."
      trunc_note=" (truncated to ${MAX_CONTEXT_LINES} of ${file_line_count} lines)"
    else
      content="$(cat "$full_path")"
      trunc_note=""
    fi

    # Context content is inserted via literal parameter-expansion substitution
    # (never shell-expanded), so no escaping is needed — the raw file text is
    # emitted verbatim.

    PROJECT_CONTEXT+="### ${filepath}${trunc_note}"$'\n'
    PROJECT_CONTEXT+="${content}"$'\n\n'
  done <<< "$NORMALIZED_PATHS"
fi

# Pre-build the section block (empty string if no context files provided)
if [[ -n "$PROJECT_CONTEXT" ]]; then
  PROJECT_CONTEXT_SECTION="$(printf '%s\n\n%s\n\n%s' \
    '## Project Context' \
    'The following project documentation provides context for this review. Use this information to understand project conventions, architecture decisions, and team standards when evaluating changes.' \
    "$PROJECT_CONTEXT")"
else
  PROJECT_CONTEXT_SECTION=""
fi

# Helper: get custom instructions for a given type (type-specific + general)
get_custom() {
  local type="$1"
  local result=""
  if [[ -n "${CUSTOM_INSTRUCTIONS[$type]:-}" ]]; then
    result+="${CUSTOM_INSTRUCTIONS[$type]}"
  fi
  if [[ "$type" != "general" && -n "${CUSTOM_INSTRUCTIONS[general]:-}" ]]; then
    result+="${CUSTOM_INSTRUCTIONS[general]}"
  fi
  echo "$result"
}

# ── Prompt builder ────────────────────────────────────────────────────
# Assembles base.md + <type>.md + optional custom standards, substituting the
# placeholder tokens. File content is inserted with parameter expansion so it is
# never shell-expanded.
build_prompt() {
  local type="$1" label="${TYPE_LABEL[$type]}" custom base criteria prompt
  custom="$(get_custom "$type")"
  base="$(<"$PROMPTS_DIR/base.md")"
  criteria="$(<"$PROMPTS_DIR/$type.md")"
  prompt="${base//__TYPE_CRITERIA__/$criteria}"
  prompt="${prompt//__PROJECT_CONTEXT__/$PROJECT_CONTEXT_SECTION}"
  prompt="${prompt//__LABEL__/$label}"
  prompt="${prompt//__TYPE__/$type}"
  prompt="${prompt//__PR_NUMBER__/$PR_NUMBER}"
  if [[ -n "$custom" ]]; then
    prompt+=$'\n## Additional Team Standards\n\n'"$custom"$'\n'
  fi
  printf '%s' "$prompt"
}

# ── Emit outputs for each active type ────────────────────────────────
for type in "${ACTIVE_TYPES[@]}"; do
  [[ -z "$type" ]] && continue

  prompt="$(build_prompt "$type")"

  DELIMITER="EOF_${type^^}_PROMPT_${RANDOM}"
  {
    echo "${type}_enabled=true"
    echo "${type}_prompt<<${DELIMITER}"
    printf '%s\n' "${prompt}"
    echo "${DELIMITER}"
  } >> "$GITHUB_OUTPUT"
done

# Mark all unused types as disabled
for type in "${ALL_KNOWN_TYPES[@]}"; do
  if ! printf '%s\n' "${ACTIVE_TYPES[@]}" | grep -qx "$type"; then
    echo "${type}_enabled=false" >> "$GITHUB_OUTPUT"
  fi
done
