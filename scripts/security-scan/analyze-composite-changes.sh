#!/usr/bin/env bash
set -euo pipefail

ACTION_DIFF=$(git diff "${BASE_SHA}...${HEAD_SHA}" -- 'action.yml' 'action.yaml' || true)

if [ -z "${ACTION_DIFF}" ]; then
  echo "has_composite_findings=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "has_composite_findings=true" >> "$GITHUB_OUTPUT"

# Detect using: field changes (action type change)
USING_CHANGE=$(echo "${ACTION_DIFF}" | grep -E '^[+-][[:space:]]*using[[:space:]]*:' | grep -vE '^(\+{3}|-{3})' || true)
DELIMITER_UC="USING_$(head -c 8 /dev/urandom | xxd -p)"
echo "using_change<<${DELIMITER_UC}" >> "$GITHUB_OUTPUT"
printf '%s\n' "${USING_CHANGE:-None}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER_UC}" >> "$GITHUB_OUTPUT"

# Detect added uses: references (exclude diff headers and comments)
ADDED_USES=$(echo "${ACTION_DIFF}" | grep -E '^\+' | grep -v '^+++' | grep -v '^+[[:space:]]*#' | grep '[[:space:]]*uses[[:space:]]*:' | sed 's/^\+//' || true)
DELIMITER_AU="USES_$(head -c 8 /dev/urandom | xxd -p)"
echo "added_uses<<${DELIMITER_AU}" >> "$GITHUB_OUTPUT"
printf '%s\n' "${ADDED_USES:-None}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER_AU}" >> "$GITHUB_OUTPUT"

# Detect removed uses: references
REMOVED_USES=$(echo "${ACTION_DIFF}" | grep -E '^\-' | grep -v '^---' | grep -v '^\-[[:space:]]*#' | grep '[[:space:]]*uses[[:space:]]*:' | sed 's/^\-//' || true)
DELIMITER_RU="RUSES_$(head -c 8 /dev/urandom | xxd -p)"
echo "removed_uses<<${DELIMITER_RU}" >> "$GITHUB_OUTPUT"
printf '%s\n' "${REMOVED_USES:-None}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER_RU}" >> "$GITHUB_OUTPUT"

# Detect SHA-changed uses: references (same action, different ref)
CHANGED_REFS=""
if [ "${ADDED_USES:-None}" != "None" ] && [ "${REMOVED_USES:-None}" != "None" ]; then
  while IFS= read -r added_line; do
    [ -z "${added_line}" ] && continue
    added_name=$(echo "${added_line}" | sed -n 's/.*uses:[[:space:]]*\([a-zA-Z0-9._/-]*\)@.*/\1/p')
    [ -z "${added_name}" ] && continue
    added_ref=$(echo "${added_line}" | sed -n 's/.*@\([^[:space:]]*\).*/\1/p')
    while IFS= read -r removed_line; do
      [ -z "${removed_line}" ] && continue
      removed_name=$(echo "${removed_line}" | sed -n 's/.*uses:[[:space:]]*\([a-zA-Z0-9._/-]*\)@.*/\1/p')
      removed_ref=$(echo "${removed_line}" | sed -n 's/.*@\([^[:space:]]*\).*/\1/p')
      if [ "${added_name}" = "${removed_name}" ] && [ "${added_ref}" != "${removed_ref}" ]; then
        CHANGED_REFS=$(printf '%s%s: %s -> %s\n' "${CHANGED_REFS}" "${added_name}" "${removed_ref}" "${added_ref}")
      fi
    done <<< "${REMOVED_USES}"
  done <<< "${ADDED_USES}"
fi
DELIMITER_CR="CREF_$(head -c 8 /dev/urandom | xxd -p)"
echo "changed_refs<<${DELIMITER_CR}" >> "$GITHUB_OUTPUT"
printf '%s\n' "${CHANGED_REFS:-None}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER_CR}" >> "$GITHUB_OUTPUT"

