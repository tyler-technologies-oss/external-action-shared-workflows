#!/usr/bin/env bash
set -euo pipefail

# Check for security-relevant changes between fork and upstream
# Inputs via env: DEFAULT_BRANCH
# Outputs to $GITHUB_OUTPUT: has_security_changes, security_files

SECURITY_FILES=$(git diff --name-only "origin/${DEFAULT_BRANCH}...HEAD" -- \
  'action.yml' \
  'action.yaml' \
  'Dockerfile' \
  'package.json' \
  'package-lock.json' \
  '*.ps1' \
  '*.sh' \
  'dist/' \
  'node_modules/' \
|| true)

if [ -n "${SECURITY_FILES}" ]; then
  echo "has_security_changes=true" >> "$GITHUB_OUTPUT"
  DELIMITER="SEC_$(head -c 16 /dev/urandom | xxd -p)"
  echo "security_files<<${DELIMITER}" >> "$GITHUB_OUTPUT"
  echo "${SECURITY_FILES}" >> "$GITHUB_OUTPUT"
  echo "${DELIMITER}" >> "$GITHUB_OUTPUT"
else
  echo "has_security_changes=false" >> "$GITHUB_OUTPUT"
  echo "security_files=None detected" >> "$GITHUB_OUTPUT"
fi
