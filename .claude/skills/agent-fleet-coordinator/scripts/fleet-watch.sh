#!/usr/bin/env bash
# Consolidated low-latency watcher for a fleet of herdr agents.
#
# Usage:  fleet-watch.sh <pane_id>=<label> [<pane_id>=<label> ...]
#   e.g.  fleet-watch.sh wH:p1=ACC-15 wM:p1=ACC-19 wR:p1=ACC-24
#
# Run it as the command of a persistent Monitor. Each line it prints becomes a
# coordinator notification. It emits:
#   - one line the moment a pane transitions INTO `blocked` or `done` (the edge)
#   - a "STILL blocked" re-nudge every $STALE seconds (default 60) so a missed
#     edge (a rapid clear->re-block between polls) or a block you overlooked
#     never sits silently.
#
# Why both: a pure edge trigger can miss a fast clear->re-block that happens
# between polls; a pure level trigger spams every poll. Edge + slow re-nudge
# gives ~1s latency on fresh blocks and a bounded backstop on missed ones.
# Requires bash 4+ (associative arrays) -- invoke via `env bash` on macOS.
set -uo pipefail
declare -A LBL prev last_emit
PANES=()
for arg in "$@"; do
	pane="${arg%%=*}"
	label="${arg#*=}"
	LBL[$pane]="$label"
	prev[$pane]=working
	last_emit[$pane]=0
	PANES+=("$pane")
done
[ ${#PANES[@]} -eq 0 ] && {
	echo "usage: fleet-watch.sh pane=label [pane=label ...]"
	exit 1
}
STALE=${STALE:-60}
PY_PANES=$(printf '"%s",' "${PANES[@]}")
while true; do
	snap=$(herdr agent list 2>/dev/null | python3 -c "
import sys,json
try: ags={a['pane_id']:a['agent_status'] for a in json.load(sys.stdin)['result']['agents']}
except Exception: ags={}
for p in [${PY_PANES%,}]: print(p, ags.get(p,'unknown'))
" 2>/dev/null)
	[ -z "$snap" ] && {
		sleep 1
		continue
	}
	now=$(date +%s)
	while read -r pane status; do
		[ -z "${pane:-}" ] && continue
		lbl="${LBL[$pane]:-$pane}"
		if [ "$status" = "blocked" ] || [ "$status" = "done" ]; then
			if [ "${prev[$pane]}" != "$status" ]; then
				echo "$(date +%H:%M:%S) $lbl $pane -> $status"
				last_emit[$pane]=$now
			elif [ "$status" = "blocked" ] && [ $((now - ${last_emit[$pane]})) -ge "$STALE" ]; then
				echo "$(date +%H:%M:%S) $lbl $pane STILL blocked — needs clearing"
				last_emit[$pane]=$now
			fi
		fi
		prev[$pane]="$status"
	done <<<"$snap"
	sleep 1
done
