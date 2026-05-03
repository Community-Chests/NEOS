# NEOS Tracks

## Active

- [ ] **multi_ecosystem_collaboration_20260425** — Multi-Ecosystem Collaboration & Platform Hardening
  - Data model (CircleMembership, Shares/Needs, Collaborations, Culture Code), AI independence (OpenRouter/LiteLLM), Jinja2 removal (React only), inter-unit discovery, "No Sultan" routing, conflict resolution refinement, PWA notifications, compliance summaries, version fingerprinting. 7 phases, 51 tasks.
  - Spec: `conductor/tracks/multi_ecosystem_collaboration_20260425/spec.md`
  - Plan: `conductor/tracks/multi_ecosystem_collaboration_20260425/plan.md`
  - Priority: P0
  - Status: Not started

- [ ] **monorepo_bff_setup_20260403** — Monorepo + BFF Setup
  - Convert NEOS into a monorepo with BFF architecture. Consolidate git repos, set up dev tooling, define API contract, remove legacy Express/Supabase/Drizzle deps, add Railway config.
  - Spec: `conductor/tracks/monorepo_bff_setup_20260403/spec.md`
  - Plan: `conductor/tracks/monorepo_bff_setup_20260403/plan.md`
  - Priority: P0
  - Status: Mostly complete (Phase 1-2 done, Phase 3 partial)

## Backlog

- [ ] **frontend_migration_20260403** — Frontend Migration: Sanic/Jinja2 to React (PARTIALLY SUPERSEDED)
  - Jinja2 removal now covered by multi_ecosystem_collaboration_20260425 Phase 3. Remaining scope: course migration, integration cleanup.
  - Spec: `conductor/tracks/frontend_migration_20260403/spec.md`
  - Plan: `conductor/tracks/frontend_migration_20260403/plan.md`
  - Priority: P1
  - Status: Partially superseded by multi_ecosystem_collaboration_20260425
  - Depends on: multi_ecosystem_collaboration_20260425

- [ ] **supabase_removal_feature_migration_20260403** — Supabase Removal & Feature Migration (SUPERSEDED)
  - Superseded by frontend_migration_20260403 which covers the same scope with more detail.
  - Spec: `conductor/tracks/supabase_removal_feature_migration_20260403/spec.md`
  - Plan: `conductor/tracks/supabase_removal_feature_migration_20260403/plan.md`
  - Priority: P2
  - Status: Superseded by frontend_migration_20260403

## Completed

(none yet)
