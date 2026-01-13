# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Block** is an iOS app that uses NFC tags to toggle app blocking on/off via iOS Screen Time APIs. Users register an NFC tag, select apps to block, then scan the tag to instantly enable or disable blocking for those apps.

## Build & Development Commands

This is an Xcode-based iOS project. **Note:** Full Xcode is required (not just Command Line Tools).

- **Build**: Open `Block.xcodeproj` in Xcode and use Cmd+B
- **Run**: Open in Xcode and use Cmd+R (requires iPhone with NFC - iPhone 7+)
- **Clean**: In Xcode, Product → Clean Build Folder

The project has no tests currently and no external dependencies (uses only iOS system frameworks).

## Architecture Overview

### Core Components

The app follows a singleton-based architecture with three main managers:

1. **AppConfigurationStore** (`Services/AppConfigurationStore.swift`)
   - Singleton shared instance managing app state
   - Properties: `selectedApps`, `registeredTagIdentifier`, `isBlockingEnabled`
   - Persists state to UserDefaults
   - Observable: View updates happen automatically via `@Published` properties

2. **ScreenTimeManager** (`Services/ScreenTimeManager.swift`)
   - `@MainActor` singleton handling all Screen Time API interactions
   - Manages `ManagedSettingsStore` for app blocking
   - Methods: `requestAuthorization()`, `enableBlocking()`, `disableBlocking()`, `toggleBlocking()`
   - Key insight: Setting `store.shield.applications` blocks apps with iOS's default shield screen

3. **NFCManager** (`Services/NFCManager.swift`)
   - Singleton handling NFC tag reading via `NFCTagReaderSession`
   - Supports all major tag types: ISO7816, FeliCa, ISO15693, MiFare
   - Tag identifiers are hex strings extracted from tag hardware IDs
   - Has `onTagScanned` callback for coordination with UI

### View Architecture

- **ContentView**: Main screen with status display and scan button
- **SettingsView**: Screen Time authorization + app selection (uses `FamilyActivityPicker`)
- **TagRegistrationView**: NFC tag registration flow
- **ArtNouveauTheme**: Design system with Art Nouveau styling (organic curves, gradient colors)

### Data Flow

1. User scans NFC tag → `NFCManager` reads hardware ID
2. If no tag registered: Store tag ID in `AppConfigurationStore`
3. If tag matches registered: Toggle blocking via `ScreenTimeManager`
4. `ScreenTimeManager.toggleBlocking()` → Updates `ManagedSettingsStore.shield.applications`
5. iOS enforces blocking automatically with shield screen

### Key Technical Details

- **ApplicationToken**: System-managed type from Family Controls framework. Cannot be directly serialized - selection persists via system, not UserDefaults
- **Background NFC**: App can detect tag scans when backgrounded (requires proper entitlements)
- **@MainActor**: Both `ScreenTimeManager` and `NFCManager` are MainActor-isolated for thread safety
- **Singleton pattern**: All managers use `shared` singleton instances, injected as `@StateObject` in views

## iOS Requirements & Capabilities

- **Minimum iOS**: 15.0 (required for Family Controls)
- **Device**: iPhone with NFC (iPhone 7+)
- **Required Capabilities** (configured in Xcode project):
  - NFC Tag Reading
  - Family Controls (requires special entitlement)
  - Background Modes: NFC Tag Reading

## Working with Screen Time APIs

- Authorization is required via `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
- Must check `authorizationStatus == .approved` before blocking
- `ManagedSettingsStore.clearAllSettings()` disables all blocking
- Custom shield screens require separate app extension (not implemented)

## Working with NFC

- Always check `NFCTagReaderSession.readingAvailable` before scanning
- Tag identifiers are hardware-based and unique per physical tag
- Session invalidation patterns:
  - User cancellation: Silent (no error shown)
  - Timeout: Show user error message
  - Connection failure: Show error message
- Delegate methods are `nonisolated` - use `Task { @MainActor in ... }` for UI updates

## Art Nouveau Design System

The app uses an Art Nouveau theme (`Views/ArtNouveauTheme.swift`):
- Colors: Forest green, olive green, teal, gold accents
- Fonts: Georgia (serif) with specific size scales
- Components: `ArtNouveauCard`, `ArtNouveauOrnament`, `ArtNouveauButtonStyle`
- Visual style: Organic curves, decorative elements, gradient overlays

When adding UI elements, use the theme's predefined colors, fonts, and components for consistency.

## Emergency Override System

The app includes a typing challenge override for emergency situations when the NFC tag is unavailable:

- **TypingChallengeView** (`Views/TypingChallengeView.swift`): Modal that requires users to type a motivational passage exactly to disable blocking
- Accessible via Settings menu in "Emergency Access" section (only appears when blocking is active)
- Provides friction to discourage casual bypass while ensuring access is always possible
- Normalizes input (case-insensitive, ignores extra whitespace) for reasonable error tolerance

## Selected Apps Display

- Due to iOS privacy restrictions, `ApplicationToken` doesn't expose app names or icons programmatically
- The `FamilyActivityPicker` shows app details in its native UI, but this info cannot be extracted
- Settings shows count of selected apps (e.g., "3 Apps Selected") instead of individual app names
- Users must use the FamilyActivityPicker UI to see which specific apps are selected

## Roadmap Context

See `Roadmap.md` for additional planned features including:
- Time-of-day automatic locks
- Cooldown timers
- Motion-based unlock requirements (step count)

These features would extend the existing toggle mechanism with additional friction or automation.
