# Specification: Multi-Ecosystem Collaboration & Platform Hardening

## Overview

Implement the foundational data model and infrastructure for multi-ecosystem collaboration in NEOS. Add CircleMembership, Shares/Needs discovery, domain-to-domain Collaborations, compliance summaries, and version fingerprinting. Switch AI to OpenRouter/LiteLLM with AI-optional design. Remove Jinja2/Datastar (React only). Add PWA notifications via cron jobs. Implement "No Sultan" lateral routing for cross-ecosystem requests. Refine conflict resolution to support incremental/partial proposal resolution.

## Background

A deep architectural review (2026-04-25) with historical research (Ostrom, Swiss cantons, Haudenosaunee, federated protocols, DAOs) identified critical gaps between NEOS's 54-skill governance specification and its implementation. Layers IV (Economic) and V (Inter-Unit) have zero code. The database lacks Circle/ETHOS organizational units. AI depends on a single proprietary provider. Jinja2/Datastar templates coexist with React creating dual maintenance. No notification infrastructure exists for time-bound governance processes.

## Decisions (Resolved)

1. **Circle/ETHOS/Domain merge:** Circle, ETHOS, and Domain are similar enough to use a single `Domain` entity with a `domain_type` field (circle, ethos, shur, working-group, etc.). Flat is good up to a point.
2. **No multi-ecosystem identity:** Intentional — NEOS is a 3rd space for free association in consent-based agreements. No cross-ecosystem reputation/identity system.
3. **AI independence:** Everything works without AI. Templates prepopulated with human-readable instructions. AI is an accelerator.
4. **OpenRouter + LiteLLM:** Replace Anthropic-only dependency with OpenRouter as default, LiteLLM as proxy layer. Multiple model choices.
5. **React only:** Jinja2/Datastar templates removed. All frontend is React/TypeScript.
6. **Inter-unit collaboration via Shares/Needs:** Not economic layer. Domains declare what they share and what they need. Discovery page surfaces matches.
7. **Domain-to-domain relationships:** Standard pattern for ecosystem collaboration. A `Collaboration` entity links domains across ecosystems.
8. **Conflict resolution:** conflict → solution proposal → if fails, break into smaller parts → incremental/partial proposals → continuous engagement → agreements updated.
9. **UAF philosophy:** Enforces free association. Culture Code entities at domain/ecosystem level for cultural specialization.
10. **Instances operate independently:** External API for inter-instance communication deferred. Focus on single-instance multi-ecosystem.

## Functional Requirements

### FR-1: CircleMembership & Domain Enhancement
**Description:** Add `DomainMembership` table linking Members to Domains with role/capacity. Enhance Domain model with `domain_type` enum (circle, ethos, shur, working-group, committee). Add `parent_domain_id` for nesting.
**Acceptance Criteria:**
- Members can belong to multiple Domains within an ecosystem
- Domain has `domain_type`, `parent_domain_id`, `culture_code` (JSON)
- DomainMembership tracks: member, domain, role, capacity_hours, joined_at, status
- API endpoints for domain membership CRUD
- Quorum can be computed for any domain
**Priority:** P0

### FR-2: Shares & Needs Entities
**Description:** Add `DomainShare` and `DomainNeed` tables at the domain level. A Share declares a resource/capability a domain offers. A Need declares what a domain is looking for.
**Acceptance Criteria:**
- DomainShare: domain_id, title, description, category (resource, expertise, service, space), availability_status, tags
- DomainNeed: domain_id, title, description, category, urgency (low, medium, high), tags
- Shares and Needs are visible on the Discover page
- Cross-ecosystem visibility: Shares/Needs from public ecosystems are discoverable
- API endpoints for CRUD + search/filter
**Priority:** P0

### FR-3: Collaborations Entity
**Description:** Add `Collaboration` table linking two Domains (potentially across ecosystems) in a formal collaboration relationship. This is the "No Sultan" routing — lateral domain-to-domain connections.
**Acceptance Criteria:**
- Collaboration: source_domain_id, target_domain_id, collaboration_type (bilateral, service, mutual-aid, knowledge-sharing), status (proposed, active, paused, concluded), terms (JSON), initiated_by, review_date
- Dual-consent: both domains must accept (status workflow: proposed → accepted by target → active)
- Collaborations visible on Discover/Explore page
- API endpoints for proposing, accepting, declining, concluding collaborations
**Priority:** P0

### FR-4: Version Fingerprinting
**Description:** Add `version` field to Agreement, Domain (for culture codes), and any entity that represents a governance definition. Version auto-increments on update.
**Acceptance Criteria:**
- Agreement model gains `version` integer field (default 1, auto-increment on update)
- Domain model gains `culture_code_version` field
- API returns version in all relevant responses
- Version history queryable (leverages existing amendment/review records)
**Priority:** P1

