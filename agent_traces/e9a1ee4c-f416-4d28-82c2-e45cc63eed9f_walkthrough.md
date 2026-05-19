# Finora — Jira Project Setup Complete

## 🔗 Board URL
**[Finora Scrum Board](https://finora-team-spm.atlassian.net/jira/software/projects/SCRUM/boards/1)**

---

## Summary of Created Items

| Category | Count |
|----------|-------|
| Epics | 6 |
| Stories | 22 |
| Subtasks | 56 |
| Risk Tasks | 6 |
| Sprints | 5 (Sprint 0–4) |
| **Total Issues** | **90+** |

---

## Epics

| Key | Epic | Sprint Focus |
|-----|------|-------------|
| SCRUM-5 | Foundation & Tooling | Sprint 0 |
| SCRUM-6 | Authentication & Onboarding | Sprint 1 |
| SCRUM-7 | Wallet Management | Sprint 2 |
| SCRUM-8 | Payments (P2P + QR) | Sprint 2 |
| SCRUM-9 | Cards & Bills | Sprint 3 |
| SCRUM-10 | QA, Documentation & Delivery | Sprint 4 |

---

## Sprint Breakdown

### Sprint 0 — Foundation (4 May 2026)
| Key | Type | Summary | Labels |
|-----|------|---------|--------|
| SCRUM-11 | Story | Initialize Flutter project and Git repository | must-have, backend |
| SCRUM-12 | Story | Configure Jira project and agile workflow | must-have, docs |
| SCRUM-13 | Story | Design system and reusable widget library | must-have, frontend, uiux |
| SCRUM-14 | Story | SQLite schema and mock data fixtures | must-have, backend |
| SCRUM-15 | Story | Mock service-layer scaffolding | must-have, backend |
| SCRUM-16–27 | Subtasks | 12 subtasks across 5 stories | various |

### Sprint 1 — Authentication & Onboarding (5 May 2026)
| Key | Type | Summary | SP | Labels |
|-----|------|---------|-----|--------|
| SCRUM-28 | Story | CNIC-based registration with validation | 3 | must-have, frontend, backend |
| SCRUM-29 | Story | Mock OTP verification flow | 3 | must-have, frontend, backend |
| SCRUM-30 | Story | Biometric verification | 2 | should-have, frontend, backend |
| SCRUM-31 | Story | Secure PIN creation and login | 3 | must-have, frontend, backend |
| SCRUM-32–42 | Subtasks | 11 subtasks across 4 stories | — | various |

### Sprint 2 — Wallet + Payments (6 May 2026)
| Key | Type | Summary | SP | Labels |
|-----|------|---------|-----|--------|
| SCRUM-43 | Story | Wallet dashboard with PKR balance | 3 | must-have, frontend |
| SCRUM-44 | Story | Transaction history with search and filter | 5 | must-have, frontend, backend |
| SCRUM-45 | Story | In-app transaction receipt view | 2 | must-have, frontend |
| SCRUM-53 | Story | P2P transfer by phone number | 5 | must-have, frontend, backend |
| SCRUM-54 | Story | QR scanner for merchant payments | 5 | must-have, frontend, backend |
| SCRUM-55 | Story | Transaction rollback on simulated failure | 3 | must-have, backend, testing |
| SCRUM-46–52,64–71 | Subtasks | 15 subtasks across 6 stories | — | various |

### Sprint 3 — Cards & Bills (7 May 2026)
| Key | Type | Summary | SP | Labels |
|-----|------|---------|-----|--------|
| SCRUM-56 | Story | Virtual card display and management | 5 | must-have, frontend, backend |
| SCRUM-57 | Story | Bill payment flow | 3 | should-have, frontend, backend |
| SCRUM-58 | Story | Transaction limits and 2FA for high-value transfers | 3 | should-have, backend, frontend |
| SCRUM-72–80 | Subtasks | 9 subtasks across 3 stories | — | various |

### Sprint 4 — QA, Docs & Delivery (8 May 2026)
| Key | Type | Summary | SP | Labels |
|-----|------|---------|-----|--------|
| SCRUM-59 | Story | End-to-end regression test of all five core journeys | 5 | must-have, testing |
| SCRUM-60 | Story | User manual with screenshots | 3 | must-have, docs |
| SCRUM-61 | Story | Final project report | 5 | must-have, docs |
| SCRUM-62 | Story | 5-minute PowerPoint and demo recording | 3 | must-have, docs |
| SCRUM-63 | Story | APK build and release packaging | 2 | must-have, backend |
| SCRUM-81–91 | Subtasks | 11 subtasks across 5 stories | — | various |

---

## Risk Register

| Key | Risk ID | Title | Probability | Impact | Priority |
|-----|---------|-------|-------------|--------|----------|
| SCRUM-92 | R1 | Scope Creep | High | High | High |
| SCRUM-93 | R2 | Team Availability | Medium | High | High |
| SCRUM-94 | R3 | Technical Debt from Mock Services | Medium | Medium | Medium |
| SCRUM-95 | R4 | Device Compatibility | Medium | Medium | Medium |
| SCRUM-96 | R5 | Data Loss / Corruption | Low | High | High |
| SCRUM-97 | R6 | Submission Deadline Missed | Low | Critical | Medium |

---

## Team Assignment Notes

> [!WARNING]
> **Team member accounts not resolvable.** The following members' Atlassian accounts could not be found in the Jira Cloud instance:
> - **Abdulrehman Baloch** — Tried: `@Abdulrehman`
> - **Ayesha Kiani** — Tried: `@AyeshaKian`
>
> **Fallback applied:** All issues assigned to **Sana Fatima** (`i221160@nu.edu.pk`) as project lead. Each subtask description notes the intended assignee for manual reassignment once accounts are confirmed.

---

## Project Metadata

| Field | Value |
|-------|-------|
| Jira Instance | `finora-team-spm.atlassian.net` |
| Project Key | `SCRUM` |
| Board ID | `1` |
| Story Points Field | `customfield_10016` |
| Sprint 0 ID | `2` (active) |
| Sprint 1 ID | `35` |
| Sprint 2 ID | `36` |
| Sprint 3 ID | `37` |
| Sprint 4 ID | `38` |

---

## What Was Done

1. ✅ **6 Epics** created (SCRUM-5 to SCRUM-10)
2. ✅ **22 User Stories** with acceptance criteria, story points, and MoSCoW + discipline labels
3. ✅ **56 Subtasks** with intended assignees documented in descriptions
4. ✅ **6 Risk Register items** (SCRUM-92 to SCRUM-97) with probability/impact/mitigation
5. ✅ **5 Sprints** configured (Sprint 0 active, Sprints 1-4 as future)
6. ✅ **Sprint assignments** — all stories placed in their correct sprints
7. ✅ **Labels applied** — `must-have`, `should-have`, `frontend`, `backend`, `uiux`, `testing`, `docs`, `risk`