# Detect added run: steps
ADDED_RUNS=$(echo "${ACTION_DIFF}" | grep -E '^\+' | grep -v '^+++' | grep -v '^+[[:space:]]*#' | grep '[[:space:]]*run[[:space:]]*:' | sed 's/^\+//' || true)
DELIMITER_AR="RUNS_$(head -c 8 /dev/urandom | xxd -p)"
echo "added_runs<<${DELIMITER_AR}" >> "$GITHUB_OUTPUT"
printf '%s\n' "${ADDED_RUNS:-None}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER_AR}" >> "$GITHUB_OUTPUT"

# Detect modified run: block content
# Compares run: block content between old and new action file versions
RUN_MOD_SUMMARY="No run: blocks found"
for af in action.yml action.yaml; do
  OLD_CONTENT=$(git show "${BASE_SHA}:${af}" 2>/dev/null || true)
  NEW_CONTENT=$(git show "${HEAD_SHA}:${af}" 2>/dev/null || true)
  [ -z "${OLD_CONTENT}" ] && [ -z "${NEW_CONTENT}" ] && continue

  OLD_RUN_COUNT=$(printf '%s\n' "${OLD_CONTENT}" | grep -c '[[:space:]]run:' || echo "0")
  NEW_RUN_COUNT=$(printf '%s\n' "${NEW_CONTENT}" | grep -c '[[:space:]]run:' || echo "0")

  if [ "${OLD_RUN_COUNT}" -eq 0 ] && [ "${NEW_RUN_COUNT}" -eq 0 ]; then
    RUN_MOD_SUMMARY="No run: blocks in ${af}"
    break
  fi

  # Extract run: block content using awk (lines inside run: | blocks)
  AWK_PROG='/[[:space:]]run:[[:space:]]*\|/ { ri=index($0,"run:"); c=1; next } /[[:space:]]run:[[:space:]]+[^|>]/ { sub(/.*run:[[:space:]]+/,""); print; next } c { if(NF==0){print;next} ci=match($0,/[^[:space:]]/); if(ci<=ri){c=0} else{print} }'

  OLD_BLOCKS=$(printf '%s\n' "${OLD_CONTENT}" | awk "${AWK_PROG}")
  NEW_BLOCKS=$(printf '%s\n' "${NEW_CONTENT}" | awk "${AWK_PROG}")

  OLD_LINES=$(printf '%s\n' "${OLD_BLOCKS}" | wc -l)
  NEW_LINES=$(printf '%s\n' "${NEW_BLOCKS}" | wc -l)
  OLD_HASH=$(printf '%s\n' "${OLD_BLOCKS}" | sha256sum | cut -d' ' -f1)
  NEW_HASH=$(printf '%s\n' "${NEW_BLOCKS}" | sha256sum | cut -d' ' -f1)

  if [ "${OLD_HASH}" = "${NEW_HASH}" ]; then
    RUN_MOD_SUMMARY="run: steps: ${OLD_RUN_COUNT}, content unchanged"
  else
    DELTA=$((NEW_LINES - OLD_LINES))
    SIGN=""
    [ "${DELTA}" -gt 0 ] && SIGN="+"
    RUN_MOD_SUMMARY="run: steps: ${OLD_RUN_COUNT} -> ${NEW_RUN_COUNT}, content MODIFIED (${OLD_LINES} -> ${NEW_LINES} lines, ${SIGN}${DELTA})"
  fi
  break
done
echo "run_mod_summary=${RUN_MOD_SUMMARY}" >> "$GITHUB_OUTPUT"

# Detect unpinned uses: references (not using 40 or 64-char SHA)
UNPINNED=$(echo "${ACTION_DIFF}" | grep -E '^\+' | grep -v '^+++' | grep -v '^+[[:space:]]*#' | grep '[[:space:]]*uses[[:space:]]*:' | grep -vE '@[0-9a-f]{40}([0-9a-f]{24})?' | sed 's/^\+//' || true)
DELIMITER_UP="UNPIN_$(head -c 8 /dev/urandom | xxd -p)"
echo "unpinned_refs<<${DELIMITER_UP}" >> "$GITHUB_OUTPUT"
printf '%s\n' "${UNPINNED:-None}" >> "$GITHUB_OUTPUT"
echo "${DELIMITER_UP}" >> "$GITHUB_OUTPUT"
