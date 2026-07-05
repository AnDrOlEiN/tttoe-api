# Socket load-test harness

Load-tests the Phoenix **Channels/WebSocket** path of the tic-tac-toe app with
[k6](https://k6.io), plus a server-side sampler that records BEAM internals so
you can see *what* saturates, not just client-side numbers.

## What it measures

- **`game.js`** — latency & throughput. Each VU iteration plays one full game
  over **two** sockets (X + O): join both, then play turn-by-turn until
  `game_end` (win or draw). Exercises the whole hot path: join → `start_child`,
  per-move `find_or_start_game` + `play` + broadcast, and presence cleanup on
  disconnect.
- **`capacity.js`** — max concurrent connections. Each VU opens **one** socket,
  joins, and holds it (with heartbeats). Ramp VUs up to find the ceiling.

The starting player is random per game (server-side
`Game.State.initial`), so `game.js` is turn-driven — it follows the
`current_player` the server reports rather than assuming who goes first.

## Prerequisites

- The stack running: from the repo root, `docker-compose up -d`
  (the repo's `docker-compose.override.yml` publishes the app on `:3000`).
- Docker (k6 runs as a container — see below). A host `k6` is **not** required.

> **Why k6 runs in a container.** k6 is launched inside the compose network
> (`grafana/k6`). Hitting the BEAM directly from a *host* k6 fails on Docker
> Desktop for macOS — the host port-forward + Go WebSocket dialer hang on the
> upgrade handshake (nginx and non-Go clients are unaffected). In-network it
> works, it dodges the host's ~16k ephemeral-port ceiling, and it scales by
> launching more k6 containers. `run.sh` handles all of this.

## Quickstart

```bash
# 1-game smoke, straight to the BEAM (app:3000) and via nginx (nginx:80)
bench/run.sh game direct
bench/run.sh game nginx

# throughput/latency: 50 concurrent games for 30s
bench/run.sh game direct -e VUS=50 -e DURATION=30s

# ramp games to find where latency/mailboxes blow up
bench/run.sh game direct -e STAGES=10s:50,30s:400,10s:0

# LONGER games/sessions: 200 held game-sessions, each 5 rounds with 1s think-time
bench/run.sh game direct -e VUS=200 -e DURATION=2m -e ROUNDS=5 -e THINK=1000

# capacity: ramp to 2000 held connections, hold 60s
bench/run.sh capacity direct -e TARGET_VUS=2000 -e RAMP=60s -e HOLD=60s
```

### Simulating longer games

Tic-tac-toe is capped at 9 moves, so "longer" means longer-lived **sessions**:
`THINK` adds think-time (ms) before each move, and `ROUNDS` plays multiple games
back-to-back on the same two sockets via the server's `reset` (heartbeats keep
the session under the 300s idle timeout). `THINK=1000 ROUNDS=5` ≈ a 90s session
holding two connections. Unlike `capacity.js` (idle held connections), these
sessions stay *active* the whole time — so `active_games` holds steady at the VU
count instead of churning. The `game_duration` Trend reports wall-clock per game.

`run.sh <game|capacity> <nginx|direct> [extra k6 args...]` — starts the BEAM
sampler, runs k6, stops the sampler, and prints artifact paths.

## Config (k6 `-e` env vars)

**game.js**: `VUS`, `ITERATIONS`, `DURATION`, `STAGES` (`"dur:target,..."`),
`MOVE_P95` (move_rtt p95 threshold ms, default 250), `VSN` (default `2.0.0`),
`THINK` (think-time ms between moves, default 0), `ROUNDS` (games per session via
`reset`, default 1), `HB` (heartbeat ms, default 30000). With no
`STAGES`/`DURATION` it defaults to 1 VU × 1 iteration.

**capacity.js**: `TARGET_VUS` (default 500), `RAMP` (30s), `HOLD` (30s),
`HB` (heartbeat ms, 30000), `STAGES` (override), `VSN`.

`run.sh` env: `SAMPLE_INTERVAL` (BEAM sample seconds, default 2), `CONTAINER`
(default `tttoe-api-app-1`), `K6_IMAGE` (default `grafana/k6`), `NETWORK`
(auto-detected).

## Outputs (`bench/results/`)

- `summary-<tag>.json` — k6 end-of-run summary.
- `k6-<tag>.csv` — k6 time series (per-metric samples).
- `beam-<tag>.csv` — server sampler, columns:
  `ts,process_count,mem_total_mb,mem_proc_mb,run_queue,gsup_mbox,rooms_mbox,active_games`

### Key k6 metrics

`join_latency`, `game_start_latency`, `move_rtt`, `game_duration` (Trends),
`games_completed` (Counter), `move_errors` (Rate, thresholded `==0`), `ws_errors`
(thresholded `==0`); for capacity: `connections_opened`, `connect_errors`
(thresholded `==0`).

### Reading the BEAM CSV — the point of interest

`gsup_mbox` is the **GameSupervisor mailbox length**. Every join *and every move*
calls `GameSupervisor.find_or_start_game/1`. This used to go through
`DynamicSupervisor.start_child` unconditionally, making that single process a
global serialization point (measured at an 800-VU ramp: `run_queue` peaking at
208, `gsup_mbox` samples up to 26 — see Recorded results below).
`find_or_start_game/1` now takes a Registry fast-path
(concurrent ETS read) and only calls `start_child` when the game doesn't exist
yet, so the supervisor is off the per-move hot path. Expect `gsup_mbox ≈ 0`
even under ramp; if it climbs again, something reintroduced supervisor calls to
the hot path. `active_games` = live game processes; `rooms_mbox` = the
(REST-only) Rooms GenServer mailbox.

Quick peaks from a result file:
```bash
CSV=bench/results/beam-game-direct-<tag>.csv
awk -F, 'NR>1{for(i=2;i<=8;i++)if($i>m[i])m[i]=$i} END{print "proc="m[2]" mem="m[3]"MB rq="m[5]" gsup="m[6]" games="m[8]}' "$CSV"
```

## Recorded results (2026-07-05)

Execution environment — all numbers are from this setup and are *indicative*
(Docker Desktop VM, see Caveats):

- **Host**: MacBook Pro, Apple M3 Pro (11 cores), 18 GB RAM, macOS 26.5.1
- **Runtime**: Docker Desktop (Docker 29.1.3, linux/arm64 VM); app + nginx +
  k6 all as containers on the compose network
- **App image**: multi-stage Distillery release, Elixir 1.7.3 / Phoenix 1.3
  on Alpine, `MIX_ENV=prod`
- **Load gen**: `grafana/k6` v2.1.0, run in-network (`bench/run.sh`),
  targeting `app:3000` directly (no nginx hop)

### Throughput ramp — `game`, `STAGES=20s:400,40s:800,10s:0` (70 s, peak 800 VUs = 800 concurrent games)

Run twice: with the original `find_or_start_game` (always
`DynamicSupervisor.start_child`) and after the Registry fast-path fix.

| metric                        | before fast-path | after fast-path |
|-------------------------------|------------------|-----------------|
| games completed               | 34,677 (~495/s)  | 37,334 (~533/s) |
| move RTT avg / p95            | 62.8 ms / 245 ms | 56.7 ms / 224 ms |
| join latency avg / p95        | 69.2 ms / 289 ms | 65.3 ms / 272 ms |
| peak scheduler run queue      | **208**          | **42**          |
| peak GameSupervisor mailbox   | 6                | 3               |
| move / ws errors              | 0 / 0            | 0 / 0           |
| BEAM peak                     | ~3,275 procs, 137 MB, 679 live games | ~3,452 procs, 141 MB, 598 live games |

The run-queue collapse (208 → 42) is the supervisor serialization leaving the
per-move hot path; throughput +~8% with lower tails on identical hardware.

### Capacity ramp — `capacity`, ramp to 5,000 held connections

Recorded before the fast-path fix (the fix does not affect this path):
peak ~4,970 held connections, 0 connect errors, join avg 1.9 ms / p95 6 ms;
BEAM peak 15,169 processes, 313 MB total (~50 KB per connection+game process),
run queue ≤ 2. Idle connections are memory-bound, not CPU-bound.

## Raising ceilings (when the *harness* is the limit, not the app)

- **More connections than one k6 container can source**: launch several in
  parallel (each gets its own port range). Use a distinct `RUN_ID` per container
  so game topics don't collide:
  ```bash
  for i in 1 2 3; do
    docker run --rm --network tttoe-api_default -v "$PWD/bench/k6:/scripts:ro" \
      -e TARGET=app:3000 -e RUN_ID=c$i grafana/k6 run \
      -e TARGET_VUS=5000 -e RAMP=60s -e HOLD=120s /scripts/capacity.js &
  done; wait
  ```
- **End-to-end via nginx at high load**: nginx `worker_connections` (default
  1024) will cap you; raise it (and `worker_rlimit_nofile`) in
  `services/nginx/` and rebuild if you push the nginx path hard.
- **Host-run k6** (if you ever bypass the container for the nginx path): macOS
  gives ~16k ephemeral ports/IP; raise with
  `sudo sysctl -w net.inet.ip.portrange.first=1024` (resets on reboot).

## Caveats

- **Docker Desktop for macOS runs in a VM** — absolute numbers are *indicative*,
  not production ceilings. For true limits run the app on a Linux host.
- The app uses **Cowboy 1.x** (Phoenix 1.3), a lower ceiling than Cowboy 2.
- The sampler shells into the container via `bin/tictactoe rpc` (~1.4s/sample);
  it can't resolve sub-second activity, so use `DURATION`/`HOLD` of at least a
  few seconds for the BEAM CSV to be meaningful.

## Cleanup

```bash
docker-compose down        # stop the stack
rm -rf bench/results/*      # discard captured runs
```
