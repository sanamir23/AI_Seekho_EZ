# Agentic Service Matching — Backend

FastAPI + LangGraph + Supabase + Gemini. Implements the hackathon challenge:
natural-language service requests (Urdu / Roman Urdu / English) → provider
discovery → ranked recommendation → simulated booking → scheduled follow-up
reminder, with a full traceable agent log.

## Setup

1. Create a Supabase project. From **Settings → API** copy the URL, anon key,
   service-role key. From **Settings → Database** copy the connection string
   (URI form). Put them in `.env` (see `.env.example`).
2. Open the Supabase SQL editor and run `supabase/migrations/001_init.sql`.
3. Get a Google Gemini API key and a Google Places API key.
4. Install deps:
   ```powershell
   cd backend
   python -m venv .venv ; .venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```
5. Seed providers (Islamabad, 5 categories):
   ```powershell
   python -m scripts.seed_providers
   ```
6. Run:
   ```powershell
   uvicorn app.main:app --reload --port 8000
   ```

## Endpoints

- `POST /auth/signup`  `{ phone, password, display_name? }`
- `POST /auth/login`   `{ phone, password }`
- `GET  /auth/me`      (Bearer token)
- `POST /service-requests`  `{ text, conversation_id?, demo_offset_seconds? }`
  - Response `status`: `completed | needs_clarification | abandoned`
  - On `needs_clarification`, POST again with the same `conversation_id` and the user's reply.
- `GET  /bookings`
- `GET  /bookings/{id}`  (includes the agent trace)
- `POST /bookings/{id}/cancel`

## Agent graph

`intent_parser → provider_discovery → ranking → decision → booking → followup`
with a `clarifier` branch (uses LangGraph `interrupt()` to pause across HTTP
turns; resumes via `Command(resume=...)`). Hard-capped at 2 clarification
rounds before falling through to `give_up`. State persists in the
`PostgresSaver` checkpointer (same Supabase Postgres, `langgraph` schema).

Trace of every node (latency, output summary) is stored in `agent_traces.steps`
and surfaced in `GET /bookings/{id}`.

## Demo tip

Pass `demo_offset_seconds=30` in the request body to have the reminder fire 30
seconds after booking — handy for live demos.
