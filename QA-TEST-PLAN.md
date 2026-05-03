# NEOS Platform - Comprehensive QA Test Plan & Bug Report

**Date:** 2026-04-23 (Updated: 2026-04-28 -- all bugs verified resolved)
**App URL:** http://localhost:5173/
**Stack:** React 18 + Vite (frontend) | Python Sanic (backend) | SQLite/PostgreSQL

---

## PART 1: BUGS FOUND (Prioritized)

> **STATUS UPDATE (2026-04-28):** All 14 bugs below have been verified as RESOLVED.
> Supabase references fully removed. Emergency types/URLs aligned. All hooks exported.
> All previously blocked test cases are now unblocked and ready for execution.

### CRITICAL - App-Breaking Bugs (ALL RESOLVED)

#### BUG-001: Discover Page Crash (Reported: "times out")
**Files:** `charting-the-course/client/src/pages/Discover.tsx:30,38`
**Root Cause:** Page references `useSupabaseAuth()` and `supabase` client which **do not exist** in the codebase. The app uses DID-based auth (`useAuth` from `AuthContext`), not Supabase. The module `@/lib/supabase` and hook `@/hooks/useSupabaseAuth` were never created after the auth migration.
**Symptom:** Runtime crash -> React error boundary -> appears to "time out" as React Query retries the failed render.
**Impact:** Entire `/discover` page is non-functional.
**Fix Required:**
- Replace `useSupabaseAuth()` with `useAuth()` from `@/contexts/AuthContext`
- Replace `supabase.from('ethos_user_access')` query with a proper API client call (add `fetchEthosAccess()` to `api-client.ts`, add corresponding backend endpoint or use existing discover API)
- Update property references from `user.id` to `member.id`

