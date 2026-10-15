#!/usr/bin/env bash
# scripts/verify_setup.sh — Verifies that Claude Code extracted all 34 orchestration files cleanly
set -u

REQUIRED_FILES=(
  ".gitignore"
  "rokit.toml"
  "wally.toml"
  "default.project.json"
  ".luaurc"
  "selene.toml"
  ".mcp.json"
  "assets/asset_manifest.json"
  ".claude/settings.json"
  "scripts/verify_luau.sh"
  "tests/verify_economy_math.luau"
  "CLAUDE.md"
  ".claude/agents/01-chief-architect.md"
  ".claude/agents/02a-luau-worker.md"
  ".claude/agents/02b-studio-world-worker.md"
  ".claude/agents/02c-blender-worker.md"
  ".claude/agents/03-principal-reviewer.md"
  ".claude/agents/04-qa-playtest-tester.md"
  ".claude/agents/05-repo-librarian.md"
  ".claude/skills/enforcing-luau-standards/SKILL.md"
  ".claude/skills/enforcing-luau-standards/references/deprecated_to_modern_matrix.md"
  ".claude/skills/verifying-roblox-apis/SKILL.md"
  ".claude/skills/verifying-roblox-apis/scripts/scan_deprecated_apis.sh"
  ".claude/skills/syncing-documentation/SKILL.md"
  ".claude/skills/syncing-documentation/scripts/verify_docs_coverage.sh"
  ".claude/skills/implementing-milestone/SKILL.md"
  ".claude/skills/building-feature/SKILL.md"
  ".claude/skills/greyboxing-citadel/SKILL.md"
  ".claude/skills/greyboxing-citadel/scripts/generate_citadel_3d.luau"
  ".claude/skills/validating-ui-contracts/SKILL.md"
  ".claude/skills/validating-ui-contracts/scripts/audit_or_wireframe_ui.luau"
  ".claude/skills/fuzzing-remotes/SKILL.md"
  ".claude/skills/fuzzing-remotes/scripts/fuzz_network_router.luau"
  ".claude/skills/forging-3d-asset/SKILL.md"
  ".claude/skills/forging-3d-asset/scripts/blender_normalize_export.py"
  ".claude/skills/forging-3d-asset/scripts/opencloud_upload.py"
  "docs/REPO_STATE.md"
  "docs/API_CONTRACTS.md"
  "docs/DEVELOPER_GUIDEBOOK.md"
  "docs/ADR.md"
  "docs/CHANGELOG.md"
  "docs/specs/current_task.md"
  "docs/specs/pipeline_state.md"
)

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -s "$f" ]; then
    echo "[SETUP ERROR] Missing or empty file: $f" >&2
    MISSING=1
  fi
done

for exec_file in "scripts/verify_luau.sh" "scripts/verify_setup.sh" ".claude/skills/verifying-roblox-apis/scripts/scan_deprecated_apis.sh" ".claude/skills/syncing-documentation/scripts/verify_docs_coverage.sh" ".claude/skills/forging-3d-asset/scripts/opencloud_upload.py"; do
  if [ ! -x "$exec_file" ]; then
    echo "[SETUP ERROR] File is not executable (run chmod +x): $exec_file" >&2
    MISSING=1
  fi
done

if [ $MISSING -ne 0 ]; then
  echo "[SELF-SETUP VERIFICATION FAILED] Fix the missing files above." >&2
  exit 1
fi

echo "[SELF-SETUP 100% VERIFIED] All ${#REQUIRED_FILES[@]} Arcane Citadel orchestration files, agents, anti-deprecation skills, hooks, and docs are installed and ready."
exit 0
