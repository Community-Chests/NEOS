# Implementation Plan: Multi-Ecosystem Collaboration & Platform Hardening

## Overview

Eight phases: (0) Critical fixes from code review, (1) Data model foundation, (2) AI independence, (3) Jinja2 removal, (4) Inter-unit discovery & collaboration, (5) "No Sultan" routing & conflict refinement, (6) PWA notifications & cron, (7) Compliance & versioning. Each phase ends with verification and a commit.

---

## Phase 0: Critical Fixes (Code Review Blockers)

**Goal:** Fix 3 critical bugs and 4 high-severity issues that block multi-ecosystem collaboration. These are security and correctness issues in the existing codebase.

### Tasks

- [x] Task 0.1: **[CRITICAL] Fix ecosystem scoping bypass** — Delete all 14 copies of `_get_ecosystem_ids()` from API blueprints (agreements.py, members.py, proposals.py, conflicts.py, decisions.py, domains.py, exit.py, onboarding.py, messaging.py, courses.py, quizzes.py, safeguards.py, emergency.py, dashboard.py). Replace every call site with `request.ctx.selected_ecosystem_ids` (already set by middleware in main.py:170-292). Extract shared `_require_auth()` to `api/helpers.py` to eliminate that duplication too.

- [x] Task 0.2: **[CRITICAL] Fix Member.did unique constraint** — Change `models.py:138` from `unique=True` to a composite unique constraint `UniqueConstraint("ecosystem_id", "did", name="uq_member_ecosystem_did")`. Generate Alembic migration. Test that the same DID can exist in two ecosystems.

- [x] Task 0.3: **[CRITICAL] Fix sync Anthropic client** — In `api/ai_assist.py:69-76`, replace `anthropic.Anthropic()` with `anthropic.AsyncAnthropic()` and `await client.messages.create(...)`. Add error handling for when API key is missing.

- [x] Task 0.4: **[HIGH] Unify agreement state machines** — Replace the API's simplified transitions (`draft→ratified→archived` in agreements.py:165-169) with the governance tools' full ACT lifecycle (`draft→advice→consent→test→active→under_review→sunset→archived` from governance_tools.py:49-57). Update the frontend AgreementDetail to support all states.

- [x] Task 0.5: **[HIGH] Replace datetime.utcnow()** — Find and replace all 18 call sites with `datetime.now(timezone.utc)`. Files: main.py, auth/routes.py, api/auth.py, governance_tools.py, messaging/handlers.py, messaging/routes.py, api/exit.py, api/emergency.py.

- [x] Task 0.6: **[HIGH] Fix SESSION_SECRET default** — In config.py, remove the default value. Add a startup check that fails fast if SESSION_SECRET is not explicitly set (or generate a random one with a logged warning in dev mode).

- [x] Task 0.7: **[HIGH] Remove duplicate /auth/ routes** — Remove the legacy `auth_bp` registration from main.py:163-164. Keep only `auth_api_bp` at `/api/v1/auth/`. Verify the React frontend only uses `/api/v1/auth/` paths.

- [x] Task 0.8: **[HIGH] Fix quorum calculation** — In governance_tools.py:845, replace `int(total_deciding_body * required_fraction)` with `math.ceil(total_deciding_body * required_fraction)`.

- [x] Task 0.9: **[HIGH] Add ecosystem update authorization** — In ecosystems.py:237-282, check that the member has a steward role in the ecosystem before allowing updates. Add a `role` field check against DomainMembership (or Member.role if available).

- [x] Task 0.10: **[HIGH] Enable multi-ecosystem selection in frontend** — In EcosystemContext.tsx, add `toggleEcosystem(id)` and `selectMultiple(ids)` methods alongside the existing `selectEcosystem`.

- [x] Task 0.11: Write tests for: ecosystem scoping (verify forged cookie is rejected), multi-ecosystem DID membership, agreement state transitions, quorum calculation edge cases.

- [x] Verification: All 14 blueprints use middleware-authorized ecosystem IDs. A member can join 2 ecosystems. Agreement lifecycle follows ACT states. Quorum ceil(2 * 0.667) = 2. Forged cookie returns only authorized data. Tests pass.

**Commit:** `conductor(critical-fixes): ecosystem scoping, DID uniqueness, agreement states, security hardening`

---

## Phase 1: Data Model Foundation

**Goal:** Add CircleMembership, Shares/Needs, Collaborations, Culture Code to the database. Enhance Domain as the unified organizational unit.

### Tasks

