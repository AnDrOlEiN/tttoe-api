#!/usr/bin/env bash
# Sample BEAM internals from the running release into a CSV, once per interval,
# until interrupted (SIGINT/SIGTERM). Uses `bin/tictactoe rpc`, which evaluates
# code on the LIVE node. Distillery's rpc atomizes the whole expression (255-byte
# limit), so the metrics are split across two sub-256B calls per sample.
#
# Columns:
#   ts             unix epoch seconds
#   process_count  :erlang.system_info(:process_count)
#   mem_total_mb   :erlang.memory(:total)      / 1 MiB
#   mem_proc_mb    :erlang.memory(:processes)  / 1 MiB
#   run_queue      :erlang.statistics(:run_queue)   (total ready-to-run procs)
#   gsup_mbox      GameSupervisor mailbox length  <-- the predicted hot-path bottleneck
#   rooms_mbox     Rooms GenServer mailbox length
#   active_games   DynamicSupervisor active children (live games)
#
# Usage: sample-beam.sh [-i interval_secs] [-c container] [-o out.csv]
set -uo pipefail

INTERVAL=2
CONTAINER="tttoe-api-app-1"
OUT=""

while getopts "i:c:o:" opt; do
  case "$opt" in
    i) INTERVAL="$OPTARG" ;;
    c) CONTAINER="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    *) echo "usage: $0 [-i interval] [-c container] [-o out.csv]" >&2; exit 2 ;;
  esac
done

BIN="/app/bin/tictactoe"

# VM-wide stats (159 bytes).
EXPR_VM='Enum.join([:erlang.system_info(:process_count),div(:erlang.memory(:total),1048576),div(:erlang.memory(:processes),1048576),:erlang.statistics(:run_queue)],",")'
# App-specific: two mailbox lengths + active game count (209 bytes).
EXPR_APP='s=Tictactoe.GameSupervisor;q=fn n->case Process.whereis(n) do nil->-1;p->elem(Process.info(p,:message_queue_len),1) end end;Enum.join([q.(s),q.(Tictactoe.Rooms),DynamicSupervisor.count_children(s).active],",")'

HEADER="ts,process_count,mem_total_mb,mem_proc_mb,run_queue,gsup_mbox,rooms_mbox,active_games"

rpc() {
  # Runs an expression, strips the surrounding quotes and CR/whitespace from the
  # returned string literal. Emits nothing on failure.
  docker exec "$CONTAINER" "$BIN" rpc "$1" 2>/dev/null | tr -d '"\r' | tr -d '[:space:]'
}

echo "$HEADER"
[ -n "$OUT" ] && echo "$HEADER" > "$OUT"

running=1
trap 'running=0' INT TERM

while [ "$running" -eq 1 ]; do
  ts=$(date +%s)
  vm=$(rpc "$EXPR_VM")
  app=$(rpc "$EXPR_APP")
  [ -z "$vm" ] && vm="-1,-1,-1,-1"
  [ -z "$app" ] && app="-1,-1,-1"
  row="${ts},${vm},${app}"
  echo "$row"
  [ -n "$OUT" ] && echo "$row" >> "$OUT"
  # rpc itself costs ~1.4s/sample; sleep the remainder of the interval.
  sleep "$INTERVAL"
done

echo "sampler stopped" >&2
