#!/usr/bin/env bash
set -euo pipefail

# Scan the ADDED lines of the sync diff for dangerous invisible / bidirectional
# Unicode (Trojan Source: bidi controls, zero-width chars, BOM). These can make
# code read differently than it executes and are stripped from the text an AI
# reviewer sees, so this deterministic check owns them.
#
# Informational: reports findings to the log / step summary and to $GITHUB_OUTPUT;
# exits 1 when findings exist so the check surfaces red, but the workflow does NOT
# fold it into the merge-gating aggregate.
#
# Env: either BASE_SHA + HEAD_SHA (a pre-resolved range, e.g. for tests), or
# DEFAULT_BRANCH (the script derives the range against origin/upstream-tracking,
# same as generate-diff-analysis.sh).
# Outputs to $GITHUB_OUTPUT: unicode_count, unicode_findings.

# PCRE \x{...} codepoint matching needs a UTF-8 locale.
export LC_ALL="${LC_ALL:-C.UTF-8}"

# Resolve the diff range. Prefer explicit SHAs; otherwise derive from the branches.
if [ -z "${BASE_SHA:-}" ] || [ -z "${HEAD_SHA:-}" ]; then
  : "${DEFAULT_BRANCH:?set BASE_SHA+HEAD_SHA or DEFAULT_BRANCH}"
  git fetch --quiet origin upstream-tracking "${DEFAULT_BRANCH}"
  BASE_SHA="$(git rev-parse "origin/${DEFAULT_BRANCH}")"
  HEAD_SHA="$(git rev-parse origin/upstream-tracking)"
fi

# Fixed danger set (hex codepoint -> human name).
CODEPOINTS=(200B 200C 200D 200E 200F 202A 202B 202C 202D 202E 2060 2066 2067 2068 2069 FEFF)
declare -A CP_NAME=(
  [200B]="ZERO WIDTH SPACE"            [200C]="ZERO WIDTH NON-JOINER"
  [200D]="ZERO WIDTH JOINER"           [200E]="LEFT-TO-RIGHT MARK"
  [200F]="RIGHT-TO-LEFT MARK"          [202A]="LEFT-TO-RIGHT EMBEDDING"
  [202B]="RIGHT-TO-LEFT EMBEDDING"     [202C]="POP DIRECTIONAL FORMATTING"
  [202D]="LEFT-TO-RIGHT OVERRIDE"      [202E]="RIGHT-TO-LEFT OVERRIDE"
  [2060]="WORD JOINER"                 [2066]="LEFT-TO-RIGHT ISOLATE"
  [2067]="RIGHT-TO-LEFT ISOLATE"       [2068]="FIRST STRONG ISOLATE"
  [2069]="POP DIRECTIONAL ISOLATE"     [FEFF]="ZERO WIDTH NO-BREAK SPACE (BOM)"
)

DIFF="$(git diff --no-color "${BASE_SHA}...${HEAD_SHA}")"

findings=""
current_file=""
while IFS= read -r line; do
  case "$line" in
    "+++ b/"*) current_file="${line#+++ b/}" ;;
    "+++ "*)   current_file="${line#+++ }" ;;
    "+"*)
      content="${line:1}"   # strip the leading '+'
      for cp in "${CODEPOINTS[@]}"; do
        if printf '%s' "$content" | grep -qP "\\x{${cp}}"; then
          findings+="${current_file}: U+${cp} ${CP_NAME[$cp]}"$'\n'
        fi
      done
      ;;
  esac
done <<< "$DIFF"

# One line per (file, codepoint).
findings="$(printf '%s' "$findings" | sed '/^$/d' | sort -u)"
count=0
[ -n "$findings" ] && count="$(printf '%s\n' "$findings" | grep -c .)"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "unicode_count=${count}" >> "$GITHUB_OUTPUT"
  delim="UNI_$(head -c 16 /dev/urandom | xxd -p)"
  echo "unicode_findings<<${delim}" >> "$GITHUB_OUTPUT"
  printf '%s\n' "${findings:-none}" >> "$GITHUB_OUTPUT"
  echo "${delim}" >> "$GITHUB_OUTPUT"
fi

if [ "$count" -gt 0 ]; then
  echo "::warning::Dangerous invisible/bidirectional Unicode found in ${count} location(s)."
  printf '%s\n' "$findings"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "### Unicode scan: ${count} finding(s)"
      echo ""
      printf '%s\n' "$findings" | sed 's/^/- /'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 1
fi

echo "Unicode scan: clean (no dangerous invisible/bidirectional characters in added lines)."
exit 0
