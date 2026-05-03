# NEOS Platform - QA User Flows Guide

**Date:** 2026-04-28 (Updated: 2026-04-28 -- all bugs verified resolved)
**Scope:** Critical user flow paths mapped to the NEOS Operating System governance model
**Stack:** React 18 + Vite (frontend) | Python Sanic (backend) | DID Auth | SQLAlchemy + PostgreSQL/SQLite

---

## Table of Contents

1. [User Personas & Roles](#1-user-personas--roles)
2. [Flow Map: NEOS Operating System Layers](#2-flow-map-neos-operating-system-layers)
3. [Critical User Flows](#3-critical-user-flows)
4. [Gap Analysis: Intended vs. Implemented](#4-gap-analysis-intended-vs-implemented)
5. [Flow Dependencies & Sequencing](#5-flow-dependencies--sequencing)
6. [Risk Matrix](#6-risk-matrix)

---

## 1. User Personas & Roles

| Persona | Permission Level | Key Flows | Frontend Guard |
|---------|-----------------|-----------|----------------|
| **New Visitor** | None | Login, DID generation | Public routes only |
| **Member (Viewer)** | Base authenticated | Dashboard, profile, quizzes, governance read, messaging | `ProtectedRoute` |
| **Collaborator** | `manage_content`, `proxy_quiz` | Quiz management, content creation | `canManageContent` |
| **Builder / Co-Creator** | `manage_users`, `manage_content`, `proxy_quiz`, `view_analytics` | Admin panel, user management, journey maps | `canManageUsers`, `isAdmin` |
| **Domain Steward** | Contextual (domain-level) | Domain governance, agreements, proposals, onboarding ceremonies | Ecosystem-scoped |
| **Ecosystem Admin** | Full ecosystem scope | Emergency declarations, safeguards, compliance, ecosystem CRUD | Ecosystem context |

---

## 2. Flow Map: NEOS Operating System Layers

The NEOS Operating System is organized into governance layers. Each layer maps to specific user flows and frontend/backend paths.

```
NEOS Operating System
+---------------------------------------------------------------+
| LAYER I: IDENTITY & ACCESS                                     |
|   Flows: DID Auth, Session, Profile, Permissions               |
|   Status: FUNCTIONAL (minor gaps)                              |
+---------------------------------------------------------------+
| LAYER II: LEARNING & ORIENTATION                               |
|   Flows: Quizzes, Orientation Journey, Ethos Discovery         |
|   Status: FUNCTIONAL (all Supabase refs removed, stubs in place)|
+---------------------------------------------------------------+
| LAYER III: GOVERNANCE CORE                                     |
|   Flows: Agreements, Proposals (ACT), Decisions, Domains,      |
|          Members, Onboarding, Conflicts, Emergency, Exit,      |
|          Safeguards, Compliance                                 |
|   Status: FUNCTIONAL (all type/URL bugs resolved)              |
+---------------------------------------------------------------+
| LAYER IV: ECONOMIC / RESOURCE (Shares & Needs)                 |
|   Flows: Domain Shares, Domain Needs, Resource Discovery       |
|   Status: SCAFFOLDED (frontend exists, backend partial)        |
+---------------------------------------------------------------+
| LAYER V: INTER-UNIT COLLABORATION                              |
|   Flows: Cross-Ecosystem Discovery, Domain Collaborations,     |
|          Multi-Ecosystem Switching                              |
|   Status: SCAFFOLDED (frontend exists, data model incomplete)  |
+---------------------------------------------------------------+
| LAYER VI: COMMUNICATION                                        |
|   Flows: Direct Messaging, AI Chat, Notifications              |
|   Status: FUNCTIONAL (notifications PWA not wired)             |
+---------------------------------------------------------------+
```

---

## 3. Critical User Flows

### FLOW 1: Identity & First Login (Layer I)

**Goal:** New user creates a self-sovereign identity and enters the platform.

```
[Visit /login]
    |
    v
[Generate DID Keypair] -- Ed25519, stored in localStorage
    |
    v
[POST /api/v1/auth/challenge] -- server returns nonce
    |
    v
[Sign nonce with private key]
    |
    v
[POST /api/v1/auth/verify] -- server validates signature
    |                          sets neos_session cookie
    |                          creates/finds Member record
    v
[Redirect to /dashboard]
    |
    v
[AuthProvider loads member + ecosystems via GET /api/v1/auth/me]
```

**Files:**
- Frontend: `charting-the-course/client/src/pages/Login.tsx`, `contexts/AuthContext.tsx`, `lib/did-auth.ts`
- Backend: `neos-operating-system/agent/src/neos_agent/api/auth.py`, `auth/did.py`, `auth/middleware.py`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F1-01 | DID generation | Keypair stored in localStorage, DID format `did:key:z...` |
| F1-02 | Challenge issued | Server returns hex nonce, stored in `auth_challenges` with 5-min TTL |
| F1-03 | Signature verification | Valid signature -> 200 + session cookie; invalid -> 401 |
| F1-04 | Session cookie | `neos_session` cookie set as HTTPOnly, contains `{session_id}:{hmac}` |
| F1-05 | Member creation | First login creates Member record; subsequent logins find existing |
| F1-06 | Session persistence | Page reload -> `GET /auth/me` -> user stays authenticated |
| F1-07 | Returning user | Saved keypair in localStorage -> "Sign In" button (no re-generation) |
| F1-08 | Logout | `POST /auth/logout` -> cookie cleared -> redirect to `/login` |

**Gaps:**
- None. All Supabase references removed. DID auth flow is clean.

---

### FLOW 2: Dashboard & Ecosystem Context (Layer I/III)

**Goal:** Authenticated user sees governance summary scoped to their ecosystem(s).

```
[/dashboard]
    |
    v
[EcosystemContext reads cookie: neos_selected_ecosystems]
    |
    v
[GET /api/v1/dashboard/summary?ecosystem_id=...]
    |
    v
[Render summary cards: agreements, proposals, members, domains, conflicts]
    |
    v
[Click card] --> [Navigate to entity list page]
```

**Files:**
- Frontend: `pages/Dashboard.tsx`, `contexts/EcosystemContext.tsx`, `components/AppSidebar.tsx`
- Backend: `api/dashboard.py` (if exists), aggregation from multiple endpoints

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F2-01 | Dashboard loads | Summary cards render with counts |
| F2-02 | Ecosystem switching | Sidebar picker changes context, data reloads |
| F2-03 | Multi-ecosystem | Multiple ecosystems selected -> aggregated counts |
| F2-04 | Empty state | New user with no ecosystem data -> graceful message |
| F2-05 | Card navigation | Click "Proposals (5)" -> navigates to `/proposals` |

---

### FLOW 3: Orientation & Ethos Discovery (Layer II)

**Goal:** New member discovers their ethos alignment and completes orientation.

```
[/discover] -- Discover portal entry
    |
    v
[Select ethos or get matched]
    |
    v
[/orientation/:ethos_slug] -- OrientationGate (consent screen)
    |
    v
[Accept] --> [/orientation/:ethos_slug/journey]
    |
    v
[Multi-step journey:]
    |-- VideoStep (watch content)
    |-- ChoiceStep (branching decisions)
    |-- ReflectionStep (free text response)
    |-- AIConversationStep (interactive AI)
    |-- SurveyStep (SurveyJS form)
    |-- ConfirmationStep (binary choice)
    |
    [Each step: POST /api/v1/orientation/progress]
    |
    v
[All steps complete]
    |
    v
[/orientation/:ethos_slug/complete] -- Exit package with documents & tools
```

**Files:**
- Frontend: `pages/Discover.tsx`, `pages/OrientationJourney.tsx`, `pages/OrientationComplete.tsx`
- Frontend: `components/orientation/` (step type components)
- Backend: `api/discover.py`, orientation endpoints

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F3-01 | Discover loads | Page renders ethos options (RESOLVED) |
| F3-02 | Ethos detail | `/ethos/:slug/detail` renders (RESOLVED) |
| F3-03 | Orientation gate | Consent screen appears before journey starts |
| F3-04 | Journey progression | Steps render in sequence, progress saved per step |
| F3-05 | Step types | All 6 step types render and accept input |
| F3-06 | Progress persistence | Reload mid-journey -> resumes at correct step |
| F3-07 | Completion | Exit package renders documents and tools (RESOLVED) |
| F3-08 | Skip prevention | Cannot skip required steps |

**Gaps:**
- ConsentGate is a passthrough stub (TODO: implement consent tracking via backend API)
- AlignedParticipants is a placeholder stub (TODO: implement participant listing via backend API)
- No backend endpoint for ethos matching/access checking (ethos_user_access not yet implemented)

---

### FLOW 4: Proposal Lifecycle - ACT Process (Layer III)

**Goal:** Governance change proposed, advised upon, consented to, tested, and ratified.

This is the core governance workflow implementing NEOS's Advice-Consent-Test (ACT) model.

```
[/proposals/new] -- ProposalForm
    |
    v
[POST /api/v1/proposals] -- Status: "draft"
    |
    v
[/proposals/:id] -- ProposalDetail
    |
    +-- [Phase 1: ADVICE]
    |   |
    |   v
    |   [POST /api/v1/proposals/:id/status {status: "advice"}]
    |   |
    |   v
    |   [Advisors submit feedback]
    |   [POST /api/v1/proposals/:id/advice]
    |   {advisor, role, ethos, advice_type, content, concerns}
    |   |
    |   v
    |   [GET /api/v1/proposals/:id/advice] -- View all advice
    |
    +-- [Phase 2: CONSENT]
    |   |
    |   v
    |   [POST /api/v1/proposals/:id/status {status: "consent"}]
    |   |
    |   v
    |   [Consent round conducted]
    |   [POST /api/v1/proposals/:id/consent]
    |   {consent_mode, weighting_model, facilitator, participants, outcome}
    |   |
    |   v
    |   [GET /api/v1/proposals/:id/consent] -- View consent records
    |   |
    |   v
    |   [If objections: integration rounds]
    |   [If fails: decompose into smaller proposals (FR-9)]
    |
    +-- [Phase 3: TEST]
    |   |
    |   v
    |   [POST /api/v1/proposals/:id/status {status: "test"}]
    |   |
    |   v
    |   [Test period with success criteria]
    |   [GET /api/v1/proposals/:id/test] -- View test reports
    |
    +-- [Phase 4: RATIFICATION]
        |
        v
        [POST /api/v1/proposals/:id/status {status: "ratified"}]
        |
        v
        [Decision record created]
        [Agreement updated if applicable]
```

**Files:**
- Frontend: `pages/governance/proposals/ProposalForm.tsx`, `ProposalDetail.tsx`, `ProposalList.tsx`
- Frontend: `hooks/use-governance.ts` (useProposals, useSubmitAdvice, useSubmitConsent, etc.)
- Frontend: `lib/api-client.ts:108-120` (advice/consent/test fetchers)
- Backend: `api/proposals.py` (full ACT workflow)

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F4-01 | Create proposal | Form submits, proposal created with "draft" status |
| F4-02 | Draft -> Advice | Status transition succeeds, advice tab activates |
| F4-03 | Submit advice | Advice entry created with all fields |
| F4-04 | View advice | Advice list renders on detail page (RESOLVED) |
| F4-05 | Advice -> Consent | Status transition succeeds |
| F4-06 | Submit consent | Consent round recorded with participants |
| F4-07 | View consent | Consent records render (RESOLVED) |
| F4-08 | Consent -> Test | Status transition succeeds |
| F4-09 | View test reports | Test reports render (RESOLVED) |
| F4-10 | Test -> Ratified | Final status transition, decision record created |
| F4-11 | Withdrawal | Any status -> "withdrawn" works |
| F4-12 | Invalid transition | Cannot skip phases (e.g., draft -> ratified) |

**Gaps:**
- MISSING: Consent objection integration rounds (DB models exist, no frontend UI)
- MISSING: Proposal decomposition for failed consent (FR-9 not implemented)
- MISSING: Link between ratified proposal and resulting Decision/Agreement update

---

### FLOW 5: Agreement Lifecycle (Layer III)

**Goal:** Create, amend, review, and track governance agreements.

```
[/agreements/new] -- AgreementForm
    |
    v
[POST /api/v1/agreements]
    {title, type, status, domain, hierarchy_level, proposer}
    |
    v
[/agreements/:id] -- AgreementDetail
    |
    +-- [View] -- Full agreement with metadata
    +-- [Edit] -- PUT /api/v1/agreements/:id
    +-- [History] -- GET /api/v1/agreements/:id/history
    |                Shows amendment records, ratification records
    +-- [Status Change] -- POST /api/v1/agreements/:id/status
                           draft -> active -> under_review -> archived
```

**Files:**
- Frontend: `pages/governance/agreements/AgreementForm.tsx`, `AgreementDetail.tsx`, `AgreementList.tsx`, `AgreementHistory.tsx`
- Backend: `api/agreements.py`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F5-01 | Create agreement | All fields saved, redirects to detail |
| F5-02 | Edit agreement | Form pre-populated, save persists |
| F5-03 | View history | Amendment records listed chronologically |
| F5-04 | Status transitions | Valid transitions work, invalid rejected |
| F5-05 | Domain scoping | Agreement filtered by selected ecosystem |
| F5-06 | Pagination | List pagination works beyond page 1 |

**Gaps:**
- MISSING: Version fingerprinting (FR-4 not implemented -- no `version` field auto-incrementing)
- MISSING: Link from ratified proposal -> agreement update
- MISSING: Review date notifications (FR-8 cron exists but PWA push not wired to frontend)

---

### FLOW 6: Member Onboarding Ceremony (Layer III)

**Goal:** New member goes through the UAF (Universal Agreement Framework) consent ceremony.

```
[/members/new] -- MemberForm
    |
    v
[POST /api/v1/members] -- Member created with onboarding_status: "pending"
    |
    v
[/onboarding] -- OnboardingList (pending ceremonies)
    |
    v
[/onboarding/:memberId/ceremony] -- OnboardingCeremony
    |
    +-- Section 1: Ethos Alignment
    |   [POST /api/v1/onboarding/:memberId/ceremony {section: "ethos", consented: true}]
    |
    +-- Section 2: Roles & Responsibilities
    |   [POST /api/v1/onboarding/:memberId/ceremony {section: "roles", consented: true}]
    |
    +-- Section 3: Governance Agreements
    |   [POST /api/v1/onboarding/:memberId/ceremony {section: "governance", consented: true}]
    |
    +-- Section N: [Additional sections...]
    |
    v
[All sections consented]
    |
    v
[Member status: "active"]
[Cooling-off period tracked]
```

**Files:**
- Frontend: `pages/governance/onboarding/OnboardingList.tsx`, `OnboardingCeremony.tsx`
- Frontend: `pages/governance/members/MemberForm.tsx`, `MemberDetail.tsx`
- Backend: `api/onboarding.py`, `api/members.py`
- DB: `member_onboarding` table

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F6-01 | Create member | Member created with pending onboarding state |
| F6-02 | Ceremony loads | All sections render with consent toggles |
| F6-03 | Section consent | Each section can be individually consented |
| F6-04 | Progress tracking | Partial completion persisted across sessions |
| F6-05 | Completion | All sections consented -> member status transitions |
| F6-06 | Cooling-off | Period dates set and enforced |

---

### FLOW 7: Conflict Resolution (Layer III)

**Goal:** Report a conflict, propose solutions, resolve incrementally.

```
[/conflicts/new] -- ConflictForm
    |
    v
[POST /api/v1/conflicts]
    {title, description, severity, urgency, parties, safety_flag}
    |
    v
[/conflicts/:id] -- ConflictDetail
    |
    +-- [View case details, parties, timeline]
    +-- [Link to proposal] -- Create proposal as solution
    |   |
    |   v
    |   [Proposal goes through ACT process (Flow 4)]
    |   |
    |   +-- [If consent fails] --> [Decompose into smaller proposals]
    |   +-- [If consent succeeds] --> [Repair agreement created]
    |
    +-- [Repair Agreement]
        [PUT /api/v1/conflicts/:id] -- Add repair_agreement
        |
        v
        [Agreement updated with conflict resolution]
```

**Files:**
- Frontend: `pages/governance/conflicts/ConflictForm.tsx`, `ConflictDetail.tsx`, `ConflictList.tsx`
- Backend: `api/conflicts.py`
- DB: `conflict_cases`, `repair_agreement_records`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F7-01 | Report conflict | All fields saved, severity/urgency badges |
| F7-02 | Safety flag | Flag prominently displayed when set |
| F7-03 | View detail | Full case info with parties and timeline |
| F7-04 | Link to proposal | Can create a proposal linked to this conflict |
| F7-05 | Repair agreement | Repair agreement saved to conflict record |

**Gaps:**
- MISSING: `parent_conflict_id` for decomposition (FR-9 not implemented)
- MISSING: Incremental/partial proposal resolution workflow
- MISSING: Frontend showing "which parts resolved, which pending"
- MISSING: Auto-link between proposal outcome and conflict status

---

### FLOW 8: Emergency Circuit Breaker (Layer III)

**Goal:** Declare governance emergency, trigger circuit breaker, resolve.

```
[/emergency] -- EmergencyDashboard
    |
    +-- [Normal state: "System Normal" display]
    +-- [Declare Emergency]
        |
        v
        [POST /api/v1/emergency/declare]
        {ecosystem_id, declared_by, reason, auto_revert_days}
        |
        v
        [Emergency state: "open"]
        [Auto-revert timer set]
        |
        v
        [/emergency/:id] -- EmergencyDetail
        |
        +-- [View: declared_by, time, reason, actions_log]
        +-- [Resolve: POST /api/v1/emergency/:id/resolve]
            |
            v
            [Emergency state: "closed"]
            [Post-review triggered]
```

**Files:**
- Frontend: `pages/governance/emergency/EmergencyDashboard.tsx`, `EmergencyDetail.tsx`
- Frontend: `lib/api-client.ts:265-278`
- Backend: `api/emergency.py`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F8-01 | Dashboard loads | Current state renders (RESOLVED) |
| F8-02 | Declare emergency | Form submits to correct URL (RESOLVED) |
| F8-03 | Active display | Shows declared_by, time, reason (RESOLVED) |
| F8-04 | Resolve emergency | State transitions to closed |
| F8-05 | Auto-revert | Timer triggers automatic resolution |
| F8-06 | Emergency detail | Full detail page renders (RESOLVED) |

**Gaps:**
- None. All type/URL mismatches resolved. Emergency flow fully unblocked.

---

### FLOW 9: Cross-Ecosystem Discovery & Collaboration (Layer IV/V)

**Goal:** Discover resources across ecosystems, propose collaborations.

```
[/explore] -- DiscoverHub
    |
    v
[GET /api/v1/discover?section=ecosystems,shares-needs,collaborations]
    |
    +-- [Ecosystems Tab] -- Browse public ecosystems
    +-- [Shares & Needs Tab] -- View domain shares/needs
    +-- [Collaborations Tab] -- Active collaborations
    |
    v
[/discover/shares-needs/new] -- Post a Share or Need
    |
    v
[POST /api/v1/discover/shares-needs]
    {domain_id, type, title, description, category, tags}
    |
    v
[/discover/collaborations/new] -- Propose Collaboration
    |
    v
[POST /api/v1/discover/collaborations]
    {source_domain_id, target_domain_id, title, description, engagement_tier, terms}
    |
    v
[Collaboration status: "proposed"]
    |
    v
[Target domain accepts] -- Status: "active"
    |
    v
[/discover/collaborations/:id] -- CollaborationDetail
```

**Files:**
- Frontend: `pages/discover/DiscoverHub.tsx` (or `pages/DiscoverHub.tsx`), `SharesNeedsForm.tsx`, `CollaborationForm.tsx`, `CollaborationDetail.tsx`
- Frontend: `hooks/use-discover.ts`
- Backend: `api/discover.py`
- DB: `shares_needs`, `collaborations`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F9-01 | DiscoverHub loads | Tabs render with ecosystem/shares/collab data |
| F9-02 | Search/filter | Search term filters results across sections |
| F9-03 | Post share/need | Created and visible in discover feed |
| F9-04 | Propose collaboration | Collaboration created with "proposed" status |
| F9-05 | Accept collaboration | Target domain can accept -> status "active" |
| F9-06 | Collaboration detail | Full terms and status rendered |
| F9-07 | Cross-ecosystem visibility | Shares from other ecosystems appear in discover |

**Gaps:**
- MISSING: `DomainShare` and `DomainNeed` as separate entities (FR-2 -- currently `shares_needs` is a single table)
- MISSING: Dual-consent workflow for collaborations (FR-3 -- target domain acceptance flow)
- MISSING: Engagement tier display and terms rendering
- MISSING: Cross-ecosystem visibility filtering (public vs private ecosystems)
- PARTIAL: Backend discover endpoint exists but may not fully support all filter combinations

---

### FLOW 10: Quiz & Learning (Layer II)

**Goal:** Take assessments, earn badges, build profile tiles.

```
[/quizzes] -- QuizList
    |
    v
[Select quiz]
    |
    v
[/quiz/take/:id] -- TakeQuiz (SurveyJS)
    |
    v
[Complete all questions]
    |
    v
[POST /api/v1/quizzes/:id/results]
    {survey_results: JSON, time_spent: ms}
    |
    v
[/quiz/results/:id] -- Results page
    |
    v
[Score calculated, badges awarded, profile tiles generated]
    |
    v
[Profile updated with new tiles and achievements]
```

**Files:**
- Frontend: `pages/QuizList.tsx`, `pages/TakeQuiz.tsx` (SurveyJS), `pages/QuizResults.tsx`
- Frontend: `hooks/use-courses.ts`
- Backend: `api/quizzes.py`, `api/courses.py`
- DB: `quizzes`, `quiz_results`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F10-01 | Quiz catalog | Published quizzes listed with metadata |
| F10-02 | Take quiz | SurveyJS renders, all question types work |
| F10-03 | Submit results | Results saved with score and time |
| F10-04 | Results page | Score, pass/fail, badges displayed |
| F10-05 | Profile tiles | Auto-generated tiles appear on profile |
| F10-06 | Quiz history | `/my-quiz-history` shows past attempts |
| F10-07 | Time limit | Timed quizzes enforce the limit |
| F10-08 | Retakes | Allowed quizzes permit new attempts |

---

### FLOW 11: Messaging & Communication (Layer VI)

**Goal:** Real-time direct messaging between members.

```
[FloatingComms FAB (bottom-right)] or [/messaging]
    |
    v
[GET /api/v1/messaging/conversations] -- Conversation list
    |
    v
[Select conversation] or [Create new]
    |
    v
[GET /api/v1/messaging/conversations/:id] -- Messages load
    |
    v
[WebSocket connect: /messaging/ws]
    |
    v
[Type message]
    |-- [Send typing indicator via WS]
    |
    v
[Send message via WS]
    |
    v
[Message stored in DB, broadcast to participants]
    |
    v
[Recipient sees message in real-time]
    |
    v
[Read receipt via WS]
```

**Files:**
- Frontend: `components/FloatingComms.tsx`, `pages/messaging/` (if exists)
- Frontend: `hooks/use-messaging.ts`
- Backend: `api/messaging.py`, `messaging/routes.py`, `messaging/handlers.py`, `messaging/connections.py`
- DB: `conversations`, `messages`, `conversation_participants`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F11-01 | Conversation list | Conversations load with unread badges |
| F11-02 | Send message | Message sent and appears in thread |
| F11-03 | WebSocket realtime | Two users see messages in real-time |
| F11-04 | Typing indicator | Typing status shown to other participant |
| F11-05 | Read receipt | Message marked as read when viewed |
| F11-06 | Create conversation | New conversation created with participant |
| F11-07 | FloatingComms | FAB opens messaging panel inline |

---

### FLOW 12: AI-Assisted Governance (Layer VI)

**Goal:** AI assists with governance text generation and chat.

```
[Any governance form with AI textarea]
    |
    v
[Click "AI Assist"]
    |
    v
[POST /api/v1/ai/generate]
    {context, field_name, current_text}
    |
    v
[AI generates suggestion]
    |
    v
[User reviews and accepts/edits]

--- OR ---

[/chat] -- AI Chat Panel
    |
    v
[POST /api/v1/chat] (SSE streaming)
    |
    v
[AI response streams token by token]
    |
    v
[Response complete, stored in chat history]
```

**Files:**
- Frontend: `hooks/use-chat.ts`, `components/omnibot/`
- Backend: `api/ai_assist.py`, `api/chat.py`, `ai/provider.py`
- Config: `AI_PROVIDER`, `AI_MODEL`, `AI_BASE_URL`, `AI_API_KEY`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F12-01 | AI assist in form | Text generated and inserted into field |
| F12-02 | Chat streaming | SSE delivers tokens progressively |
| F12-03 | Chat history | Previous messages persist across reloads |
| F12-04 | AI unavailable | Graceful fallback when `AI_PROVIDER=none` |
| F12-05 | Provider switching | Works with OpenRouter, Anthropic, local models |

---

### FLOW 13: Domain Management & Culture Code (Layer III)

**Goal:** Create and manage governance domains with stewards and culture codes.

```
[/domains/new] -- DomainForm
    |
    v
[POST /api/v1/domains]
    {name, description, domain_type, stewards, ecosystem_id}
    |
    v
[/domains/:id] -- DomainDetail
    |
    +-- [View domain elements, metrics, stewards]
    +-- [Edit domain] -- PUT /api/v1/domains/:id (BLOCKED: BUG-010)
    +-- [Culture Code] -- (NOT YET IMPLEMENTED)
    +-- [Domain Membership] -- (NOT YET IMPLEMENTED)
```

**Files:**
- Frontend: `pages/governance/domains/DomainForm.tsx`, `DomainDetail.tsx`, `DomainList.tsx`
- Backend: `api/domains.py`
- DB: `domains`, `domain_elements`, `domain_metrics`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F13-01 | Create domain | Domain created with type and stewards |
| F13-02 | Domain detail | Elements and metrics render |
| F13-03 | Edit domain | Form pre-populated, save works (RESOLVED) |
| F13-04 | Domain types | circle, ethos, shur, working-group selectable |

**Gaps:**
- MISSING: `DomainMembership` table and CRUD (FR-1)
- MISSING: `domain_type` enum on model (FR-1)
- MISSING: `parent_domain_id` for nesting (FR-1)
- MISSING: `culture_code` JSON field (FR-10)
- MISSING: Quorum computation based on domain membership

---

### FLOW 14: Member Exit & Portability (Layer III)

**Goal:** Structured member exit with knowledge transfer and data portability.

```
[/exit/new] -- ExitForm
    |
    v
[POST /api/v1/exit]
    {member_id, exit_type, reason, transition_plan}
    |
    v
[/exit/:id] -- ExitDetail
    |
    +-- [Unwinding tracker: knowledge transfer, handoffs]
    +-- [Status updates: PUT /api/v1/exit/:id]
    +-- [Final transition]
        |
        v
        [Member status transitions to "exited"]
        [Data portability package generated (future)]
```

**Files:**
- Frontend: `pages/governance/exit/ExitForm.tsx`, `ExitDetail.tsx`, `ExitList.tsx`
- Backend: `api/exit.py`
- DB: `exit_records`

**Test Points:**
| ID | Checkpoint | Verify |
|----|-----------|--------|
| F14-01 | Create exit | Exit record created with type and reason |
| F14-02 | Exit detail | Unwinding tracker renders |
| F14-03 | Status updates | Status transitions persist |
| F14-04 | Exit list | All exit records listed with status filters |

---

## 4. Gap Analysis: Intended vs. Implemented

### Layer-by-Layer Gap Summary

| # | Feature (from Spec) | Spec Ref | Frontend | Backend | DB | Status | Severity |
|---|---------------------|----------|----------|---------|-----|--------|----------|
| G-01 | DomainMembership (members in domains) | FR-1 | None | None | Missing table | NOT STARTED | P0 |
| G-02 | Domain type enum (circle, ethos, shur, etc.) | FR-1 | None | None | Missing column | NOT STARTED | P0 |
| G-03 | Domain nesting (parent_domain_id) | FR-1 | None | None | Missing column | NOT STARTED | P0 |
| G-04 | DomainShare / DomainNeed as separate entities | FR-2 | Partial (single form) | Partial (shares_needs table) | Partial | SCAFFOLDED | P0 |
| G-05 | Cross-ecosystem share/need visibility | FR-2 | None (no filter) | No public flag | Missing | NOT STARTED | P0 |
| G-06 | Collaboration dual-consent workflow | FR-3 | Form exists | No accept/decline endpoints | Missing status workflow | PARTIAL | P0 |
| G-07 | Version fingerprinting on Agreement/Domain | FR-4 | None | None | Missing columns | NOT STARTED | P1 |
| G-08 | ComplianceSummary entity | FR-5 | Page exists | Partial endpoint | Table exists | PARTIAL | P1 |
| G-09 | AI independence (OpenRouter + LiteLLM) | FR-6 | N/A | DONE (provider.py) | N/A | COMPLETE | -- |
| G-10 | Jinja2/Datastar removal | FR-7 | N/A | Mostly done | N/A | NEARLY COMPLETE | P1 |
| G-11 | PWA push notifications | FR-8 | No service worker | Cron + push_subscriptions exist | Table exists | PARTIAL | P2 |
| G-12 | Conflict decomposition (parent_conflict_id) | FR-9 | None | None | Missing column | NOT STARTED | P2 |
| G-13 | Culture Code on Domain/Ecosystem | FR-10 | None | None | Missing columns | NOT STARTED | P2 |
| G-14 | Notification events table | FR-8 | None | No events table | Missing | NOT STARTED | P2 |

### Bug-Induced Gaps (All Resolved as of 2026-04-28)

All 14 bugs from the original QA-TEST-PLAN.md (BUG-001 through BUG-014) have been verified as resolved:
- Supabase references fully removed from all frontend files (BUG-001, 005, 006, 008, 009)
- Emergency API URL, types, and response shape aligned (BUG-002, 003, 004)
- EthosDetail imports and constants defined (BUG-006, 007)
- Proposal response unwrapping implemented (BUG-011)
- useUpdateDomain hook exported (BUG-010)
- OrientationComplete property names match type definitions (BUG-012)
- No remaining blocked test cases from bugs.

---

## 5. Flow Dependencies & Sequencing

The following diagram shows which flows must work before others can be tested:

```
FLOW 1 (Auth)
    |
    +---> FLOW 2 (Dashboard) ------+
    |                              |
    +---> FLOW 3 (Orientation) ----+---> FLOW 10 (Quiz)
    |                              |
    +---> FLOW 13 (Domains) -------+---> FLOW 6 (Onboarding)
    |         |                    |
    |         +---> FLOW 9 (Discovery/Collaboration)
    |         |
    +---> FLOW 5 (Agreements) <----+---> FLOW 4 (Proposals ACT)
    |                              |
    +---> FLOW 7 (Conflicts) ------+
    |
    +---> FLOW 8 (Emergency)
    |
    +---> FLOW 11 (Messaging)
    |
    +---> FLOW 12 (AI Chat)
    |
    +---> FLOW 14 (Exit)
```

**Critical Path:** Auth -> Dashboard -> Domains -> Proposals (ACT) -> Agreements

**Testing Order (Recommended):**
1. Flow 1: Auth (prerequisite for everything)
2. Flow 2: Dashboard (validates ecosystem context)
3. Flow 13: Domains (prerequisite for proposals, collaboration)
4. Flow 5: Agreements (core governance)
5. Flow 4: Proposals ACT (core governance workflow)
6. Flow 6: Onboarding (member lifecycle)
7. Flow 7: Conflicts (governance integrity)
8. Flow 10: Quiz (learning module)
9. Flow 11: Messaging (communication)
10. Flow 8: Emergency (after bugs fixed)
11. Flow 3: Orientation (after bugs fixed)
12. Flow 9: Discovery (after data model complete)
13. Flow 12: AI Chat (requires AI provider config)
14. Flow 14: Exit (member lifecycle completion)

---

## 6. Risk Matrix

### Flow Health Summary

| Flow | Layer | Health | Blocking Bugs | Missing Spec Features | Test Readiness |
|------|-------|--------|---------------|----------------------|----------------|
| F1: Auth | I | GREEN | None | None | 8/8 ready |
| F2: Dashboard | I/III | GREEN | None | None | 4/4 ready |
| F3: Orientation | II | GREEN | None | Ethos matching API (stub), ConsentGate (stub) | 8/8 ready |
| F4: Proposals ACT | III | GREEN | None | FR-9 decomposition | 12/12 ready |
| F5: Agreements | III | GREEN | None | FR-4 versioning | 6/6 ready |
| F6: Onboarding | III | GREEN | None | None | 4/4 ready |
| F7: Conflicts | III | GREEN | None | FR-9 decomposition | 5/5 ready |
| F8: Emergency | III | GREEN | None | None | 6/6 ready |
| F9: Discovery | IV/V | YELLOW | None | FR-1,2,3 data model | 7/7 ready |
| F10: Quiz | II | GREEN | None | None | 8/8 ready |
| F11: Messaging | VI | GREEN | None | None | 7/7 ready |
| F12: AI Chat | VI | GREEN | None | None (FR-6 done) | 5/5 ready |
| F13: Domains | III | GREEN | None | FR-1,10 enhancements | 4/4 ready |
| F14: Exit | III | GREEN | None | None | 4/4 ready |

### Priority Fix Sequence

**Wave 1 & 2 -- Bug Fixes: ALL COMPLETE (verified 2026-04-28)**
All 14 bugs (BUG-001 through BUG-014) resolved. Zero blocked test cases remaining.

**Wave 3 -- Implement missing data model (P0 spec features):**
1. FR-1: DomainMembership table + API + frontend
2. FR-2: DomainShare/DomainNeed entities
3. FR-3: Collaboration dual-consent workflow

**Wave 4 -- Polish & hardening (P1-P2 spec features):**
4. FR-4: Version fingerprinting
5. FR-8: PWA service worker + notification events
6. FR-9: Conflict decomposition
7. FR-10: Culture Code entities

**Wave 5 -- Stub implementations (functional but incomplete):**
8. ConsentGate: Implement consent tracking via backend API
9. AlignedParticipants: Implement participant listing via backend API
10. Ethos user access/matching: Backend endpoint for ethos access control

---

## Appendix A: Route-to-Flow Mapping

| Route | Flow | Layer |
|-------|------|-------|
| `/login` | F1 | I |
| `/dashboard`, `/` | F2 | I/III |
| `/discover` | F3 | II |
| `/ethos/:slug/detail` | F3 | II |
| `/orientation/:slug` | F3 | II |
| `/orientation/:slug/journey` | F3 | II |
| `/orientation/:slug/complete` | F3 | II |
| `/proposals`, `/proposals/new`, `/proposals/:id` | F4 | III |
| `/agreements`, `/agreements/new`, `/agreements/:id` | F5 | III |
| `/onboarding`, `/onboarding/:id/ceremony` | F6 | III |
| `/conflicts`, `/conflicts/new`, `/conflicts/:id` | F7 | III |
| `/emergency`, `/emergency/:id` | F8 | III |
| `/explore` | F9 | IV/V |
| `/discover/hub` | F9 | IV/V |
| `/discover/shares-needs/new` | F9 | IV |
| `/discover/collaborations/new`, `/discover/collaborations/:id` | F9 | V |
| `/quizzes`, `/quiz/take/:id`, `/quiz/results/:id` | F10 | II |
| `/messaging` | F11 | VI |
| `/chat` | F12 | VI |
| `/domains`, `/domains/new`, `/domains/:id` | F13 | III |
| `/exit`, `/exit/new`, `/exit/:id` | F14 | III |
| `/members`, `/members/new`, `/members/:id` | F6 | III |
| `/decisions`, `/decisions/:id` | F4/F5 | III |
| `/safeguards`, `/safeguards/audits` | F5 | III |
| `/compliance` | F5 | III |
| `/profile` | F1 | I |
| `/users/:username` | F1 | I |
| `/settings/notifications` | F11 | VI |
| `/admin`, `/admin/users` | Admin | I |
| `/quiz/manage` | F10 | II |
| `/admin/journey-maps` | F3 | II |
| `/map` | F10 | II |

---

## Appendix B: API Contract Quick Reference

| Endpoint Pattern | Method | Flow | Notes |
|-----------------|--------|------|-------|
| `/auth/challenge` | POST | F1 | DID -> nonce |
| `/auth/verify` | POST | F1 | DID + signature -> session |
| `/auth/me` | GET | F1 | Session -> member + ecosystems |
| `/auth/logout` | POST | F1 | Destroy session |
| `/dashboard/summary` | GET | F2 | Aggregated counts |
| `/agreements[/:id]` | CRUD | F5 | + `/history`, `/status` |
| `/proposals[/:id]` | CRUD | F4 | + `/status`, `/advice`, `/consent`, `/test` |
| `/members[/:id]` | CRUD | F6 | + `/onboarding`, `/badges`, `/tags` |
| `/domains[/:id]` | CRUD | F13 | |
| `/decisions[/:id]` | GET | F4/F5 | Read-only |
| `/onboarding[/:id]` | GET/POST | F6 | Ceremony flow |
| `/conflicts[/:id]` | CRUD | F7 | |
| `/ecosystems[/:id]` | CRUD | F2 | |
| `/emergency[/:id]` | GET | F8 | + `/declare`, `/resolve` |
| `/exit[/:id]` | CRUD | F14 | |
| `/safeguards/audits[/:id]` | GET | F5 | |
| `/compliance` | GET | F5 | |
| `/discover` | GET | F9 | Multi-section query |
| `/discover/shares-needs` | CRUD | F9 | |
| `/discover/collaborations[/:id]` | CRUD | F9 | |
| `/quizzes[/:id]` | CRUD | F10 | + `/results` |
| `/messaging/conversations[/:id]` | CRUD | F11 | |
| `/messaging/ws` | WS | F11 | WebSocket |
| `/chat` | POST (SSE) | F12 | Streaming |
| `/ai/generate` | POST | F12 | Form assistance |
| `/notifications` | CRUD | F11 | Push subscriptions |
| `/skills` | GET | -- | Skill registry |
| `/health` | GET | -- | Service health |

---

*Generated: 2026-04-28 | NEOS Platform QA User Flows Guide v1.0*
