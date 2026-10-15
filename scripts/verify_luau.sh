#!/usr/bin/env bash
# scripts/verify_luau.sh — Anti-Deprecation Scanner, Compiler, Linter & 50ms Math Unit-Test Gate
set -u

# Skip gracefully during initial repo bootstrap when src/ has no .luau files yet
LUAU_FILES=$(find src -name "*.luau" 2>/dev/null || true)
if [ -z "$LUAU_FILES" ]; then
  exit 0
fi

# 0. Deterministic Anti-Deprecation Gate (Blocks legacy Roblox/Lua APIs immediately)
if [ -x ".claude/skills/verifying-roblox-apis/scripts/scan_deprecated_apis.sh" ]; then
  bash .claude/skills/verifying-roblox-apis/scripts/scan_deprecated_apis.sh
  if [ $? -ne 0 ]; then
    exit 2
  fi
fi

if command -v rojo >/dev/null 2>&1; then
  rojo sourcemap default.project.json --output sourcemap.json 2>/dev/null || true
fi

if command -v stylua >/dev/null 2>&1; then
  stylua src/ 2>/dev/null || true
fi

# 1. Strict Typecheck Gate
if command -v luau-lsp >/dev/null 2>&1; then
  SOURCEMAP_ARG=""
  [ -f "sourcemap.json" ] && SOURCEMAP_ARG="--sourcemap=sourcemap.json"
  LSP_OUT=$(luau-lsp analyze $SOURCEMAP_ARG src/ 2>&1)
  if [ $? -ne 0 ]; then
    echo "[COMPILER GATE REJECTED] luau-lsp strict typecheck failed:" >&2
    echo "$LSP_OUT" >&2
    echo "If an API signature changed, run /verifying-roblox-apis to look up the latest Roblox documentation." >&2
    exit 2
  fi
fi

# 2. Static Linter Gate
if command -v selene >/dev/null 2>&1; then
  SELENE_OUT=$(selene src/ 2>&1)
  if [ $? -ne 0 ]; then
    echo "[LINTER GATE REJECTED] Selene linter failed:" >&2
    echo "$SELENE_OUT" >&2
    echo "Fix all Selene warnings/errors in src/ before completing your turn." >&2
    exit 2
  fi
fi

# 3. Headless Economy & Multiplier Math Unit Test Gate (<50ms via Lune)
if [ -f "tests/verify_economy_math.luau" ] && command -v lune >/dev/null 2>&1; then
  LUNE_OUT=$(lune run tests/verify_economy_math.luau 2>&1)
  if [ $? -ne 0 ]; then
    echo "[UNIT TEST GATE REJECTED] Economy & Multiplier math assertions failed:" >&2
    echo "$LUNE_OUT" >&2
    echo "Ensure all Config tables and Math utilities match the Master Blueprint laws." >&2
    exit 2
  fi
fi

echo "[ANTI-DEPRECATION, COMPILER, LINTER & MATH UNIT GATES PASSED] Zero errors."
exit 0
