# EZ App Integration & Enhancement Plan

This plan details the changes required to synchronize the frontend with the FastAPI backend, overhaul the UI into a unified chat flow, enhance animations, and fix the voice recording functionality.

## Goal Description
The objective is to fix existing bugs and upgrade the application to a dynamic, single-page, conversational layout. This includes fixing model mismatches with the backend, resolving voice transcription errors, gracefully supporting multiple provider recommendations, and generating a dynamic thinking phase matching the backend's real trace steps.

## User Review Required
> [!WARNING]
> Since we are consolidating the Composer, Thinking, Results, and Confirmation screens into a unified chat interface (Task 6), some separate files (like `thinking_screen.dart`, `results_screen.dart`, etc.) may become redundant. I will create a new `chat_screen.dart` and route the home screen to it, keeping the old files intact but unused, or I can delete them if preferred. For the scope of this hackathon, I'll keep them but route everything through the unified `chat_screen.dart`.

> [!IMPORTANT]
> The `pubspec.yaml` currently does not have an audio recording package like `flutter_sound` or `record`. I plan to install the `record` package and `path_provider` to implement Task 4 (Voice feature). Please confirm this is acceptable.

## Proposed Changes

---

### Backend Sync (Task 0)
- **Completed**: Pulled the latest backend from the provided GitHub repository and overwrote the local `backend/` folder.

---

### API Audit & Integration (Task 1)
Update frontend models to perfectly align with the backend's Pydantic schemas.

#### [MODIFY] `lib/core/models/agent_response.dart`
- Add `freeSlots` and `alternatives` to `AgentRunOut` so we can handle cases where multiple providers or slots are returned.
- Add `priceRange` if needed.
- Update `IntentParsed` to handle any missing fields.

#### [MODIFY] `lib/core/services/api_service.dart`
- Verify endpoints. They appear perfectly matched (`signup`, `login`, `me`, `sendServiceRequest`, `transcribeAudio`, `listBookings`, `getBooking`, `cancelBooking`). Will double-check JSON structures and auth headers.

---

### Splash Screen Enhancement (Task 3)
Make the splash screen more lively while maintaining the exact existing design language.

#### [MODIFY] `lib/screens/splash/splash_screen.dart`
- Add an entrance scale/fade animation to the logo and a delayed fade to the tagline.
- Implement a subtle shimmer/glow loop on the background or logo container.
- Ensure the transition triggers after ~2.5 seconds.

---

### Voice Feature Fix (Task 4)
Implement actual audio recording and transcription.

#### [MODIFY] `pubspec.yaml`
- Add `record` and `path_provider` packages.

#### [MODIFY] `android/app/src/main/AndroidManifest.xml` & `ios/Runner/Info.plist`
- Ensure microphone permissions are declared.

#### [NEW/MODIFY] `lib/screens/composer/chat_screen.dart`
- Implement recording logic using the `record` package.
- Send the recorded audio file to `ApiService.instance.transcribeAudio()`.
- Populate the chat input with the transcribed string and auto-submit it or allow the user to review.

---

### Unified Chat Flow & Dynamic Thinking (Tasks 2, 5, 6)
Combine multiple steps into a single conversational interface.

#### [NEW] `lib/screens/composer/chat_screen.dart`
- Create a unified chat interface with a scrolling message list.
- **Dynamic Thinking (Task 2)**: Render backend `trace_steps` dynamically. If `status == "needs_clarification"`, interrupt the trace stream and show the agent's question as a chat bubble.
- **Multiple Providers (Task 5)**: When `alternatives` (list of `ProviderBrief`) are present, render a horizontal scrollable list of provider cards inline within the chat. Tapping a card confirms the booking.
- **Maintain Flow (Task 6)**: Keep `conversation_id` across requests to maintain context. All user inputs, agent reasoning, questions, provider cards, and booking confirmations will be appended to the chat stream. 

#### [MODIFY] `lib/screens/home/home_screen.dart`
- Update the FAB or main call-to-action to navigate to the new `chat_screen.dart` instead of the old `composer_screen.dart`.

---

## Verification Plan

### Automated Tests
- N/A for this UI-heavy sprint.

### Manual Verification
- Test splash screen animations locally.
- Test voice recording (microphone permissions and file uploading).
- Test conversation flow with the backend to ensure `trace_steps` display sequentially and clarification questions interrupt them properly.
- Verify that selecting one of multiple provider cards correctly finalizes the booking in the backend.

### Academic Submission (Task 7)
After executing and testing all these tasks, I will generate a final, structured markdown report containing the objectives, files modified, approaches, and status of each task to fulfill Task 7.
