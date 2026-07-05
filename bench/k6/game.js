// Latency & throughput scenario.
//
// Each VU iteration plays ONE full tic-tac-toe game over two sockets:
//   - open X and O sockets, join both (O's join fills the game -> game_start)
//   - play the deterministic X-win line, measuring each move's round-trip
//   - close both sockets (disconnect fires the presence-leave / game-stop path)
//
// Concurrency = number of VUs, and each VU == one live game (two connections).
// This exercises the whole hot path: join -> start_child, per-move
// find_or_start_game + play + broadcast, and presence cleanup on close.
//
// To simulate LONGER games/sessions (tic-tac-toe caps at 9 moves), use:
//   THINK    ms of "think time" before each move   (default 0)
//   ROUNDS   games per session via server `reset`   (default 1)
// A session holds its two sockets open for ROUNDS games with THINK between every
// move (heartbeats keep it under the 300s idle timeout), so e.g.
// THINK=2000 ROUNDS=5 is a ~90s session of two connections.
//
// Config via env vars:
//   TARGET   host:port to hit          (default localhost:3000)
//   VSN      Phoenix serializer vsn    (default 2.0.0)
//   VUS / ITERATIONS / DURATION / STAGES  standard k6 knobs (see below)
//   MOVE_P95 threshold for move_rtt p95 in ms (default 250)
//   THINK    think-time ms between moves (default 0)
//   ROUNDS   rounds (games) per session  (default 1)
//   HB       heartbeat interval ms       (default 30000)
import { check } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';
import { Phoenix, socketUrl } from './lib/phoenix.js';

const TARGET = __ENV.TARGET || 'localhost:3000';
const VSN = __ENV.VSN || '2.0.0';
const MOVE_P95 = __ENV.MOVE_P95 || '250';
const THINK = parseInt(__ENV.THINK || '0', 10);
const ROUNDS = parseInt(__ENV.ROUNDS || '1', 10);
const HB = parseInt(__ENV.HB || '30000', 10);

const joinLatency = new Trend('join_latency', true);
const gameStartLatency = new Trend('game_start_latency', true);
const moveRtt = new Trend('move_rtt', true);
const gameDuration = new Trend('game_duration', true);
const gamesCompleted = new Counter('games_completed');
const wsErrors = new Counter('ws_errors');
const moveErrors = new Rate('move_errors');

function sleep(ms) {
  return ms > 0 ? new Promise((r) => setTimeout(r, ms)) : Promise.resolve();
}

// Play one game to game_end (or a rejected move), starting with `current`.
// Returns { ended, current } where `current` is meaningless once ended.
async function playGame(x, o, current) {
  const start = nowMs();
  for (let i = 0; i < CELLS.length; i++) {
    const [mx, my] = CELLS[i];
    await sleep(THINK);
    const sock = current === 'X' ? x : o;
    const m0 = nowMs();
    const res = await sock.play(mx, my);
    moveRtt.add(nowMs() - m0);
    if (res.kind === 'reply') {
      moveErrors.add(true);
      return { ended: false };
    }
    moveErrors.add(false);
    if (res.event === 'game_end') {
      check(res, { 'valid outcome': (r) => OUTCOMES.indexOf(r.payload.outcome) >= 0 });
      gameDuration.add(nowMs() - start);
      return { ended: true };
    }
    current = res.payload.current_player;
  }
  return { ended: false };
}

// The server picks the starting player at random per game
// (Game.State.initial -> select_player_randomly), so we don't hardcode a
// winning line for a fixed player. Instead we fill cells in a fixed order,
// letting whichever socket is `current_player` take the next cell, and play
// until game_end (a win or a full-board draw). Each cell is distinct and thus
// empty when reached, and we follow the server's reported turn, so every move
// is legal.
const CELLS = [
  [0, 0], [1, 1], [2, 2],
  [0, 1], [0, 2], [1, 0],
  [2, 0], [1, 2], [2, 1],
];
const OUTCOMES = ['X wins', 'O wins', 'Draw'];

export const options = buildOptions();

function buildOptions() {
  const o = {
    thresholds: {
      move_errors: ['rate==0'],
      ws_errors: ['count==0'],
      move_rtt: [`p(95)<${MOVE_P95}`],
    },
  };
  if (__ENV.STAGES) {
    // STAGES="10s:50,30s:200,10s:0" -> ramp target VUs over durations
    o.stages = __ENV.STAGES.split(',').map((s) => {
      const [duration, target] = s.split(':');
      return { duration, target: parseInt(target, 10) };
    });
  } else if (__ENV.DURATION) {
    o.vus = parseInt(__ENV.VUS || '1', 10);
    o.duration = __ENV.DURATION;
  } else {
    o.vus = parseInt(__ENV.VUS || '1', 10);
    o.iterations = parseInt(__ENV.ITERATIONS || '1', 10);
  }
  return o;
}

function nowMs() {
  return Date.now();
}

const RUN = __ENV.RUN_ID || 'r';

export default async function () {
  // Unique game id per iteration AND per run (RUN_ID) so games never collide
  // across VUs or across repeated invocations that reuse VU/ITER numbering.
  const gameId = `g-${RUN}-${__VU}-${__ITER}`;
  const topic = `game:${gameId}`;
  const url = socketUrl(TARGET, VSN);

  const x = new Phoenix(url);
  const o = new Phoenix(url);

  try {
    await Promise.all([x.opened(), o.opened()]);

    // X joins first (creates the game, waits for a partner).
    let t = nowMs();
    const xJoin = await x.join(topic, { nickname: 'x', sign: 'X' });
    joinLatency.add(nowMs() - t);
    check(xJoin, { 'X join ok': (r) => r.status === 'ok' && r.response.playing_as === 'X' });

    // O joins -> game becomes full -> game_start broadcast to both.
    t = nowMs();
    const oJoin = await o.join(topic, { nickname: 'o', sign: 'O' });
    joinLatency.add(nowMs() - t);
    check(oJoin, { 'O join ok': (r) => r.status === 'ok' && r.response.playing_as === 'O' });

    // Heartbeats keep long (high-THINK) sessions under the 300s idle timeout.
    x.startHeartbeat(HB);
    o.startHeartbeat(HB);

    // Both sockets should receive game_start.
    const gs = await Promise.all([x.waitEvent(['game_start']), o.waitEvent(['game_start'])]);
    gameStartLatency.add(nowMs() - t);
    check(gs[0], { 'game_start has current_player': (r) => r.payload.current_player === 'X' || r.payload.current_player === 'O' });

    // Play ROUNDS games back-to-back on the same sockets, using `reset` between
    // rounds. Each game is turn-driven, following the server's current_player.
    let current = gs[0].payload.current_player;
    for (let round = 0; round < ROUNDS; round++) {
      const { ended } = await playGame(x, o, current);
      check(null, { 'game ended': () => ended });
      if (!ended) break;
      gamesCompleted.add(1);
      if (round < ROUNDS - 1) {
        // reset -> server re-broadcasts game_start with a fresh board/turn.
        x.push('reset', {});
        const rs = await Promise.all([x.waitEvent(['game_start']), o.waitEvent(['game_start'])]);
        // Cells repeat next round; drop stale broadcasts so they can't match.
        x.clearBuffer();
        o.clearBuffer();
        current = rs[0].payload.current_player;
      }
    }
  } catch (e) {
    wsErrors.add(1);
    // Surface the first few for debugging; k6 keeps running other VUs.
    console.error(`game ${gameId} failed: ${e.message}`);
  } finally {
    x.close();
    o.close();
  }
}
