#!/usr/bin/env bash
# Orchestrate one benchmark run: start the BEAM sampler, run k6, stop the
# sampler, and print where the artifacts landed.
#
# k6 runs INSIDE the compose network (grafana/k6 container) rather than on the
# host. This is deliberate:
#   * "direct to BEAM" (app:3000) doesn't work from a host k6 on Docker Desktop
#     for macOS -- the host port-forward + Go WebSocket dialer hang on the
#     upgrade (nginx and non-Go clients are unaffected). In-network it's fine.
#   * the container has its own network namespace, dodging the host's ~16k
#     ephemeral-port ceiling, and you can scale by launching more k6 containers.
#
# Usage:
#   bench/run.sh <game|capacity> <nginx|direct> [extra k6 args...]
#
# Examples:
#   bench/run.sh game direct
#   bench/run.sh game nginx -e VUS=50 -e DURATION=30s
#   bench/run.sh game direct -e STAGES=10s:50,30s:200,10s:0
#   bench/run.sh capacity direct -e TARGET_VUS=2000 -e RAMP=60s -e HOLD=60s
#
# Env overrides: SAMPLE_INTERVAL (default 2), CONTAINER, K6_IMAGE, NETWORK.
set -uo pipefail

SCENARIO="${1:-}"
WHERE="${2:-}"
shift 2 2>/dev/null || true

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS="$DIR/results"
CONTAINER="${CONTAINER:-tttoe-api-app-1}"
SAMPLE_INTERVAL="${SAMPLE_INTERVAL:-2}"
K6_IMAGE="${K6_IMAGE:-grafana/k6}"

case "$SCENARIO" in
  game)     SCRIPT="game.js" ;;
  capacity) SCRIPT="capacity.js" ;;
  *) echo "error: scenario must be 'game' or 'capacity'" >&2; exit 2 ;;
esac

# In-network targets (service names on the compose network).
case "$WHERE" in
  nginx)  TARGET="nginx:80" ;;
  direct) TARGET="app:3000" ;;
  *) echo "error: target must be 'nginx' or 'direct'" >&2; exit 2 ;;
esac

command -v docker >/dev/null || { echo "error: docker not found" >&2; exit 1; }

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "error: container '$CONTAINER' is not running. Start it: docker-compose up -d" >&2
  exit 1
fi

# Discover the compose network from the app container.
NETWORK="${NETWORK:-$(docker inspect "$CONTAINER" -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}')}"
[ -z "$NETWORK" ] && { echo "error: could not determine docker network" >&2; exit 1; }

mkdir -p "$RESULTS"
STAMP="$(date +%Y%m%d-%H%M%S)"
TAG="${SCENARIO}-${WHERE}-${STAMP}"
BEAM_CSV="$RESULTS/beam-${TAG}.csv"
K6_CSV="k6-${TAG}.csv"           # path inside the mounted /results
K6_SUMMARY="summary-${TAG}.json"

echo "==> scenario=$SCENARIO target=$TARGET ($WHERE) network=$NETWORK"
echo "==> beam sampler -> $BEAM_CSV (every ${SAMPLE_INTERVAL}s)"

# Server-side sampler (host, via docker exec) in the background.
"$DIR/sample-beam.sh" -i "$SAMPLE_INTERVAL" -c "$CONTAINER" -o "$BEAM_CSV" >/dev/null 2>&1 &
SAMPLER_PID=$!
cleanup() { kill "$SAMPLER_PID" 2>/dev/null; wait "$SAMPLER_PID" 2>/dev/null; }
trap cleanup EXIT INT TERM

echo "==> running k6 (image $K6_IMAGE)..."
docker run --rm --network "$NETWORK" \
  -v "$DIR/k6:/scripts:ro" \
  -v "$RESULTS:/results" \
  -e "TARGET=$TARGET" \
  "$K6_IMAGE" run \
    --out "csv=/results/$K6_CSV" \
    --summary-export "/results/$K6_SUMMARY" \
    -e "TARGET=$TARGET" \
    -e "RUN_ID=$STAMP" \
    "$@" \
    "/scripts/$SCRIPT"
K6_EXIT=$?

cleanup
trap - EXIT INT TERM

echo
echo "==> artifacts:"
echo "    k6 summary : $RESULTS/$K6_SUMMARY"
echo "    k6 series  : $RESULTS/$K6_CSV"
echo "    beam series: $BEAM_CSV"
echo "==> BEAM tail (ts,proc,mem_total_mb,mem_proc_mb,run_queue,gsup_mbox,rooms_mbox,active_games):"
tail -n 5 "$BEAM_CSV" 2>/dev/null
exit $K6_EXIT
