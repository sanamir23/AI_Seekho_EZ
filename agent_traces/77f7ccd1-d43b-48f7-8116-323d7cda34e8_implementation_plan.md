# EZ App — Flutter Screen Implementation Plan

Convert Claude Design HTML/JSX mockups into polished Flutter screens for the Google Antigravity Hackathon submission (Challenge 2). The design retains the EZ brand identity (yellow `#FCD24A`, cream `#FBF8F1`, near-black `#141414`) while adding a cleaner, more professional feel.

## Screens to Build

| # | Screen | Source file |
|---|--------|-------------|
| 1 | **Splash** | `uploads/Welcome + Splash.png` (leftmost card) |
| 2 | **Onboarding** (3-page carousel) | `uploads/Welcome + Splash.png` (pages 1–3) |
| 3 | **Role Selection** | `uploads/Welcome + Splash.png` (rightmost card) |
| 4 | **Home / Input** | `screen1-home.jsx` |
| 5 | **AI Composer** | `screen1b-composer.jsx` |
| 6 | **Thinking / Reasoning** | `screen2-thinking.jsx` |
| 7 | **Results** | `screen3-results.jsx` |
| 8 | **Booking Confirmed** | `screen4-confirm.jsx` |

---

## Open Questions

> [!IMPORTANT]
> **Does a Flutter project already exist?** If yes, should I add screens to it, or create a fresh standalone Flutter app?
> I'll proceed assuming a **new Flutter project** created at `c:\Users\Sana Mir\Documents\QuantumEdge\AI_Seekho_Hackathon\ez_app`.

> [!IMPORTANT]
> **Navigation**: Should the app use `go_router` or standard `Navigator`? I'll default to **Navigator.push** for simplicity / hackathon speed.

> [!NOTE]
> The reference PDF (Challenge 2) could not be parsed in this session but the pasted screenshot confirms the AI-agent flow is the correct scope.

---

## Design System (Flutter)

### Color Palette
```dart
// lib/core/theme/ez_colors.dart
ezYellow      = Color(0xFFFCD24A)
ezYellowSoft  = Color(0xFFFFE988)
ezYellowGlow  = Color(0xFFFFF5C2)
ezYellowDeep  = Color(0xFFE8B617)
ezCream       = Color(0xFFFBF8F1)
ezCream2      = Color(0xFFF4EFE2)
ezInk         = Color(0xFF141414)
ezInkSoft     = Color(0xFF4A4742)
ezMuted       = Color(0xFF8B8576)
ezBorder      = Color(0xFFECE5D3)
ezSuccess     = Color(0xFF16A34A)
```

### Typography
- **Display**: `Bricolage Grotesque` (Google Fonts) — headings, brand
- **Body**: `Plus Jakarta Sans` (Google Fonts) — all body text
- **Mono**: `JetBrains Mono` (Google Fonts) — badges, counters

### Elevation / Shadows
Mimic CSS shadows using Flutter `BoxShadow` combos.

---

## Project Structure

```
ez_app/
├── lib/
│   ├── core/
│   │   ├── theme/
│   │   │   ├── ez_colors.dart
│   │   │   ├── ez_text_styles.dart
│   │   │   └── ez_theme.dart
│   │   └── widgets/
│   │       ├── ez_chip.dart
│   │       ├── ez_pill_button.dart
│   │       ├── bottom_nav_bar.dart
│   │       ├── wave_bars.dart
│   │       └── provider_card.dart
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart
│   │   ├── role_selection/
│   │   │   └── role_selection_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── composer/
│   │   │   └── composer_screen.dart
│   │   ├── thinking/
│   │   │   └── thinking_screen.dart
│   │   ├── results/
│   │   │   └── results_screen.dart
│   │   └── confirm/
│   │       └── confirm_screen.dart
│   └── main.dart
├── assets/
│   ├── images/
│   │   └── ez_logo.png
│   └── fonts/ (via google_fonts package)
└── pubspec.yaml
```

---

## Proposed Changes

### pubspec.yaml [NEW]
- Dependencies: `google_fonts`, `flutter_animate`, `cupertino_icons`
- Asset declarations for logo PNG

---

### `lib/core/theme/` — Design tokens
#### [NEW] ez_colors.dart
All brand colors as `Color` constants

#### [NEW] ez_text_styles.dart
`TextStyle` presets for display, body, mono

#### [NEW] ez_theme.dart
`ThemeData` wiring everything together

---

### `lib/core/widgets/` — Reusable components
#### [NEW] ez_chip.dart
Service category chip (active/inactive states)

#### [NEW] ez_pill_button.dart
Primary / yellow / ghost / soft pill buttons