- [ ] Task 1.1: Enhance `Domain` model — add `domain_type` enum field (circle, ethos, shur, working_group, committee), `parent_domain_id` FK (self-referential for nesting), `culture_code` JSON field, `culture_code_version` integer field. Add `Ecosystem.culture_code` and `Ecosystem.culture_code_version` fields.

- [ ] Task 1.2: Create `DomainMembership` model — `id`, `domain_id` FK, `member_id` FK, `role` (member, steward, delegate, liaison), `capacity_hours` integer (nullable), `joined_at`, `status` (active, inactive, on_leave), unique constraint on (domain_id, member_id).

- [ ] Task 1.3: Create `DomainShare` model — `id`, `domain_id` FK, `ecosystem_id` FK, `title`, `description`, `category` enum (resource, expertise, service, space), `availability_status` (available, limited, unavailable), `tags` JSON, `created_at`, `updated_at`.

- [ ] Task 1.4: Create `DomainNeed` model — `id`, `domain_id` FK, `ecosystem_id` FK, `title`, `description`, `category` enum (resource, expertise, service, space), `urgency` enum (low, medium, high), `tags` JSON, `fulfilled` boolean, `created_at`, `updated_at`.

- [ ] Task 1.5: Create `Collaboration` model — `id`, `source_domain_id` FK, `target_domain_id` FK, `collaboration_type` enum (bilateral, service, mutual_aid, knowledge_sharing), `status` enum (proposed, accepted, active, paused, concluded, declined), `terms` JSON, `initiated_by` FK (member), `accepted_by` FK (member, nullable), `review_date`, `created_at`, `updated_at`. Unique constraint on (source_domain_id, target_domain_id) when status is active.

- [ ] Task 1.6: Generate Alembic migration for all new models and field additions.

- [ ] Task 1.7: Write tests for new models — creation, relationships, constraints, domain nesting.

- [ ] Verification: `alembic upgrade head` succeeds. All new models create tables. Tests pass. Existing data untouched.

**Commit:** `conductor(data-model): add DomainMembership, Shares, Needs, Collaborations, Culture Code`

---

## Phase 2: AI Independence — OpenRouter + LiteLLM

**Goal:** Replace Anthropic-only dependency with multi-provider AI via LiteLLM. Ensure all governance works without AI.

### Tasks

- [ ] Task 2.1: Update `config.py` — add `AI_PROVIDER` (openrouter, anthropic, local, none), `AI_MODEL`, `AI_BASE_URL`, `AI_API_KEY` settings. Deprecate `ANTHROPIC_API_KEY` and `CLAUDE_MODEL` (map to new fields for backward compat).

- [ ] Task 2.2: Add `litellm` to requirements. Create `agent/src/neos_agent/agent/llm_client.py` — unified LLM interface using litellm.completion(). Handle provider routing, fallbacks, and `AI_PROVIDER=none` gracefully.

- [ ] Task 2.3: Refactor `agent/router.py` and `chat.py` to use the new `llm_client` instead of direct Anthropic SDK calls. Preserve tool-calling interface.

- [ ] Task 2.4: Update governance tool templates in `governance_tools.py` — add `instructions` field to each tool's output templates with human-readable "How to fill this out" guidance.

- [ ] Task 2.5: Add `AI_PROVIDER=none` mode to chat endpoint — returns a helpful message directing users to manual governance processes with template links.

- [ ] Task 2.6: Update `system_prompt.py` — make prompt assembly model-agnostic (remove Anthropic-specific formatting assumptions).

- [ ] Task 2.7: Write tests for LLM client (mock provider), AI-none mode, template instructions.

- [ ] Verification: App starts with `AI_PROVIDER=none` and all non-chat endpoints work. Chat endpoint returns graceful fallback. App starts with `AI_PROVIDER=openrouter` and chat works with configured model.

**Commit:** `conductor(ai-independence): switch to LiteLLM, multi-provider support, AI-optional mode`

---

## Phase 3: Jinja2/Datastar Removal

**Goal:** Remove all server-rendered HTML. Sanic is API-only. React is the sole frontend.

### Tasks

- [ ] Task 3.1: Identify all Jinja2 template routes — grep for `@app.get` and `@bp.get` that return HTML or use `jinja2_async`. List all routes to remove.

- [ ] Task 3.2: Remove `agent/templates/` directory and all Jinja2 template files.

- [ ] Task 3.3: Remove HTML-serving routes from all blueprints. Keep only `/api/v1/` JSON routes and the root health endpoint.

- [ ] Task 3.4: Remove Jinja2, Datastar, and related dependencies from `requirements.txt` / `pyproject.toml`.

- [ ] Task 3.5: Update `main.py` — remove any template engine initialization, static file serving for Datastar assets.

