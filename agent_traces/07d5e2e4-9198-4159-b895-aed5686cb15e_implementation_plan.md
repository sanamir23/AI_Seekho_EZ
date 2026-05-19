# API Integration: EZ Flutter App ↔ FastAPI Backend

## Overview

The cloned `hackathon` repo contains a **FastAPI + LangGraph** backend that exposes three API routers:
- **`/api/auth`** — signup, login, `GET /me`
- **`/api/service-requests`** — AI agent endpoint (text → provider match → booking), plus audio transcription
- **`/api/bookings`** — list, get detail, cancel bookings

The Flutter frontend currently hard-codes all data and navigates between screens with no real API calls. This plan wires every screen to the real backend and reorganises the repository.

---

## Backend API Surface (FastAPI at `http://localhost:8000`)

| Method | Endpoint | Screen | Purpose |
|--------|----------|--------|---------|
| `POST` | `/api/auth/signup` | Login/Signup | Create account |
| `POST` | `/api/auth/login` | Login/Signup | Get JWT |
| `GET` | `/api/auth/me` | App startup | Validate stored token |
| `POST` | `/api/service-requests` | Composer → Thinking | Submit text, get agent response |
| `POST` | `/api/service-requests/transcribe` | Composer (mic) | Upload audio file → transcript |
| `GET` | `/api/bookings` | Home (bookings tab) | List user's bookings |
| `GET` | `/api/bookings/{id}` | (future) | Booking detail |
| `POST` | `/api/bookings/{id}/cancel` | (future) | Cancel |

**Agent response statuses:**
- `completed` → `selected_provider`, `booking`, `reasoning`, `suggestions`
- `needs_clarification` → `question` (multi-turn conversation_id)
- `abandoned` → `reason`

---

## New Folder Layout (inside `ez_app/`)

```
ez_app/
├── backend/          ← copy of hackathon/backend/
│   └── app/...
├── docs/             ← copy of hackathon/docs/
│   └── *.md, *.png
└── lib/
    ├── core/
    │   ├── services/
    │   │   └── api_service.dart     [NEW] HTTP client + auth token storage
    │   ├── models/
    │   │   ├── agent_response.dart  [NEW] AgentRunOut, ProviderBrief, BookingBrief
    │   │   └── booking.dart         [NEW] BookingOut, ProviderOut
    │   ├── theme/
    │   └── widgets/
    ├── screens/
    │   ├── auth/
    │   │   └── auth_screen.dart     [NEW] Login + Signup
    │   ├── home/
    │   │   └── home_screen.dart     [MODIFY] add bookings tab + fetch real data
    │   ├── composer/
    │   │   └── composer_screen.dart [MODIFY] submit text → API, handle clarification
    │   ├── thinking/
    │   │   └── thinking_screen.dart [MODIFY] show real trace steps from response
    │   ├── results/
    │   │   └── results_screen.dart  [MODIFY] show real provider from API
    │   └── confirm/
    │       └── confirm_screen.dart  [MODIFY] show real booking data
    └── main.dart                    [MODIFY] auth guard → show auth or home
```

---

## Proposed Changes

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///c:/Users/Sana%20Mir/Documents/QuantumEdge/AI_Seekho_Hackathon/EZ_Frontend/ez_app/pubspec.yaml)
Add:
- `http: ^1.2.0` — HTTP client
- `shared_preferences: ^2.2.3` — local JWT storage

---

### New Layer: `lib/core/services/` and `lib/core/models/`

#### [NEW] `lib/core/services/api_service.dart`
Singleton HTTP client that:
- Sets base URL (`http://10.0.2.2:8000` for Android emulator / `http://localhost:8000` for desktop)
- Attaches `Authorization: Bearer <token>` header automatically
- Exposes typed methods: `login`, `signup`, `sendServiceRequest`, `transcribeAudio`, `listBookings`
- Stores/loads JWT via `shared_preferences`

#### [NEW] `lib/core/models/agent_response.dart`
Dart models matching the backend Pydantic schemas:
- `AgentRunOut` (status, conversation_id, selected_provider, booking, reasoning, suggestions, question, etc.)
- `ProviderBrief`, `BookingBrief`, `IntentParsed`

#### [NEW] `lib/core/models/booking.dart`
- `BookingOut`, `ProviderOut`

---

### Auth Flow

#### [NEW] `lib/screens/auth/auth_screen.dart`
Minimal but styled login/signup screen with:
- Email + password fields
- Toggle between Login / Sign Up
- Calls `ApiService.login()` / `ApiService.signup()`
- On success, stores JWT and navigates to `HomeScreen`

#### [MODIFY] `lib/main.dart`
On startup: check for stored JWT → `/api/auth/me` validation:
- Valid → `HomeScreen`
- Invalid/missing → `AuthScreen`

---

### Screen Integrations

#### [MODIFY] `composer_screen.dart`
- On submit: call `POST /api/service-requests` with `{text, conversation_id?}`
- Navigate to `ThinkingScreen` **passing the Future result** (not completed yet)
- On mic stop: call `POST /api/service-requests/transcribe` → set text in field
- Handle `needs_clarification`: show inline question and re-submit with same `conversation_id`

#### [MODIFY] `thinking_screen.dart`
- Accept `Future<AgentRunOut>` as constructor param
- Show animated timeline while awaiting (current hardcoded steps replaced with real `trace_steps` from API)
- On future complete → navigate to `ResultsScreen` with `AgentRunOut` data

#### [MODIFY] `results_screen.dart`
- Accept `AgentRunOut` as constructor param
- Display `selected_provider` data (name, rating, area, category)
- Show `reasoning` in the AI insight bar
- Show `suggestions` as action chips
- "Book Now" → navigate to `ConfirmScreen` with `booking` data

#### [MODIFY] `confirm_screen.dart`
- Accept `BookingBrief` + `ProviderBrief` as constructor params
- Display real booking data (scheduled_at, provider name, etc.)
- "Track Provider" placeholder (no tracking API yet)
- "Go Home" → clear stack → `HomeScreen`

#### [MODIFY] `home_screen.dart`
- On mount: call `GET /api/bookings` → show real bookings list in bookings tab
- Show active/upcoming bookings in a styled card list

---

### Repository Reorganisation

After integration:

1. Copy `hackathon/backend/` → `ez_app/backend/`
2. Copy `hackathon/docs/` → `ez_app/docs/`
3. Delete the `hackathon/` folder from `EZ_Frontend/` root
4. Clean up root-level JSX/HTML design files (move to `assets/design/` or delete)

---

## Verification Plan

### Automated
- `flutter analyze` — zero errors
- `flutter build apk --debug` — successful build

### Manual
1. Launch backend: `cd ez_app/backend && uvicorn app.main:app --reload`
2. Run Flutter on emulator
3. Sign up → login → lands on Home
4. Tap "Ask EZ" → type service request → verify thinking screen uses real API
5. On completion → verify results show real provider name
6. Confirm booking → verify confirmation shows real scheduled time

> [!IMPORTANT]
> The backend needs a `.env` file with Supabase + Gemini keys. We will add an `.env.example` to `ez_app/backend/` to document required variables.

> [!NOTE]
> For the clarification flow (`needs_clarification` status), the composer screen will show the agent's question inline and allow a follow-up reply using the same `conversation_id` before navigating to thinking/results.