### FR-5: Compliance Summary
**Description:** Add `ComplianceSummary` table. AI-generated (or manually created) summary of an ecosystem's or domain's governance health. Regenerated ad-hoc and on 30-day cron cycle.
**Acceptance Criteria:**
- ComplianceSummary: entity_type (ecosystem, domain), entity_id, summary_text, generated_at, generated_by (ai, manual), score_data (JSON), expires_at
- Cron job regenerates summaries every 30 days
- Manual trigger available via API
- AI generates summary when available; template with instructions for manual completion when AI unavailable
**Priority:** P1

### FR-6: AI Independence — OpenRouter + LiteLLM
**Description:** Replace Anthropic-only AI dependency with OpenRouter via LiteLLM proxy. All governance templates include human-readable instructions so processes work without AI.
**Acceptance Criteria:**
- Config supports: `AI_PROVIDER` (openrouter, anthropic, local, none), `AI_MODEL`, `AI_BASE_URL`, `AI_API_KEY`
- LiteLLM used as abstraction layer — single interface regardless of provider
- When `AI_PROVIDER=none`, all governance processes still work (form-based, template-based)
- Skill templates include "How to fill this out" instructions for each field
- Chat endpoint gracefully handles AI unavailability
**Priority:** P1

### FR-7: Jinja2/Datastar Removal
**Description:** Remove all Jinja2 templates, Datastar dependencies, and HTML-serving routes from the Sanic backend. API-only mode.
**Acceptance Criteria:**
- `agent/templates/` directory removed
- All `@app.get` routes serving HTML removed
- Jinja2 and Datastar dependencies removed from requirements
- Sanic serves only JSON API + static files
- No 404s on existing React routes after removal
**Priority:** P1

### FR-8: PWA Notifications via Cron
**Description:** Add background cron job infrastructure to Sanic. Push notifications to frontend via PWA service worker for time-bound governance events (consent rounds open, review dates approaching, stale requests).
**Acceptance Criteria:**
- Sanic background task scheduler (using sanic's built-in or APScheduler)
- Notification events table: member_id, event_type, title, body, read, created_at
- PWA service worker in React frontend for push notifications
- Cron jobs for: agreement review dates (7 days before), consent round deadlines, stale request detection (30 days), compliance summary regeneration (30 days)
- Notification API: list, mark-read, preferences
**Priority:** P2

### FR-9: Conflict Resolution Refinement
**Description:** Update the conflict resolution workflow to support incremental/partial proposal resolution. When a solution proposal fails, it can be decomposed into smaller proposals.
**Acceptance Criteria:**
- ConflictCase model gains: `parent_conflict_id` (for decomposition), `resolution_strategy` (full, incremental, partial)
- Proposals linked to conflicts can be marked as partial resolutions
- When a proposal fails consent, the system supports creating child proposals addressing subsets
- Agreement updates linked to resolved conflict components
- Frontend shows conflict resolution progress (which parts resolved, which pending)
**Priority:** P2

### FR-10: Culture Code Entities
**Description:** Formalize Culture Code as a structured field on Domain and Ecosystem. Culture Codes allow cultural specialization within the UAF framework.
**Acceptance Criteria:**
- Ecosystem model gains `culture_code` (JSON) and `culture_code_version` fields
- Domain model gains `culture_code` (JSON) and `culture_code_version` fields
- Culture Codes cannot contradict the UAF (validation rule)
- Culture Code viewable on domain/ecosystem detail pages
- API endpoints for updating culture codes (triggers version increment)
**Priority:** P2

## Non-Functional Requirements

### NFR-1: AI-Optional
Every governance process must be completable without AI assistance. Forms, templates, and wizards must include human-readable instructions.

### NFR-2: Windows Compatibility
All cron jobs and background tasks must work on Windows 11.

### NFR-3: 10% Test Coverage
Lightweight testing focused on critical paths: data model migrations, API contracts, collaboration dual-consent workflow, notification scheduling.

### NFR-4: No Breaking Changes to Existing API
All existing `/api/v1/` endpoints continue to work. New endpoints added alongside.

## Technical Considerations

- Alembic migrations for all new tables
- The Domain model already exists with ecosystem_id — we're enhancing it, not replacing it
- LiteLLM is a Python package that wraps 100+ LLM providers with a unified interface
- PWA service workers require HTTPS in production but work on localhost in dev
- Cron jobs in Sanic can use `app.add_task()` for simple scheduling or APScheduler for cron expressions
