import asyncio
import json
import time
from collections import deque
from threading import Thread

import cv2
import mediapipe as mp
import websockets

HOST = "127.0.0.1"
PORT = 8765

clients = set()


class GestureEmitter:
    def __init__(self, loop: asyncio.AbstractEventLoop):
        self.loop = loop
        self.queue = asyncio.Queue()
        self.last_emit = {}

    def emit(self, gesture: str, state: str, cooldown: float = 0.2):
        key = f"{gesture}:{state}"
        now = time.time()
        if now - self.last_emit.get(key, 0.0) < cooldown:
            return
        self.last_emit[key] = now

        payload = {
            "gesture": gesture,
            "state": state,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        }
        asyncio.run_coroutine_threadsafe(self.queue.put(payload), self.loop)


async def ws_handler(websocket):
    clients.add(websocket)
    try:
        await websocket.wait_closed()
    finally:
        clients.discard(websocket)


async def broadcaster(emitter: GestureEmitter):
    while True:
        payload = await emitter.queue.get()
        if not clients:
            continue
        dead = []
        text = json.dumps(payload)
        for ws in clients:
            try:
                await ws.send(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            clients.discard(ws)


def fingers_open(landmarks):
    # MediaPipe landmarks are normalized (0.0 to 1.0).
    tips = [8, 12, 16, 20]
    pips = [6, 10, 14, 18]
    open_count = 0
    for tip, pip in zip(tips, pips):
        if landmarks[tip].y < landmarks[pip].y:
            open_count += 1
    return open_count >= 3


def run_camera_loop(emitter: GestureEmitter):
    mp_hands = mp.solutions.hands
    cap = cv2.VideoCapture(0)
    swipe_x = deque(maxlen=7)
    pinch_active = False
    last_open_palm_emit = 0.0

    with mp_hands.Hands(
        model_complexity=0,
        min_detection_confidence=0.6,
        min_tracking_confidence=0.6,
    ) as hands:
        while cap.isOpened():
            ok, frame = cap.read()
            if not ok:
                continue

            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result = hands.process(rgb)

            if result.multi_hand_landmarks:
                hand = result.multi_hand_landmarks[0]
                lm = hand.landmark

                # PINCH = thumb tip (4) near index tip (8)
                dx = lm[4].x - lm[8].x
                dy = lm[4].y - lm[8].y
                pinch_dist = (dx * dx + dy * dy) ** 0.5
                if pinch_dist < 0.05 and not pinch_active:
                    pinch_active = True
                    emitter.emit("PINCH", "START", cooldown=0.15)
                elif pinch_dist > 0.08 and pinch_active:
                    pinch_active = False
                    emitter.emit("PINCH", "END", cooldown=0.15)

                # SWIPE detection by wrist X movement
                wrist_x = lm[0].x
                swipe_x.append(wrist_x)
                if len(swipe_x) == swipe_x.maxlen:
                    delta = swipe_x[-1] - swipe_x[0]
                    if delta > 0.18:
                        emitter.emit("SWIPE_RIGHT", "START", cooldown=0.4)
                        swipe_x.clear()
                    elif delta < -0.18:
                        emitter.emit("SWIPE_LEFT", "START", cooldown=0.4)
                        swipe_x.clear()

                # OPEN_PALM idle event
                if fingers_open(lm):
                    now = time.time()
                    if now - last_open_palm_emit > 0.8:
                        emitter.emit("OPEN_PALM", "START", cooldown=0.2)
                        last_open_palm_emit = now

            cv2.imshow("AirBridge Gesture Engine", frame)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    cap.release()
    cv2.destroyAllWindows()


async def main():
    loop = asyncio.get_running_loop()
    emitter = GestureEmitter(loop)

    camera_thread = Thread(target=run_camera_loop, args=(emitter,), daemon=True)
    camera_thread.start()

    async with websockets.serve(ws_handler, HOST, PORT):
        print(f"Gesture WebSocket running on ws://{HOST}:{PORT}")
        await broadcaster(emitter)


if __name__ == "__main__":
    asyncio.run(main())