#### [NEW] bottom_nav_bar.dart
Floating bottom nav (Home, Bookings, Chat, Profile)

#### [NEW] wave_bars.dart
5-bar audio waveform animation

#### [NEW] provider_card.dart
Provider result card with AI Pick ribbon

---

### `lib/screens/` — 8 App Screens

#### [NEW] splash_screen.dart
- Solid yellow background
- Centered EZ logo (from PNG asset)
- 2s delay → navigate to Onboarding
- Subtle fade-scale animation

#### [NEW] onboarding_screen.dart
- PageView with 3 slides
- Each: illustration area (SVG/lottie placeholder → simple drawn widget), tagline, subtitle
- Dot indicator with yellow active dot
- Black "Continue" pill button
- Slide 1: "Trusted professionals across every service"
- Slide 2: "Booked in seconds, handled in hours"
- Slide 3: "Skip the search, the chase, the guesswork"

#### [NEW] role_selection_screen.dart
- "How will you use EZ?" heading
- 3 role cards (radio-style tap): Customer / Service Provider / Shop Owner
- Each with small avatar icon, title, subtitle
- "Continue" button (disabled until selection made)

#### [NEW] home_screen.dart
- Cream background with subtle ambient illustration header
- Location pill + notification bell + avatar header
- Greeting: "Assalam-o-Alaikum, Ahmad"
- H1: "How can we assist you today?"
- Big search bar with mic + send arrow → navigates to Composer
- Horizontal chip scroll: Quick services (AC Repair, Plumber, etc.)
- 2-column grid: Popular near you cards with AI Ranked badge
- Floating bottom nav bar

#### [NEW] composer_screen.dart
- Cream bg, back button header
- Center: EZ logo with pulsing yellow halo + rings
- "EZ Agent" label with sparkle
- H2: "How can we assist you today?"
- 2×2 suggestion chips (AC stopped cooling, Leaking tap, etc.)
- Bottom composer box: textarea + attach/camera/location tools + mic + send
- "EZ may suggest local providers. Confirm before booking." footer

#### [NEW] thinking_screen.dart
- Header: EZ logo chip + "EZ Agent" / "Thinking live" green dot
- User query echo bubble
- "Reasoning" label + shimmer headline
- Vertical timeline with 6 steps:
  1. Understanding request (parse tokens flair)
  2. Scanning nearby providers (radar sweep flair)
  3. Checking ratings & reviews (stars flair)
  4. Comparing prices (range slider flair)
  5. Checking availability (time slot flair)
  6. Shortlisting top matches (rank cards flair)
- Each step: pending → active (yellow glow, shimmer bar) → done (check)
- Animated progress rail
- Footer: dark bar with wave bars + "Finding the best match…" + step counter
- Auto-advances every 1.3s → navigates to Results

#### [NEW] results_screen.dart
- Header: back button + "Top 3 matches" title + refresh icon
- AI insight bar (yellow glow): "Picked 3 of 24 pros based on rating, distance & price"
- 3 ProviderCard widgets (AI Pick #1 highlighted with yellow border & ribbon)
- Each card: avatar initials, verified shield, rating, distance, price, availability tag, reasoning pills, Book Now / Profile buttons

#### [NEW] confirm_screen.dart
- Confetti particles (animated)
- Success burst: 3 concentric circles → animated checkmark
- "Booking confirmed!" headline
- Provider summary card (service, when, where, total)
- Green reminder bar: "Reminder set"
- "Track Provider" (primary) + "Go Home" (soft) buttons

---

## Professional Enhancements vs Original Designs

| Original (Claude Design) | Flutter Refinement |
|---|---|
| Dense, small fonts | Generous spacing, larger touch targets (min 48px) |
| No safe area handling | `SafeArea` + `MediaQuery` padding everywhere |
| Static mockup | `flutter_animate` micro-animations: fade-up, scale, shimmer |
| Cluttered quick services row | Cleaner chip padding + max 6 chips with gentle shadows |
| Flat card grid | `AnimatedContainer` cards with press states |
| No loading/empty states | Skeleton shimmer on thinking screen transitions |
| Hardcoded avatar initials | Gradient avatar with initials, consistent 48/56px sizes |

---

## Verification Plan

### Build Check
```powershell
flutter pub get
flutter analyze
flutter build apk --debug
```

### Manual Verification
- Run on Android emulator / physical device
- Walk through the full flow: Splash → Onboarding → Role → Home → Composer → Thinking → Results → Confirm
- Verify animations play correctly
- Check fonts render (Google Fonts)
- Verify bottom nav highlight states
