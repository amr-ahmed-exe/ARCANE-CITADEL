---
name: implementing-milestone
description: Executes a full Milestone (1-5) from the Arcane Citadel blueprint through the 5-Stage Hierarchical Pipeline (Architect -> Workers -> Principal Reviewer -> Playtest QA -> Repo Librarian).
argument-hint: "<MilestoneNumber 1-5>"
disable-model-invocation: true
---

### Live Repository State & Pipeline Breadcrumb (Auto-Injected Before Turn):
!`cat docs/REPO_STATE.md 2>/dev/null || echo "REPO_STATE.md not initialized yet."`
!`cat docs/specs/pipeline_state.md 2>/dev/null || echo "No active pipeline state."`

### Execute Milestone $ARGUMENTS Using the Strict 5-Stage Pipeline:

1. **Stage 1 — Architecture & Modern API Verification (`@chief-architect`):**
   - Write `Milestone $ARGUMENTS - STAGE 1 (Architecture)` to `docs/specs/pipeline_state.md`.
   - Delegate to `@chief-architect` to read Milestone $ARGUMENTS in `arcane_citadel_master_blueprint.md`, verify any new Roblox Engine APIs via `/verifying-roblox-apis`, and write the complete technical spec to `docs/specs/current_task.md`.
2. **Stage 2 — Implementation (`@studio-world-worker` & `@luau-worker`):**
   - Update `docs/specs/pipeline_state.md` to `STAGE 2 (Implementation)`.
   - If `docs/specs/current_task.md` requires 3D Studio geometry or UI wireframes/tags, invoke `/greyboxing-citadel` or `/validating-ui-contracts`.
   - Delegate `.luau` implementation to `@luau-worker` until all files in `docs/specs/current_task.md` are implemented with `---` Luau-LSP docstrings and pass `scripts/verify_luau.sh` (including `scan_deprecated_apis.sh`).
3. **Stage 3 — Adversarial Audit (`@principal-reviewer`):**
   - Update `docs/specs/pipeline_state.md` to `STAGE 3 (Review)`.
   - Delegate to `@principal-reviewer` to audit `git diff` against `docs/specs/current_task.md`.
   - If `STATUS: CHANGES_REQUESTED`, send the defects back to `@luau-worker` and re-run `@principal-reviewer` until `STATUS: APPROVED`.
   - *(Break-Glass Rule: If `@luau-worker` and `@principal-reviewer` fail to resolve a distributed concurrency or math defect after 2 loops, halt and prompt the human lead whether to escalate that single turn to `claude-fable-5-1`).*
4. **Stage 4 — Studio Playtest QA & Exploit Fuzzing (`@qa-playtest-tester`):**
   - Update `docs/specs/pipeline_state.md` to `STAGE 4 (Playtest QA)`.
   - Delegate to `@qa-playtest-tester` to run acceptance assertions and `/fuzzing-remotes` in Roblox Studio Play Mode.
   - If `QA_STATUS: FAILED`, route stack traces back to `@luau-worker`, re-review, and re-test until `QA_STATUS: PASSED`.
5. **Stage 5 — Dual-Audience Living Documentation (`@repo-librarian`):**
   - Update `docs/specs/pipeline_state.md` to `STAGE 5 (Documentation)`.
   - Delegate to `@repo-librarian` (or `/syncing-documentation`) to update `docs/REPO_STATE.md`, `docs/API_CONTRACTS.md`, `docs/DEVELOPER_GUIDEBOOK.md`, `docs/ADR.md`, and `docs/CHANGELOG.md`, and verify `0` missing docs via `verify_docs_coverage.sh`.
   - Mark `Milestone $ARGUMENTS - COMPLETE` in `docs/specs/pipeline_state.md`.
