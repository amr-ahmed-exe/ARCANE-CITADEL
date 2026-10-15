---
name: building-feature
description: Builds, refactors, or fixes a specific feature using the 5-Stage Hierarchical Pipeline (Architect -> Worker -> Reviewer -> QA Tester -> Librarian). Use when implementing a new gameplay mechanic, UI controller, or bugfix.
argument-hint: "<FeatureOrFixDescription>"
---

### Current Repo State & Working Tree (Auto-Injected):
!`cat docs/REPO_STATE.md 2>/dev/null`
!`git status --short`

### Execute the 5-Stage Pipeline for: $ARGUMENTS
1. Invoke `@chief-architect` to verify modern Roblox APIs and write the scoped feature spec into `docs/specs/current_task.md`.
2. Invoke `@luau-worker` (and `@studio-world-worker` / `@blender-worker` if 3D/UI changes are required) to implement the spec with full `---` Luau-LSP docstrings and pass `scripts/verify_luau.sh`.
3. Invoke `@principal-reviewer` to audit `git diff`. Loop back to `@luau-worker` if `STATUS: CHANGES_REQUESTED`.
4. Invoke `@qa-playtest-tester` to verify runtime behavior and fuzz remotes in Studio Play Mode. Loop back to `@luau-worker` if `QA_STATUS: FAILED`.
5. Invoke `@repo-librarian` to sync `docs/REPO_STATE.md`, `docs/API_CONTRACTS.md`, `docs/DEVELOPER_GUIDEBOOK.md`, and `docs/CHANGELOG.md`, verified by `verify_docs_coverage.sh`.
