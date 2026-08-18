# Voice Companion — App

The Flutter "face" of the voice companion. Tap-and-hold to talk; it transcribes
on-device, sends the text to your backend ("the brain"), then shows and speaks
the persona's reply. Holds no API keys — only the backend URL + bearer token you
enter in Settings.

## Prerequisites (Windows dev machine)

- Flutter SDK on PATH.
- **Developer Mode ON** — Flutter needs it for the symlink support used by plugins.
  Run `start ms-settings:developers` and toggle *Developer Mode* on, then re-run
  `flutter pub get`. (Unit/widget tests — `flutter test` — run without it, but an
  on-device `flutter run` / APK build requires it.)

## Run on your Android phone

1. Start the backend on your PC: `uvicorn app.main:app --host 0.0.0.0 --port 8000`
   (see `../backend/README.md`).
2. Find your PC's LAN IP (e.g. `192.168.1.20`) with `ipconfig`. Phone and PC must
   be on the same Wi-Fi.
3. Connect the phone with USB debugging on, then `cd app && flutter run`.
4. In the app: **Settings** (gear icon) → Backend URL `http://192.168.1.20:8000`,
   paste the same `APP_BEARER_TOKEN` as the backend, set a user id → **Save**.
5. Grant microphone + speech-recognition permissions when prompted.
6. Hold the mic button, speak, release. You should see your transcript, then the
   persona's reply, and hear it (the ElevenLabs voice, or the on-device fallback
   voice if TTS is unset).
7. Tap the **people** icon to switch personas; confirm the reply and voice change.
8. To check graceful degradation: pull the PC off Wi-Fi mid-turn — the app shows a
   friendly "Couldn't reach your companion. Tap to try again." message.

## Tests

```
flutter test
```

All unit/widget tests run headless against fakes — no device, keys, or network
needed. (STT and audio playback themselves are device-only and are verified in
step 6 above.)

## Architecture (where things live)

- `lib/models/` — `AppSettings`, `Persona`, `ChatResult`.
- `lib/services/` — `BackendClient`/`DioBackendClient`, `SttService`, `AudioService`
  (just_audio playback + flutter_tts fallback).
- `lib/state/` — Riverpod providers + `ConversationController` (the talk-phase state
  machine: idle → listening → thinking → speaking → idle, or → error).
- `lib/screens/` — talk screen (hold-to-talk), persona picker, settings.
