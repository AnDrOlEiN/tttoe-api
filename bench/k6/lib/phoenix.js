// Minimal Phoenix 1.3 Channels client for k6, built on the event-loop
// WebSocket API so a single VU can drive multiple sockets and run heartbeat
// timers concurrently.
//
// Wire protocol: Phoenix v2 JSON serializer (?vsn=2.0.0) -> every frame is an
// array [join_ref, ref, topic, event, payload]. This mirrors the protocol that
// was validated end-to-end against this server with play_demo.py.
import { WebSocket } from 'k6/websockets';
// setTimeout/clearTimeout/setInterval/clearInterval are globals in k6 >= 1.0.

const DEFAULT_OP_TIMEOUT = 15000; // ms; guards a VU iteration from hanging forever

export function socketUrl(target, vsn) {
  // target is "host:port" (e.g. "localhost:3000" or "localhost:80")
  return `ws://${target}/socket/websocket?vsn=${vsn || '2.0.0'}`;
}

export class Phoenix {
  constructor(url) {
    this.url = url;
    this.ws = new WebSocket(url);
    this._ref = 0;
    this.joinRef = null;
    this.opTimeout = DEFAULT_OP_TIMEOUT;

    this._pending = []; // [{ref?, match?:(event,payload)=>bool, resolve, reject, timer}]
    this._buffer = []; // broadcasts that arrived before anyone awaited them
    this._hb = null;
    this.closed = false;
    this.errored = false;

    this._opened = new Promise((resolve, reject) => {
      this.ws.onopen = () => resolve();
      // onerror before open == connection failure
      this.ws.onerror = (e) => {
        this.errored = true;
        this._failAll(new Error(`ws error: ${e && e.error ? e.error : 'unknown'}`));
        reject(new Error('ws connection error'));
      };
    });

    this.ws.onmessage = (e) => this._route(e.data);
    this.ws.onclose = () => {
      this.closed = true;
      this._failAll(new Error('ws closed'));
      if (this._hb) clearInterval(this._hb);
    };
  }

  opened() {
    return this._opened;
  }

  _nextRef() {
    this._ref += 1;
    return String(this._ref);
  }

  _route(data) {
    let frame;
    try {
      frame = JSON.parse(data);
    } catch (_) {
      return;
    }
    const [, ref, , event, payload] = frame;

    // Reply matched to a pending op by ref (e.g. join ok, or a play error).
    if (event === 'phx_reply' && ref != null) {
      const i = this._pending.findIndex((p) => p.ref === ref);
      if (i >= 0) {
        const p = this._pending.splice(i, 1)[0];
        if (p.timer) clearTimeout(p.timer);
        p.resolve({ kind: 'reply', status: payload && payload.status, response: payload && payload.response });
        return;
      }
      return; // stray reply (e.g. heartbeat ack) -> ignore
    }

    // Broadcast: satisfy the first op whose matcher accepts it, else buffer it.
    const j = this._pending.findIndex((p) => p.match && p.match(event, payload));
    if (j >= 0) {
      const p = this._pending.splice(j, 1)[0];
      if (p.timer) clearTimeout(p.timer);
      p.resolve({ kind: 'event', event, payload });
      return;
    }
    this._buffer.push({ event, payload });
  }

  _failAll(err) {
    const pending = this._pending;
    this._pending = [];
    for (const p of pending) {
      if (p.timer) clearTimeout(p.timer);
      p.reject(err);
    }
  }

  // Wait for a reply to `ref` OR the first broadcast accepted by `match`.
  // Either arg may be null. Checks the buffer first for already-arrived events.
  _await(ref, match, label) {
    if (match) {
      const i = this._buffer.findIndex((m) => match(m.event, m.payload));
      if (i >= 0) {
        const m = this._buffer.splice(i, 1)[0];
        return Promise.resolve({ kind: 'event', event: m.event, payload: m.payload });
      }
    }
    return new Promise((resolve, reject) => {
      const op = { ref, match, resolve, reject, timer: null };
      op.timer = setTimeout(() => {
        const idx = this._pending.indexOf(op);
        if (idx >= 0) this._pending.splice(idx, 1);
        reject(new Error(`timeout waiting for ${label || (ref ? `reply#${ref}` : 'event')}`));
      }, this.opTimeout);
      this._pending.push(op);
    });
  }

  _send(joinRef, ref, topic, event, payload) {
    this.ws.send(JSON.stringify([joinRef, ref, topic, event, payload]));
  }

  // Join a channel; resolves { status, response } from the phx_reply.
  join(topic, payload) {
    const ref = this._nextRef();
    this.joinRef = ref;
    this.topic = topic;
    this._send(ref, ref, topic, 'phx_join', payload);
    return this._await(ref, null, `join ${topic}`).then((r) => ({ status: r.status, response: r.response }));
  }

  // Send a `play` and resolve on the broadcast echoing THIS move's coordinates
  // (game_update / game_end), or a phx_reply error if the move was rejected.
  // Matching by move coordinate disambiguates the broadcasts for the other
  // player's moves, which also arrive on this socket.
  play(x, y) {
    const ref = this._nextRef();
    this._send(this.joinRef, ref, this.topic, 'play', { x, y });
    const match = (ev, pl) =>
      (ev === 'game_update' || ev === 'game_end') && pl && pl.move && pl.move[0] === x && pl.move[1] === y;
    return this._await(ref, match, `move ${x},${y}`);
  }

  // Fire-and-forget push on the joined channel (e.g. 'reset'); the server
  // responds with a broadcast rather than a reply, so await it with waitEvent.
  push(event, payload) {
    this._send(this.joinRef, this._nextRef(), this.topic, event, payload || {});
  }

  // Drop any buffered broadcasts. Call after a fresh game_start so stale
  // broadcasts from a previous round (cells repeat across resets) can't
  // false-match a new move.
  clearBuffer() {
    this._buffer = [];
  }

  // Wait for a specific broadcast event (e.g. 'game_start') with no push.
  waitEvent(events) {
    const set = new Set(events);
    return this._await(null, (ev) => set.has(ev), [...set].join('/'));
  }

  startHeartbeat(intervalMs) {
    this._hb = setInterval(() => {
      if (this.closed || this.errored) return;
      this._send(null, this._nextRef(), 'phoenix', 'heartbeat', {});
    }, intervalMs || 30000);
  }

  close() {
    if (this._hb) clearInterval(this._hb);
    try {
      this.ws.close();
    } catch (_) {
      /* already closing */
    }
  }
}