- [ ] Task 3.6: Verify all existing React frontend API calls still work against the cleaned-up API.

- [ ] Verification: `python -m neos_agent.main` starts without template errors. All `/api/v1/` endpoints return JSON. No Jinja2/Datastar imports remain. React frontend works end-to-end.

**Commit:** `conductor(jinja2-removal): remove all Jinja2/Datastar, API-only backend`

---

## Phase 4: Inter-Unit Discovery & Collaboration

**Goal:** API endpoints and frontend pages for Shares/Needs discovery and domain-to-domain Collaborations.

### Tasks

- [ ] Task 4.1: Create `api/shares_needs.py` blueprint — CRUD for DomainShare and DomainNeed. Search/filter by category, tags, ecosystem. Cross-ecosystem visibility for public ecosystems.

- [ ] Task 4.2: Create `api/collaborations.py` blueprint — propose, accept, decline, pause, conclude collaborations. Dual-consent workflow: proposer creates (status=proposed), target domain steward accepts (status=active). List collaborations by domain, by ecosystem, by status.

- [ ] Task 4.3: Create `api/domain_memberships.py` blueprint — CRUD for DomainMembership. List members by domain, list domains by member. Quorum computation endpoint: given a domain, return member count, active count, quorum threshold.

- [ ] Task 4.4: Enhance `api/discover.py` — add Shares, Needs, and Collaborations sections to the discover feed. Add tab filters: "all", "quizzes", "ecosystems", "shares", "needs", "collaborations". Match shares to needs by category/tags.

- [ ] Task 4.5: Create React pages — `SharesNeedsList.tsx`, `CollaborationList.tsx`, `CollaborationDetail.tsx`. Add to governance routing.

- [ ] Task 4.6: Enhance `EthosDiscover.tsx` — add Shares/Needs/Collaborations tabs to the discover page. Show matched shares/needs with visual indicators.

- [ ] Task 4.7: Add governance tools for AI agent — `list_shares`, `list_needs`, `propose_collaboration`, `match_shares_needs`.

- [ ] Task 4.8: Write tests for dual-consent collaboration workflow, cross-ecosystem share/need visibility, quorum computation.

- [ ] Verification: A user in Ecosystem A can see shares from Ecosystem B on Discover. A domain steward can propose a collaboration to another domain. Target domain steward can accept. Collaborations appear on both domains' detail pages.

**Commit:** `conductor(inter-unit): shares/needs discovery, domain collaborations, dual-consent routing`

---

## Phase 5: Conflict Resolution Refinement

**Goal:** Support incremental/partial proposal resolution for conflicts. Update conflict workflow to decompose failed proposals.

### Tasks

- [ ] Task 5.1: Enhance `ConflictCase` model — add `parent_conflict_id` FK (self-referential for decomposition), `resolution_strategy` enum (full, incremental, partial).

- [ ] Task 5.2: Enhance `Proposal` model — add `conflict_id` FK (nullable, links proposal to conflict), `is_partial` boolean (default false), `resolves_components` JSON (list of conflict sub-issues addressed).

- [ ] Task 5.3: Update `api/conflicts.py` — add endpoints for decomposing a conflict into sub-conflicts, linking proposals to conflicts, tracking partial resolution progress.

- [ ] Task 5.4: Update `api/proposals.py` — when a proposal linked to a conflict fails consent, offer option to create child proposals addressing subsets of the original.

- [ ] Task 5.5: Create React components — `ConflictResolutionProgress.tsx` showing which parts are resolved and which are pending. Update `ConflictDetail.tsx` to show linked proposals and sub-conflicts.

- [ ] Task 5.6: Add Alembic migration for conflict/proposal model changes.

- [ ] Task 5.7: Write tests for conflict decomposition, partial resolution linking, progress tracking.

- [ ] Verification: A conflict can be decomposed into 3 sub-issues. Each sub-issue gets its own proposal. When 2 of 3 proposals pass, the conflict shows 67% resolved. Agreement updates are linked to resolved components.

**Commit:** `conductor(conflict-resolution): incremental resolution, decomposition, partial proposals`

---

## Phase 6: PWA Notifications & Cron Jobs

**Goal:** Background task infrastructure and PWA push notifications for time-bound governance events.

### Tasks

- [ ] Task 6.1: Create `Notification` model — `id`, `member_id` FK, `ecosystem_id` FK, `event_type` enum (consent_round_open, review_approaching, request_stale, compliance_due, collaboration_proposed, conflict_update), `title`, `body`, `href` (deep link), `read` boolean, `created_at`.

