#!/usr/bin/env python3
"""
Minimal raw-WebSocket client (stdlib only) that plays a full 2-player
tic-tac-toe game against the Phoenix Channels API.

Protocol: Phoenix v1 JSON serializer (?vsn=1.0.0) -> messages are plain maps:
  {"topic","event","payload","ref"}
"""
import base64
import json
import os
import socket
import struct

HOST = os.environ.get("TTOE_HOST", "localhost")
PORT = int(os.environ.get("TTOE_PORT", "80"))
PATH = "/socket/websocket?vsn=1.0.0"
GAME = os.environ.get("TTOE_GAME", "demo")


class WS:
    def __init__(self, host, port, path):
        self.sock = socket.create_connection((host, port), timeout=10)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "Origin: http://localhost\r\n\r\n"
        )
        self.sock.sendall(req.encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("handshake closed")
            buf += chunk
        status = buf.split(b"\r\n", 1)[0].decode()
        if "101" not in status:
            raise RuntimeError(f"handshake failed: {status}")
        self._rest = buf.split(b"\r\n\r\n", 1)[1]  # leftover bytes (usually empty)

    def _recv_exact(self, n):
        data = self._rest
        self._rest = b""
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise RuntimeError("connection closed")
            data += chunk
        if len(data) > n:  # shouldn't happen given recv sizing, but be safe
            self._rest = data[n:]
            data = data[:n]
        return data

    def _send_frame(self, opcode, payload=b""):
        mask = os.urandom(4)
        ln = len(payload)
        header = bytearray([0x80 | opcode])  # FIN + opcode
        if ln < 126:
            header.append(0x80 | ln)  # mask bit + length
        elif ln < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", ln)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", ln)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def send(self, text):
        self._send_frame(0x1, text.encode())

    def recv_frame(self, timeout=1.0):
        self.sock.settimeout(timeout)
        try:
            b0, b1 = self._recv_exact(2)
        except (socket.timeout, TimeoutError):
            return None
        opcode = b0 & 0x0F
        length = b1 & 0x7F
        if length == 126:
            length = struct.unpack(">H", self._recv_exact(2))[0]
        elif length == 127:
            length = struct.unpack(">Q", self._recv_exact(8))[0]
        data = self._recv_exact(length) if length else b""
        if opcode == 0x8:  # close
            return ("close", data)
        if opcode == 0x9:  # ping -> pong
            self._pong(data)
            return self.recv_frame(timeout)
        if opcode == 0xA:  # pong
            return self.recv_frame(timeout)
        return ("text", data.decode())

    def _pong(self, data):
        self._send_frame(0xA, data)

    def close(self):
        try:
            self._send_frame(0x8)  # close frame
            self.sock.close()
        except Exception:
            pass


class Player:
    def __init__(self, name, sign):
        self.name = name
        self.sign = sign
        self.ref = 0
        self.ws = WS(HOST, PORT, PATH, name)

    def _next_ref(self):
        self.ref += 1
        return str(self.ref)

    def push(self, event, payload):
        ref = self._next_ref()
        msg = {"topic": f"game:{GAME}", "event": event, "payload": payload, "ref": ref}
        self.ws.send(json.dumps(msg))
        return ref

    def join(self):
        self.push("phx_join", {"nickname": self.name, "sign": self.sign})

    def play(self, x, y):
        self.push("play", {"x": x, "y": y})

    def close(self):
        self.ws.close()

    def drain(self, timeout=1.0, label=None):
        """Read and pretty-print all messages currently available."""
        out = []
        while True:
            frame = self.ws.recv_frame(timeout=timeout)
            if frame is None:
                break
            kind, data = frame
            if kind == "close":
                print(f"  [{self.name}] << CLOSE")
                break
            try:
                m = json.loads(data)
            except Exception:
                print(f"  [{self.name}] << {data}")
                continue
            out.append(m)
            print(f"  [{self.name}] << {fmt(m)}")
            timeout = 0.4  # after first, drain quickly
        return out


def fmt(m):
    ev = m.get("event")
    p = m.get("payload", {})
    if ev == "phx_reply":
        st = p.get("status")
        resp = p.get("response", {})
        return f"reply status={st} {resp}"
    if ev in ("game_start", "game_update", "game_end", "reset"):
        board = p.get("board")
        extra = {k: v for k, v in p.items() if k != "board"}
        return f"{ev} {extra}\n{render_board(board)}"
    return f"{ev} {p}"


def render_board(board):
    if not board:
        return ""
    rows = ["top", "middle", "bottom"]
    lines = []
    for r in rows:
        cells = [c if c else "." for c in board.get(r, ["", "", ""])]
        lines.append("      " + " | ".join(cells))
    return "\n".join(lines)


def main():
    print(f"Connecting two players to ws://{HOST}:{PORT}{PATH}  (game:{GAME})\n")

    x = Player("alice", "X")
    o = Player("bob", "O")

    print("== alice joins as X ==")
    x.join()
    x.drain(1.5)

    print("== bob joins as O  (this fills the game -> game_start) ==")
    o.join()
    o.drain(1.5)
    print("-- alice sees game_start too --")
    x.drain(1.5)

    # X wins the left column: (0,0)(0,1)(0,2)
    moves = [
        (x, 0, 0),
        (o, 1, 0),
        (x, 0, 1),
        (o, 1, 1),
        (x, 0, 2),  # X completes column x=0
    ]
    for player, mx, my in moves:
        print(f"\n== {player.name} ({player.sign}) plays ({mx},{my}) ==")
        player.play(mx, my)
        player.drain(1.5)
        # let the other player observe the broadcast
        other = o if player is x else x
        other.drain(1.0)

    print("\nGame finished. Closing sockets.")
    x.close()
    o.close()


if __name__ == "__main__":
    main()
