---
name: syncing-documentation
description: Audits all files in src/ and updates docs/REPO_STATE.md, docs/API_CONTRACTS.md, docs/DEVELOPER_GUIDEBOOK.md, docs/ADR.md, and docs/CHANGELOG.md so both human developers and AI agents have 100% up-to-date documentation.
context: fork
agent: repo-librarian
---

### Current Undocumented or Modified Files (Auto-Injected):
!`bash .claude/skills/syncing-documentation/scripts/verify_docs_coverage.sh || true`
!`git status --short`

### Execution Protocol:
1. Inspect any new or modified `.luau` files in `src/`.
2. Update `docs/REPO_STATE.md` and `docs/API_CONTRACTS.md` with exact type definitions, public function signatures, and `NetworkRouter` schemas.
3. Update `docs/DEVELOPER_GUIDEBOOK.md` with plain-English architecture walkthroughs, Mermaid sequence/state diagrams, and "How-To-Extend" recipes for human developers.
4. Record any new architectural decisions in `docs/ADR.md` and log the changes in `docs/CHANGELOG.md`.
5. Run `bash .claude/skills/syncing-documentation/scripts/verify_docs_coverage.sh` and fix any missing entries until it returns `EXIT 0`.
