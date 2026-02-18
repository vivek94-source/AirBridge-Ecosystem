# AirBridge Prototype

AirBridge is a cross-platform spatial interaction prototype for encrypted file transfer with gestures.

## Implemented stack

- Flutter single codebase (desktop + Android target)
- WebRTC DataChannels for peer-to-peer transfer
- mDNS discovery (`_airbridge._tcp.local`)
- Node.js signaling server for internet pairing (6-digit codes)
- MediaPipe desktop gesture engine (webcam)
- Structured architecture:
  - `CoreTransferEngine`
  - `GestureEngine`
  - `DiscoveryManager`
  - `EncryptionLayer`
  - `UI Layer`

## Project layout

- `lib/core/transfer`: WebRTC transfer engine
- `lib/core/gesture`: gesture abstraction + WebSocket gesture client
- `lib/core/discovery`: mDNS discovery manager
- `lib/core/encryption`: identity + trust state + checksums
- `lib/core/signaling`: signaling client
- `lib/ui`: controller + futuristic animated UI
- `signaling-server`: pairing + signaling relay
- `gesture_engine/desktop`: MediaPipe gesture emitter
- `scripts/bootstrap.ps1`: generates Flutter platform folders after Flutter is installed

## 1) Bootstrap Flutter app

Flutter is not currently detected in PATH on this machine, so run this after installing Flutter:

```powershell
cd C:\Users\ken07\OneDrive\Desktop\AirBridge
.\scripts\bootstrap.ps1
```

## 2) Start signaling server

```powershell
cd C:\Users\ken07\OneDrive\Desktop\AirBridge\signaling-server
npm install
npm start
```

Server endpoint: `ws://127.0.0.1:8080`

## 3) Start desktop gesture engine

```powershell
cd C:\Users\ken07\OneDrive\Desktop\AirBridge\gesture_engine\desktop
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python .\gesture_engine.py
```

Gesture events emitted to: `ws://127.0.0.1:8765`

Event format:

```json
{
  "gesture": "PINCH",
  "state": "START",
  "timestamp": "2026-02-18T12:34:56"
}
```

## 4) Run AirBridge app

```powershell
cd C:\Users\ken07\OneDrive\Desktop\AirBridge
flutter run -d windows
```

For CLI debug animation mode:

```powershell
flutter run -d windows --dart-define=AIRBRIDGE_CLI=true
```

## Gestures (Desktop Phase 1)

- `PINCH START` -> File selection
- `SWIPE_RIGHT START` -> Send selected file
- `SWIPE_LEFT START` -> Cancel
- `OPEN_PALM START` -> Idle status

## Security behavior in this prototype

- WebRTC DTLS/SRTP channel for encrypted transport
- Local device identity persisted with `shared_preferences`
- First-time peer trust confirmation before sending
- SHA-256 integrity check on received file payload

## Current prototype scope

- Modular architecture with decoupled gesture and transfer logic is implemented.
- WebRTC signaling and DataChannel transfer flow is implemented.
- mDNS discovery is best-effort and depends on local network support.
- iOS support is not scaffolded in this package because requested platforms were desktop + Android.

