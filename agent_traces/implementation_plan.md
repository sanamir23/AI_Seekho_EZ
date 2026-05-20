# Voice Transcription Feature Integration

This plan outlines the steps to add voice transcription functionality to the ServiceMatcher app. We will allow users to record their voice from the chat UI, send it to the backend for transcription using Gemini 1.5 Pro, and automatically submit the transcribed text to the existing agent workflow.

## Proposed Changes

### Backend

#### [MODIFY] `backend/app/routers/service_requests.py`
- Import `UploadFile` and `File` from FastAPI.
- Add a new POST endpoint `/api/service-requests/transcribe` that accepts an audio `UploadFile`.
- Use the `google.generativeai` SDK (which natively supports passing raw binary media) to send the audio file to the `gemini-1.5-pro` model.
- Instruct Gemini to strictly return the raw transcription in its original language (English, Urdu, or Roman Urdu).
- Return the transcription as JSON: `{"text": "transcribed text..."}`.

### Frontend

#### [MODIFY] `frontend/index.html`
- **UI Updates**:
  - Add a microphone button (`<button id="mic-btn">🎙️</button>`) next to the chat composer.
  - Add a visual indicator (like a red pulsating dot or CSS class) to show when recording is active.
- **Logic Updates**:
  - Implement the `MediaRecorder` API to request microphone permissions and capture audio.
  - Bind the mic button to toggle recording on/off.
  - When recording stops, compile the audio chunks into a `Blob`.
  - Use `FormData` to POST the audio blob to the new `/api/service-requests/transcribe` endpoint.
  - Once the backend returns the transcribed text, insert it into the chat input or automatically send it using the existing `handleSend()` function.

## Open Questions

> [!IMPORTANT]  
> **Auto-Send vs. Manual Review:** After the audio is transcribed, should the system immediately send the message to the AI agent (hands-free experience), or should it just paste the text into the chat input box so the user can review and edit it before hitting send? I'll plan to paste it into the input box so the user can review it first, but let me know if you prefer auto-send!

## Verification Plan

### Manual Verification
1. Open the frontend UI and click the microphone button.
2. Accept the browser's microphone permission prompt.
3. Speak a test query (e.g., "Mujhe kal F-10 mein plumber chahiye").
4. Stop the recording.
5. Verify that the audio is successfully sent to the backend, transcribed by Gemini, and the correct text appears in the chat box or chat history.
6. Verify that the agent responds correctly to the transcribed text.
