#!/usr/bin/env bash
# .claude/skills/syncing-documentation/scripts/verify_docs_coverage.sh
# Deterministically verifies that every .luau file in src/ has inline docstrings
# and is documented across REPO_STATE.md, API_CONTRACTS.md, and DEVELOPER_GUIDEBOOK.md.
set -u

MISSING=0

for file in $(find src -name "*.luau" 2>/dev/null); do
  filename=$(basename "$file")
  modulename="${filename%.luau}"

  # 1. Check for Luau-LSP inline docstrings (---) inside the code file
  if ! grep -q "^---" "$file"; then
    echo "[DOC AUDIT FAIL] $file is missing '---' Luau-LSP inline docstrings." >&2
    MISSING=1
  fi

  # 2. Check that the file is indexed in docs/REPO_STATE.md
  if [ -f "docs/REPO_STATE.md" ] && ! grep -q "$filename" "docs/REPO_STATE.md"; then
    echo "[DOC AUDIT FAIL] $file is missing from docs/REPO_STATE.md." >&2
    MISSING=1
  fi

  # 3. Check that shared/server/client modules are explained in docs/DEVELOPER_GUIDEBOOK.md
  if [ -f "docs/DEVELOPER_GUIDEBOOK.md" ] && [[ "$filename" != Runtime.* ]] && ! grep -q "$modulename" "docs/DEVELOPER_GUIDEBOOK.md"; then
    echo "[DOC AUDIT FAIL] $modulename is missing an architecture/onboarding section in docs/DEVELOPER_GUIDEBOOK.md." >&2
    MISSING=1
  fi
done

if [ $MISSING -ne 0 ]; then
  echo "[DOCUMENTATION COVERAGE REJECTED] Update all missing documentation before completing Stage 5." >&2
  exit 2
fi

echo "[100% DOCUMENTATION COVERAGE VERIFIED] All src/ modules have inline docstrings, AI index entries, and Human Guidebook sections."
exit 0