#### BUG-002: Emergency Submission Fails (Reported: "error on submission")
**Files:**
- Frontend: `charting-the-course/client/src/lib/api-client.ts:271-272`
- Backend: `neos-operating-system/agent/src/neos_agent/api/emergency.py:204`
**Root Cause:** THREE compounding issues:
1. **URL Mismatch:** Frontend POSTs to `POST /api/v1/emergency`, backend expects `POST /api/v1/emergency/declare`
2. **Missing Required Field:** Backend requires `declared_by: str` but frontend never sends it
3. **Field Name Mismatch:** Frontend sends `{ reason, auto_revert_days, ecosystem_id }` but backend expects `{ ecosystem_id (required UUID), declared_by (required), reason, auto_revert_days }`
**Fix Required:**
- Change frontend `declareEmergency` URL from `/api/v1/emergency` to `/api/v1/emergency/declare`
- Add `declared_by` field (populate from current member's display_name or DID)

#### BUG-003: Emergency State Response Type Mismatch
**Files:**
- Frontend types: `charting-the-course/client/src/types/api.ts:483-493`
- Backend schema: `neos-operating-system/agent/src/neos_agent/api/emergency.py:35-53`
**Root Cause:** Frontend `EmergencyState` type does not match backend response at all:

| Frontend Field    | Backend Field       | Match? |
|-------------------|---------------------|--------|
| `is_active`       | `state` (string)    | MISMATCH - frontend expects boolean, backend returns "open"/"closed" |
| `reason`          | `notes`             | MISMATCH - different field name |
| `auto_revert_days`| `auto_revert_at`    | MISMATCH - frontend expects days (number), backend returns datetime |
| `resolved_at`     | `closed_at`         | MISMATCH - different field name |
| `resolved_by`     | (not returned)      | MISSING from backend |
| `declared_by`     | `declared_by`       | OK |
| `declared_at`     | `declared_at`       | OK |

**Impact:** Even if the GET succeeds, all data rendering on EmergencyDashboard is broken (wrong field names).
**Fix Required:** Align frontend types with backend response, or add a mapping layer.

#### BUG-004: Emergency GET Endpoint Response Mismatch
**Files:**
- Frontend: `charting-the-course/client/src/lib/api-client.ts:265-266`
- Backend: `neos-operating-system/agent/src/neos_agent/api/emergency.py:134-178`
**Root Cause:** Frontend `fetchEmergencyState()` expects a single `EmergencyState` object. Backend returns `{ current, items, total, page, per_page }` (paginated list with nested current state).
**Impact:** Frontend tries to read `data.is_active` but gets `{ current: {...}, items: [...] }`.

#### BUG-005: ConsentGate & AlignedParticipants - Same Supabase Dependency
**Files:**
- `charting-the-course/client/src/components/discovery/ConsentGate.tsx:3-4`
- `charting-the-course/client/src/components/discovery/AlignedParticipants.tsx:85`
**Root Cause:** Same as BUG-001 — these components import from `@/lib/supabase` and `@/hooks/useSupabaseAuth` which don't exist.
**Impact:** Any page using ConsentGate or AlignedParticipants crashes.

#### BUG-006: EthosDetail - Missing ConsentGate Import
**File:** `charting-the-course/client/src/pages/EthosDetail.tsx:73,266`
**Root Cause:** `ConsentGate` component used but never imported.
**Impact:** `/ethos/:slug/detail` page crashes with "ConsentGate is not defined".

#### BUG-007: EthosDetail - Undefined PHASE_LABELS
**File:** `charting-the-course/client/src/pages/EthosDetail.tsx:114-115`
**Root Cause:** `PHASE_LABELS` constant referenced but never defined in file or imported.
**Impact:** Runtime error when rendering ethos phase badge.

#### BUG-008: useDID Hook - Supabase Dependency
**File:** `charting-the-course/client/src/hooks/useDID.ts:5,16`
**Root Cause:** References `useSupabaseAuth()` and `supabase.functions.invoke` without imports, and these modules don't exist.
**Impact:** DID initialization fails silently or crashes.

### HIGH - Functional Bugs

#### BUG-009: AdminPanel - Multiple Supabase References
**File:** `charting-the-course/client/src/pages/AdminPanel.tsx:278,304,521-522,537,553,694`
**Root Cause:** At least 6 direct `supabase` calls for ethos_user_access management, ctc_handoff, and admin functions.
**Impact:** Admin-only features (ethos access grants, user management) are non-functional.

#### BUG-010: DomainForm - Missing useUpdateDomain Hook
**Files:**
- `charting-the-course/client/src/pages/governance/domains/DomainForm.tsx:10,72`
- `charting-the-course/client/src/hooks/use-governance.ts` (missing export)
**Root Cause:** `useUpdateDomain` hook does not exist. DomainForm imports `useCreateDomain` but uses `updateMutation` for edit mode.
**Impact:** Domain edit mode crashes.

#### BUG-011: Proposal Advice/Consent/Test Response Wrapper Mismatch
**Files:**
- Frontend: `charting-the-course/client/src/lib/api-client.ts:108,114,120`
- Backend: proposals.py
**Root Cause:** Frontend expects direct arrays (`AdviceLog[]`, `ConsentRecord[]`, `TestReport[]`), backend wraps in objects (`{ advice_logs: [...] }`, `{ consent_records: [...] }`, `{ test_reports: [...] }`).
**Impact:** Advice, consent, and test report data never renders on ProposalDetail page.

#### BUG-012: OrientationComplete - Wrong Property Names
**File:** `charting-the-course/client/src/pages/OrientationComplete.tsx:80,96,122`
**Root Cause:** References `pkg.docs` (should be `pkg.documents`), `doc.title` (should be `doc.label`), `tool.name` (should be `tool.label`).
**Impact:** Exit package resources don't render after orientation completion.

### MEDIUM - Degraded Functionality

#### BUG-013: Ecosystems List Missing Pagination Fields
**Backend:** `neos-operating-system/agent/src/neos_agent/api/ecosystems.py:133-136`
**Root Cause:** Returns `{ ecosystems, total }` but no `page`/`per_page` fields.
**Impact:** Frontend pagination controls may not work for ecosystem lists.

#### BUG-014: EcosystemForm Variable Shadowing
**File:** `charting-the-course/client/src/pages/governance/ecosystems/EcosystemForm.tsx:39`
**Root Cause:** Uses `setLocation_` to avoid collision with wouter's `setLocation`.
**Impact:** Works but fragile; could break on refactoring.

---

## PART 2: COMPREHENSIVE QA TEST PLAN

### Test Area 1: Authentication Flow

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| AUTH-01 | DID key generation | Visit /login, click "Create Identity" | DID key pair generated, stored in localStorage | P0 |
| AUTH-02 | Challenge-response login | Enter DID, sign challenge | Session cookie set, redirect to /dashboard | P0 |
| AUTH-03 | Session persistence | Reload page after login | User remains authenticated | P0 |
| AUTH-04 | Logout | Click logout | Session cleared, redirect to /login | P0 |
| AUTH-05 | Protected route redirect | Visit /dashboard while unauthenticated | Redirect to /login | P0 |
| AUTH-06 | Session expiry | Wait 24h or manually expire | Graceful re-auth prompt | P1 |
| AUTH-07 | Invalid DID signature | Tamper with signature during verify | 401 error, user-friendly message | P1 |

### Test Area 2: Dashboard

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| DASH-01 | Dashboard loads | Navigate to / or /dashboard | Summary cards render with counts | P0 |
| DASH-02 | Activity feed | Check activity section | Recent activity items display with correct links | P1 |
| DASH-03 | Card navigation | Click summary card | Navigate to correct list page | P1 |
| DASH-04 | Empty state | Login as new user with no data | Graceful empty state messages | P2 |

### Test Area 3: Discover & Ethos (UNBLOCKED by BUG-001, BUG-005, BUG-006, BUG-007)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| DISC-01 | Discover page loads | Navigate to /discover | Page renders without crash | P0 - UNBLOCKED |
| DISC-02 | Non-admin no access | Login as regular user with no ethos access | "Not matched" message | P0 - UNBLOCKED |
| DISC-03 | Admin ethos selector | Login as admin, visit /discover | Dropdown with all ethos options | P1 - UNBLOCKED |
| DISC-04 | Aligned participants | View ethos with participants | Participant cards render | P1 - UNBLOCKED |
| DISC-05 | Consent gate | Navigate to ethos detail first time | Consent dialog appears | P1 - UNBLOCKED |
| DISC-06 | DiscoverHub search | Navigate to /explore, type search | Filtered quizzes/ecosystems display | P1 |
| DISC-07 | DiscoverHub tabs | Switch between quizzes/ecosystems tabs | Correct content per tab | P1 |
| DISC-08 | EthosDetail page | Navigate to /ethos/:slug/detail | Page renders with solution details | P0 - UNBLOCKED |

### Test Area 4: Emergency Circuit Breaker (UNBLOCKED by BUG-002, BUG-003, BUG-004)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| EMER-01 | Emergency dashboard loads | Navigate to /emergency | Shows "System Normal" status | P0 - UNBLOCKED |
| EMER-02 | Declare emergency | Fill form, click "Declare Emergency" | Emergency created, redirects to detail | P0 - UNBLOCKED |
| EMER-03 | Validation - empty reason | Submit without reason | "Reason is required" error | P1 - UNBLOCKED |
| EMER-04 | Validation - invalid days | Enter 0 or negative days | "Must be at least 1 day" error | P1 - UNBLOCKED |
| EMER-05 | Active emergency display | View dashboard with active emergency | Shows declared_by, time, reason | P1 - UNBLOCKED |
| EMER-06 | Resolve emergency | Click resolve on active emergency | State changes to closed | P1 - UNBLOCKED |
| EMER-07 | Emergency detail page | Navigate to /emergency/:id | Full detail renders | P1 - UNBLOCKED |

### Test Area 5: Governance - Agreements

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| AGR-01 | Agreement list loads | Navigate to /agreements | Paginated list renders | P0 |
| AGR-02 | Create agreement | Fill AgreementForm, submit | New agreement created, redirects to detail | P0 |
| AGR-03 | Edit agreement | Click edit on existing agreement | Form pre-populated, save updates | P0 |
| AGR-04 | Agreement detail | Click agreement in list | Full detail page renders | P0 |
| AGR-05 | Agreement history | View detail page history tab | Amendments and reviews listed | P1 |
| AGR-06 | Pagination | Navigate beyond first page | Correct items displayed | P1 |
| AGR-07 | Status filter | Filter by status | Only matching agreements shown | P2 |

### Test Area 6: Governance - Proposals (ACT Process)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| PROP-01 | Proposal list loads | Navigate to /proposals | Paginated list renders | P0 |
| PROP-02 | Create proposal | Fill ProposalForm, submit | New proposal created | P0 |
| PROP-03 | Proposal detail | Click proposal in list | Full detail with ACT tabs | P0 |
| PROP-04 | Submit advice | Add advice entry on proposal | Advice logged | P1 - UNBLOCKED by BUG-011 |
| PROP-05 | Consent round | Record consent/objections | Consent state updated | P1 - UNBLOCKED by BUG-011 |
| PROP-06 | Test report | Add test report to proposal | Test report saved | P1 - UNBLOCKED by BUG-011 |
| PROP-07 | Status transitions | Move proposal through ACT stages | Status updates correctly | P1 |

### Test Area 7: Governance - Members

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| MEM-01 | Member list loads | Navigate to /members | Paginated member list | P0 |
| MEM-02 | Create member | Fill MemberForm, submit | New member created | P0 |
| MEM-03 | Member detail | Click member in list | Profile, badges, onboarding state | P0 |
| MEM-04 | Edit member | Edit existing member | Updates saved | P1 |
| MEM-05 | Member badges | View member badges section | Badge icons and descriptions | P1 |
| MEM-06 | Member tags | View member tags | Tags displayed with categories | P2 |

### Test Area 8: Governance - Domains (PARTIALLY UNBLOCKED by BUG-010)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| DOM-01 | Domain list loads | Navigate to /domains | Domain list renders | P0 |
| DOM-02 | Create domain | Fill DomainForm, submit | New domain created | P0 |
| DOM-03 | Edit domain | Edit existing domain | Form pre-populated, save works | P0 - UNBLOCKED by BUG-010 |
| DOM-04 | Domain detail | View domain elements and metrics | All data renders | P1 |

### Test Area 9: Governance - Onboarding

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| ONB-01 | Onboarding list | Navigate to /onboarding | Members with onboarding state | P0 |
| ONB-02 | Onboarding ceremony | Click member, start ceremony | UAF ceremony flow works | P0 |
| ONB-03 | Section consent | Toggle section consents | Progress percentage updates | P1 |
| ONB-04 | Cooling off period | Set cooling off dates | Dates saved and displayed | P1 |

### Test Area 10: Governance - Conflicts

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| CONF-01 | Conflict list loads | Navigate to /conflicts | List with severity/urgency badges | P0 |
| CONF-02 | Report conflict | Fill ConflictForm, submit | New conflict created | P0 |
| CONF-03 | Conflict detail | View conflict details | Full case info renders | P0 |
| CONF-04 | Repair agreement | Add repair agreement | Agreement saved to conflict | P1 |
| CONF-05 | Safety flag | Create conflict with safety flag | Flag prominently displayed | P1 |

### Test Area 11: Governance - Ecosystems

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| ECO-01 | Ecosystem list | Navigate to /ecosystems | List renders | P0 |
| ECO-02 | Create ecosystem | Fill EcosystemForm, submit | New ecosystem created | P0 |
| ECO-03 | Ecosystem picker | Use sidebar ecosystem picker | Context switches, data reloads | P0 |
| ECO-04 | Ecosystem detail | View ecosystem detail | All fields render | P1 |
| ECO-05 | Multi-ecosystem | Switch between ecosystems | Data scoped correctly | P1 |

### Test Area 12: Governance - Exit

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| EXIT-01 | Exit list loads | Navigate to /exit | List with exit types and statuses | P0 |
| EXIT-02 | Create exit | Fill ExitForm, submit | Exit record created | P0 |
| EXIT-03 | Exit detail | View exit detail | Unwinding tracker renders | P1 |
| EXIT-04 | Update exit status | Change status on exit | Status persists | P1 |

### Test Area 13: Governance - Safeguards

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| SAFE-01 | Safeguards dashboard | Navigate to /safeguards | Health score and latest audit | P0 |
| SAFE-02 | Audit list | View audit history | Paginated audits | P1 |
| SAFE-03 | Audit detail | Click audit | Full findings render | P1 |

### Test Area 14: Governance - Decisions (Read-Only)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| DEC-01 | Decision list | Navigate to /decisions | Paginated list | P0 |
| DEC-02 | Decision detail | Click decision | Full detail renders | P0 |

### Test Area 15: Quiz System

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| QUIZ-01 | Quiz catalog | Navigate to /quizzes | Published quizzes listed | P0 |
| QUIZ-02 | Take quiz | Start quiz, answer questions | Submissions work, results shown | P0 |
| QUIZ-03 | Quiz results | Complete quiz, view results | Score, pass/fail, badges awarded | P0 |
| QUIZ-04 | Quiz management (admin) | Navigate to /quiz/manage | CRUD operations work | P1 |
| QUIZ-05 | Quiz retakes | Retake allowed quiz | New attempt created | P1 |
| QUIZ-06 | Time limit | Start timed quiz | Timer displays and enforces limit | P2 |

### Test Area 16: Orientation Flow

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| ORI-01 | Orientation gate | New user visits orientation | Gate page renders | P0 |
| ORI-02 | Journey steps | Progress through orientation | All step types work (video, survey, reflection, AI conversation) | P0 |
| ORI-03 | Orientation complete | Finish orientation | Completion page with exit package | P0 - UNBLOCKED by BUG-012 |
| ORI-04 | Skip prevention | Try to skip required steps | Enforcement works | P1 |

### Test Area 17: Profile & Public Profile

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| PROF-01 | View profile | Navigate to /profile | Profile data renders | P0 |
| PROF-02 | Edit profile | Update profile fields, save | Changes persist | P0 |
| PROF-03 | Public profile | Visit /users/:username | Public view renders | P1 |
| PROF-04 | Profile tiles | Check all tile types | Badge, chart, list, score, text tiles render | P2 |

### Test Area 18: Messaging

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| MSG-01 | Conversation list | Navigate to /messaging | Conversations load | P0 |
| MSG-02 | Send message | Open conversation, type, send | Message appears | P0 |
| MSG-03 | WebSocket realtime | Two users in same conversation | Messages appear in realtime | P1 |
| MSG-04 | Create conversation | Start new conversation | Conversation created | P1 |

### Test Area 19: Chat (AI-Assisted)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| CHAT-01 | Chat panel | Navigate to /chat | Chat interface renders | P0 |
| CHAT-02 | Send message to AI | Type question, send | AI response received | P0 |
| CHAT-03 | Chat history | Reload chat page | Previous messages preserved | P1 |

### Test Area 20: Map & Journey Maps

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| MAP-01 | Map page | Navigate to /map | Visual map renders | P0 |
| MAP-02 | Journey map list | Navigate to /admin/journey-maps | List of maps | P1 |
| MAP-03 | Journey map editor | Edit a journey map | Visual editor works, saves | P1 |

### Test Area 21: Admin Panel (PARTIALLY UNBLOCKED by BUG-009)

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| ADM-01 | Admin dashboard | Navigate to admin panel | Stats and controls render | P0 |
| ADM-02 | User management | CRUD operations on users | All operations work | P0 |
| ADM-03 | Ethos access grants | Grant/revoke ethos access | Operations succeed | P0 - UNBLOCKED by BUG-009 |
| ADM-04 | Permission enforcement | Non-admin visits admin pages | Access denied | P1 |

### Test Area 22: Cross-Cutting Concerns

| # | Test Case | Steps | Expected Result | Priority |
|---|-----------|-------|-----------------|----------|
| XC-01 | Ecosystem context | Switch ecosystem in picker | All data reloads for selected ecosystem | P0 |
| XC-02 | Permission guards | Visit page without required permission | ProtectedRoute shows error | P0 |
| XC-03 | Toast notifications | Trigger various actions | Success/error toasts appear | P1 |
| XC-04 | Loading states | Slow network | Loading skeletons/spinners shown | P1 |
| XC-05 | Error boundaries | API returns 500 | Error message, no white screen | P1 |
| XC-06 | Navigation sidebar | Click all sidebar links | All routes accessible | P0 |
| XC-07 | Mobile responsive | Resize to 375px width | Layout adapts, no overflow | P2 |
| XC-08 | AI Textarea | Use AI assist in any form | Text generated and inserted | P2 |
| XC-09 | Speech input | Use voice input feature | Audio transcribed to text | P3 |

---

## PART 3: BUG SUMMARY & FIX PRIORITY

### Fix Wave 1 (Critical Blockers - Fix Immediately)
1. **BUG-001/005/006/008/009**: Eradicate all Supabase references (5 files)
2. **BUG-002**: Fix emergency declare URL (`/emergency` -> `/emergency/declare`)
3. **BUG-003/004**: Align EmergencyState types and response handling

### Fix Wave 2 (High - Functional Issues)
4. **BUG-007**: Define PHASE_LABELS constant in EthosDetail
5. **BUG-010**: Add useUpdateDomain hook
6. **BUG-011**: Fix proposal advice/consent/test response parsing
7. **BUG-012**: Fix OrientationComplete property names

### Fix Wave 3 (Medium - Polish)
8. **BUG-013**: Add pagination fields to ecosystems list response
9. **BUG-014**: Resolve EcosystemForm variable shadowing

---

## PART 4: TEST EXECUTION TRACKING

### Overall Stats
- **Total Test Cases:** 95
- **Blocked by Bugs:** 0 (0%) -- previously 18, all resolved as of 2026-04-28
- **Ready to Execute:** 95
- **Critical Test Areas:** 22

### Test Coverage by Feature

| Feature | Test Cases | Blocked | Ready |
|---------|-----------|---------|-------|
| Authentication | 7 | 0 | 7 |
| Dashboard | 4 | 0 | 4 |
| Discover & Ethos | 8 | 0 | 8 |
| Emergency | 7 | 0 | 7 |
| Agreements | 7 | 0 | 7 |
| Proposals | 7 | 0 | 7 |
| Members | 6 | 0 | 6 |
| Domains | 4 | 0 | 4 |
| Onboarding | 4 | 0 | 4 |
| Conflicts | 5 | 0 | 5 |
| Ecosystems | 5 | 0 | 5 |
| Exit | 4 | 0 | 4 |
| Safeguards | 3 | 0 | 3 |
| Decisions | 2 | 0 | 2 |
| Quiz System | 6 | 0 | 6 |
| Orientation | 4 | 0 | 4 |
| Profile | 4 | 0 | 4 |
| Messaging | 4 | 0 | 4 |
| Chat | 3 | 0 | 3 |
| Maps | 3 | 0 | 3 |
| Admin | 4 | 0 | 4 |
| Cross-Cutting | 9 | 0 | 9 |

---

*Generated by ULTRAQA Cycle 1 - NEOS Platform QA Analysis*
