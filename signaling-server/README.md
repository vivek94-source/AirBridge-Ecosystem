# AirBridge Signaling Server

This server provides internet pairing and WebRTC signaling relay.

## Run

```powershell
cd signaling-server
npm install
npm start
```

Server defaults to `ws://127.0.0.1:8080`.

## Message types

- `register`
- `create_session`
- `join_session`
- `peer_matched`
- `signal`

