const express = require('express');
const { WebSocketServer } = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;

const app = express();
app.get('/health', (_, res) => {
  res.json({
    status: 'ok',
    service: 'airbridge-signaling',
    time: new Date().toISOString(),
  });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const clients = new Map(); // deviceId -> ws
const sessions = new Map(); // code -> { hostId, guestId }

function send(ws, payload) {
  if (!ws || ws.readyState !== 1) {
    return;
  }
  ws.send(JSON.stringify(payload));
}

function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function uniqueCode() {
  let code = generateCode();
  while (sessions.has(code)) {
    code = generateCode();
  }
  return code;
}

function cleanSessionsForDevice(deviceId) {
  for (const [code, value] of sessions.entries()) {
    if (value.hostId === deviceId || value.guestId === deviceId) {
      sessions.delete(code);
    }
  }
}

wss.on('connection', (ws) => {
  ws.device = null;

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (_) {
      send(ws, { type: 'error', message: 'invalid_json' });
      return;
    }

    const type = message.type;
    switch (type) {
      case 'register': {
        const deviceId = message.deviceId;
        const deviceName = message.deviceName || 'Unknown Device';
        if (!deviceId) {
          send(ws, { type: 'error', message: 'missing_device_id' });
          return;
        }
        ws.device = { id: deviceId, name: deviceName };
        clients.set(deviceId, ws);
        send(ws, { type: 'register_ack', id: deviceId });
        return;
      }

      case 'create_session': {
        if (!ws.device) {
          send(ws, { type: 'error', message: 'register_first' });
          return;
        }
        const code = uniqueCode();
        sessions.set(code, {
          hostId: ws.device.id,
          guestId: null,
        });
        send(ws, { type: 'session_created', code });
        return;
      }

      case 'join_session': {
        if (!ws.device) {
          send(ws, { type: 'error', message: 'register_first' });
          return;
        }
        const code = String(message.code || '');
        const session = sessions.get(code);
        if (!session) {
          send(ws, { type: 'error', message: 'invalid_code' });
          return;
        }
        if (session.guestId && session.guestId !== ws.device.id) {
          send(ws, { type: 'error', message: 'session_full' });
          return;
        }

        session.guestId = ws.device.id;
        sessions.set(code, session);

        const hostSocket = clients.get(session.hostId);
        const guestSocket = clients.get(session.guestId);
        if (!hostSocket || !guestSocket) {
          send(ws, { type: 'error', message: 'peer_unavailable' });
          return;
        }

        send(hostSocket, {
          type: 'peer_matched',
          code,
          peer: {
            id: guestSocket.device.id,
            name: guestSocket.device.name,
            host: 'relay',
            port: PORT,
          },
        });
        send(guestSocket, {
          type: 'peer_matched',
          code,
          peer: {
            id: hostSocket.device.id,
            name: hostSocket.device.name,
            host: 'relay',
            port: PORT,
          },
        });
        return;
      }

      case 'signal': {
        if (!ws.device) {
          send(ws, { type: 'error', message: 'register_first' });
          return;
        }
        const to = message.to;
        const data = message.data || {};
        const target = clients.get(to);
        if (!target) {
          send(ws, { type: 'error', message: 'target_offline' });
          return;
        }
        send(target, {
          type: 'signal',
          from: ws.device.id,
          data,
        });
        return;
      }
    }
  });

  ws.on('close', () => {
    if (!ws.device) {
      return;
    }
    clients.delete(ws.device.id);
    cleanSessionsForDevice(ws.device.id);
  });
});

server.listen(PORT, () => {
  console.log(`AirBridge signaling server listening on :${PORT}`);
});
