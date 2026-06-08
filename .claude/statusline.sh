#!/usr/bin/env bash
set -euo pipefail

DATA=$(cat)

# Git branch
BRANCH=$(git -C "$(echo "$DATA" | jq -r '.cwd')" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

# Context window
CTX_PCT=$(echo "$DATA" | jq -r '.context_window.used_percentage // 0')
CTX_INT=${CTX_PCT%.*}
if [ "$CTX_INT" -ge 90 ] 2>/dev/null; then
  CTX_COLOR="\033[31m"
elif [ "$CTX_INT" -ge 70 ] 2>/dev/null; then
  CTX_COLOR="\033[33m"
else
  CTX_COLOR="\033[32m"
fi

# Cost
COST=$(echo "$DATA" | jq -r '.cost.total_cost_usd // 0')

# Lines changed
ADDED=$(echo "$DATA" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$DATA" | jq -r '.cost.total_lines_removed // 0')

# Time
TIME=$(date +%H:%M)

# Rate limits
FIVE_HR=$(echo "$DATA" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null || true)
SEVEN_DAY=$(echo "$DATA" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null || true)

RATE=""
if [ -n "$FIVE_HR" ]; then
  RATE=" │ 5h:${FIVE_HR}%"
fi
if [ -n "$SEVEN_DAY" ]; then
  RATE="${RATE} 7d:${SEVEN_DAY}%"
fi

RST="\033[0m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
RED="\033[31m"

printf "${CYAN} ${BRANCH}${RST} │ ${CTX_COLOR}ctx:${CTX_PCT}%%${RST} │ \$${COST}${RATE} │ ${GREEN}+${ADDED}${RST}/${RED}-${REMOVED}${RST} │ ${DIM}${TIME}${RST}\n"
