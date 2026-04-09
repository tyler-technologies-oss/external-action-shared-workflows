#!/usr/bin/env bash
set -euo pipefail

git fetch origin upstream-tracking "${DEFAULT_BRANCH}"
BASE_SHA=$(git rev-parse "origin/${DEFAULT_BRANCH}")
HEAD_SHA=$(git rev-parse origin/upstream-tracking)

FILES_CHANGED=$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}" | wc -l)
LINES_ADDED=$(git diff --numstat "${BASE_SHA}...${HEAD_SHA}" | awk '{s+=$1} END {print s+0}')
LINES_REMOVED=$(git diff --numstat "${BASE_SHA}...${HEAD_SHA}" | awk '{s+=$2} END {print s+0}')

echo "files_changed=${FILES_CHANGED}" >> "$GITHUB_OUTPUT"
echo "lines_added=${LINES_ADDED}" >> "$GITHUB_OUTPUT"
echo "lines_removed=${LINES_REMOVED}" >> "$GITHUB_OUTPUT"

MANIFEST_CHANGES=$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}" -- 'action.yml' 'action.yaml' || true)
echo "manifest_changes=${MANIFEST_CHANGES:-None}" >> "$GITHUB_OUTPUT"

SCRIPT_CHANGES=$(git diff --name-only "${BASE_SHA}...${HEAD_SHA}" -- '*.sh' '*.ps1' '*.py' || true)
echo "script_changes=${SCRIPT_CHANGES:-None}" >> "$GITHUB_OUTPUT"

BINARY_CHANGES=$(git diff --numstat "${BASE_SHA}...${HEAD_SHA}" | grep -E '^-\s+-\s+' | awk '{print $3}' || true)
echo "binary_changes=${BINARY_CHANGES:-None}" >> "$GITHUB_OUTPUT"

echo "base_sha=${BASE_SHA}" >> "$GITHUB_OUTPUT"
echo "head_sha=${HEAD_SHA}" >> "$GITHUB_OUTPUT"
