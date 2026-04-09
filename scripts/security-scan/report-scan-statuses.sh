#!/usr/bin/env bash
set -euo pipefail

PR_HEAD_SHA=$(gh pr view "${PR_NUMBER}" \
  --repo "${REPO}" \
  --json headRefOid \
  --jq '.headRefOid')

post_status() {
  local context="$1" state="$2" desc="$3"
  gh api "repos/${REPO}/statuses/${PR_HEAD_SHA}" \
    -f state="${state}" \
    -f context="${context}" \
    -f description="${desc}" \
    -f target_url="${RUN_URL}"
}

post_check() {
  local name="$1" conclusion="$2" summary="$3"
  gh api "repos/${REPO}/check-runs" \
    -f name="${name}" \
    -f head_sha="${PR_HEAD_SHA}" \
    -f status="completed" \
    -f conclusion="${conclusion}" \
    -f "output[title]=${name}" \
    -f "output[summary]=${summary}" \
    -f details_url="${RUN_URL}"
}

map_status() {
  case "$1" in
    success)  echo "success" ;;
    failure)  echo "failure" ;;
    skipped)  echo "success" ;;
    *)        echo "error" ;;
  esac
}

map_check() {
  case "$1" in
    success)  echo "success" ;;
    failure)  echo "failure" ;;
    skipped)  echo "skipped" ;;
    *)        echo "failure" ;;
  esac
}

post_check "security-scan/dependency-review" \
  "$(map_check "${DEP_REVIEW_RESULT}")" \
  "Dependency review: ${DEP_REVIEW_RESULT}"

post_check "security-scan/diff-summary" \
  "$(map_check "${DIFF_SUMMARY_RESULT}")" \
  "Diff summary: ${DIFF_SUMMARY_RESULT}"

post_check "security-scan/codeql" \
  "$(map_check "${CODEQL_RESULT}")" \
  "CodeQL analysis: ${CODEQL_RESULT}"

# CodeQL is informational -- findings appear in Code Scanning tab, not in aggregate
if [ "${DEP_REVIEW_RESULT}" = "failure" ] || \
   [ "${DIFF_SUMMARY_RESULT}" = "failure" ]; then
  AGGREGATE="failure"
  DESC="Security scan failed"
else
  AGGREGATE="success"
  DESC="Security scan passed"
fi

post_status "security-scan" "${AGGREGATE}" "${DESC}"
post_check "security-scan" "$(map_check "${AGGREGATE}")" "${DESC}"

echo "Posted checks and status on PR #${PR_NUMBER} (${PR_HEAD_SHA:0:12})"
