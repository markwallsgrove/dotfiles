#!/usr/bin/env bash
# Consolidated PR-merge watcher for a fleet of herdr agents.
#
# Usage:  pr-watch.sh <label>=<branch> [<label>=<branch> ...]
#   e.g.  pr-watch.sh ACC-15=mark/acc-15 ACC-19=mark/acc-19 ACC-24=mark/acc-24
#
# Run it as the command of a SECOND persistent Monitor, alongside
# fleet-watch.sh. Each line it prints becomes a coordinator notification. It
# polls GitHub (via `gh`) every $INTERVAL seconds (default 300 = 5 min) and
# emits:
#   - one line the moment a branch's PR transitions INTO `merged` (the edge)
#   - a "STILL merged" re-nudge every $STALE seconds (default 900) so a merge
#     edge that wasn't acted on never sits silently.
#
# Trigger is MERGED-only: a closed-without-merge PR is left alone (it may be
# reopened). The watcher only EMITS — it never closes workspaces, removes
# worktrees, or deletes branches. Teardown is the coordinator's job, and only
# after confirming the branch has no unpushed/uncommitted work.
#
# Reliability: any gh error / empty / unparseable output is treated as `unknown`
# and can NEVER emit a merged event or advance state, so a transient failure
# cannot cause a false teardown; a real merge still edge-triggers on a later
# successful poll. The slow re-nudge backstops a missed edge.
#
# Requires bash 4+ (associative arrays) -- invoke via `env bash` on macOS.
set -uo pipefail
declare -A BRANCH prev last_emit
LABELS=()
for arg in "$@"; do
	label="${arg%%=*}"
	branch="${arg#*=}"
	if [ -z "$label" ] || [ -z "$branch" ] || [ "$label" = "$branch" ]; then
		echo "usage: pr-watch.sh <label>=<branch> [<label>=<branch> ...]"
		exit 1
	fi
	BRANCH[$label]="$branch"
	prev[$label]=start
	last_emit[$label]=0
	LABELS+=("$label")
done
[ ${#LABELS[@]} -eq 0 ] && {
	echo "usage: pr-watch.sh <label>=<branch> [<label>=<branch> ...]"
	exit 1
}
INTERVAL=${INTERVAL:-300}
STALE=${STALE:-900}
while true; do
	now=$(date +%s)
	for label in "${LABELS[@]}"; do
		br="${BRANCH[$label]}"
		# `gh pr list --head` returns [] (not an error) when no PR exists yet,
		# and a non-zero exit / empty output on any real failure. Both stdout
		# cases are parsed below; the failure case falls through to `unknown`.
		line=$(gh pr list --head "$br" --state all \
			--json number,state,url --limit 1 2>/dev/null |
			python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('unknown'); sys.exit()
if not d:
    print('none'); sys.exit()
pr = d[0]
print(pr.get('state', '?').lower(), pr.get('number', '?'), pr.get('url', ''))
" 2>/dev/null)
		[ -z "$line" ] && line="unknown"
		status="${line%% *}"
		rest="${line#* }"
		num="${rest%% *}"
		url="${rest#* }"
		# `unknown` never emits and never advances state, so the next good poll
		# still sees the merge as a fresh edge.
		[ "$status" = "unknown" ] && continue
		if [ "$status" = "merged" ]; then
			if [ "${prev[$label]}" != "merged" ]; then
				echo "$(date +%H:%M:%S) $label $br PR #$num -> merged — confirm & tear down ($url)"
				last_emit[$label]=$now
			elif [ $((now - ${last_emit[$label]})) -ge "$STALE" ]; then
				echo "$(date +%H:%M:%S) $label $br PR #$num STILL merged — needs teardown ($url)"
				last_emit[$label]=$now
			fi
		fi
		prev[$label]="$status"
	done
	sleep "$INTERVAL"
done
