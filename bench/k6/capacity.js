// Max-capacity scenario.
//
// Each VU opens ONE socket, joins a unique game as X, and HOLDS the connection
// open (sending heartbeats) for HOLD seconds. Concurrency = VUs, so ramping VUs
// upward ramps the number of simultaneously-open channels/connections. We push
// the ramp until connect errors appear or latency degrades; cross-reference the
// peak with the BEAM sampler (process_count / active_games / memory).
//
// One connection per VU (rather than two) maximizes connections per ephemeral
// port on the load host. These are single-player joins that never start a game
// but still allocate a socket + channel + GameServer + Registry entry each.
//
// Config via env vars:
//   TARGET     host:port                     (default localhost:3000)
//   VSN        Phoenix serializer vsn        (default 2.0.0)
//   TARGET_VUS peak concurrent connections   (default 500)
//   RAMP       ramp-up duration              (default 30s)
//   HOLD       plateau duration              (default 30s)
//   HB         heartbeat interval ms         (default 30000)
//   STAGES     explicit "dur:target,..." override for the ramp
import { check } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { Phoenix, socketUrl } from './lib/phoenix.js';

const TARGET = __ENV.TARGET || 'localhost:3000';
const VSN = __ENV.VSN || '2.0.0';
const HOLD_MS = parseDuration(__ENV.HOLD || '30s');
const HB = parseInt(__ENV.HB || '30000', 10);

const joinLatency = new Trend('join_latency', true);
const connectionsOpened = new Counter('connections_opened');
const connectErrors = new Counter('connect_errors');

export const options = {
  scenarios: {
    capacity: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: buildStages(),
      gracefulStop: '10s',
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    connect_errors: ['count==0'],
  },
};

function buildStages() {
  if (__ENV.STAGES) {
    return __ENV.STAGES.split(',').map((s) => {
      const [duration, target] = s.split(':');
      return { duration, target: parseInt(target, 10) };
    });
  }
  const target = parseInt(__ENV.TARGET_VUS || '500', 10);
  return [
    { duration: __ENV.RAMP || '30s', target },
    { duration: __ENV.HOLD || '30s', target },
    { duration: '5s', target: 0 },
  ];
}

function parseDuration(d) {
  const m = /^(\d+)(ms|s|m)?$/.exec(d.trim());
  if (!m) return 30000;
  const n = parseInt(m[1], 10);
  return m[2] === 'm' ? n * 60000 : m[2] === 'ms' ? n : n * 1000;
}

const RUN = __ENV.RUN_ID || 'r';

export default async function () {
  // One held connection per VU. RUN_ID keeps topics distinct across runs.
  const topic = `game:cap-${RUN}-${__VU}`;
  const sock = new Phoenix(socketUrl(TARGET, VSN));
  try {
    await sock.opened();
  } catch (e) {
    connectErrors.add(1);
    return;
  }

  try {
    const t = Date.now();
    const res = await sock.join(topic, { nickname: `cap-${__VU}`, sign: 'X' });
    joinLatency.add(Date.now() - t);
    check(res, { 'join ok': (r) => r.status === 'ok' });
    connectionsOpened.add(1);

    sock.startHeartbeat(HB);
    // Hold the connection open for the plateau.
    await new Promise((resolve) => setTimeout(resolve, HOLD_MS));
  } catch (e) {
    connectErrors.add(1);
  } finally {
    sock.close();
  }
}