- [ ] Task 6.2: Create notification API blueprint — list notifications (paginated), mark read, mark all read, notification preferences (opt-in/out per event type).

- [ ] Task 6.3: Add background task scheduler to `main.py` — use `app.add_task()` with async sleep loops for cron-like scheduling. Jobs: agreement review scan (daily), consent deadline scan (daily), stale request scan (daily), compliance summary regeneration (30 days).

- [ ] Task 6.4: Create notification generation logic — scan governance tables for upcoming deadlines, create Notification records for affected members.

- [ ] Task 6.5: Add PWA service worker to React frontend — `public/sw.js` for push notification handling. Register service worker in `main.tsx`. Add `manifest.json` for PWA.

- [ ] Task 6.6: Add SSE or polling endpoint for real-time notification delivery — `/api/v1/notifications/stream` (SSE preferred, polling fallback).

- [ ] Task 6.7: Add notification bell component in React header — shows unread count, dropdown list, links to relevant governance pages.

- [ ] Task 6.8: Write tests for notification generation logic, cron job scheduling, notification API.

- [ ] Verification: A consent round with deadline in 3 days generates notifications for affected members. Notifications appear in the React UI bell. PWA push works on supported browsers. Cron jobs run on schedule in development.

**Commit:** `conductor(notifications): PWA push, cron jobs, notification API, background tasks`

---

## Phase 7: Compliance & Versioning

**Goal:** Compliance summaries with AI/manual generation and version fingerprinting on governance entities.

### Tasks

- [ ] Task 7.1: Create `ComplianceSummary` model — `id`, `entity_type` enum (ecosystem, domain), `entity_id` UUID, `summary_text`, `generated_at`, `generated_by` enum (ai, manual), `score_data` JSON, `expires_at`, `ai_model_used` (nullable).

- [ ] Task 7.2: Add `version` integer field to `Agreement` model (default 1). Add trigger/logic to auto-increment on update. Add `culture_code_version` to Domain and Ecosystem if not already done in Phase 1.

- [ ] Task 7.3: Create `api/compliance.py` blueprint — get compliance summary for entity, trigger regeneration, list all summaries. When AI available, generate via LLM; when not, return template with manual assessment instructions.

- [ ] Task 7.4: Add compliance summary generation to cron scheduler (30-day cycle). Query governance health indicators, pass to LLM or produce template.

- [ ] Task 7.5: Create React pages — `ComplianceSummary.tsx` (view/regenerate), add compliance badge to ecosystem/domain cards.

- [ ] Task 7.6: Add version display to Agreement detail and Domain detail pages. Show version history via existing amendment/review records.

- [ ] Task 7.7: Write Alembic migration for ComplianceSummary table and version fields.

- [ ] Task 7.8: Write tests for version auto-increment, compliance generation (AI and manual modes), 30-day cron trigger.

- [ ] Verification: Agreement version increments on update via API. Compliance summary generates for an ecosystem (AI mode and manual template mode). 30-day cron produces summaries. React pages display version and compliance data.

**Commit:** `conductor(compliance-versioning): compliance summaries, version fingerprinting, cron generation`

---

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| 0 | 11 + verification | Critical fixes (code review blockers) |
| 1 | 7 + verification | Data model foundation |
| 2 | 7 + verification | AI independence |
| 3 | 6 + verification | Jinja2/Datastar removal |
| 4 | 8 + verification | Inter-unit discovery & collaboration |
| 5 | 7 + verification | Conflict resolution refinement |
| 6 | 8 + verification | PWA notifications & cron |
| 7 | 8 + verification | Compliance & versioning |
| **Total** | **62 + 8 verifications** | |

## Dependencies

- **Phase 0 (Critical fixes) must complete first** — all subsequent phases depend on the corrected ecosystem scoping and DID uniqueness
- Phase 2 (AI) and Phase 3 (Jinja2 removal) can run in parallel after Phase 0
- Phase 1 (Data model) depends on Phase 0 (DID constraint fix, ecosystem scoping)
- Phase 4 (Inter-unit) depends on Phase 1 (Data model)
- Phase 5 (Conflict) depends on Phase 1 (Data model)
- Phase 6 (Notifications) depends on Phase 1 (Data model) and Phase 3 (Jinja2 removal)
- Phase 7 (Compliance) depends on Phase 1 (Data model) and Phase 2 (AI independence)

## Critical Path

Phase 0 → Phase 1 → Phase 4 → Phase 6 (critical fixes → data model → discovery → notifications)

After Phase 0, Phases 1, 2, and 3 can run in parallel since they don't touch the same files.
