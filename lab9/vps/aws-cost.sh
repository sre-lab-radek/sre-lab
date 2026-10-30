#!/usr/bin/env bash
set -uo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin

LOG="$HOME/aws-cost.log"
THRESHOLD="${THRESHOLD:-1.0}"   # USD na dzien, mozna nadpisac przy tescie
TOKEN_FILE="$HOME/.secrets/telegram_token"
CHAT_FILE="$HOME/.secrets/telegram_chat_id"
START=$(date -d '-3 days' +%F)
END=$(date -d '+1 day' +%F)
NOW=$(date -u '+%F %T UTC')

notify() {
  local token chat
  token=$(tr -d '\n' < "$TOKEN_FILE") || return 1
  chat=$(tr -d '\n' < "$CHAT_FILE") || return 1
  printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token" |
    curl -s -m 10 -o /dev/null -K - \
      --data-urlencode "chat_id=$chat" --data-urlencode "text=$1"
}

OUT=$(aws ce get-cost-and-usage \
  --time-period Start=$START,End=$END \
  --granularity DAILY --metrics UnblendedCost \
  --filter '{"Not":{"Dimensions":{"Key":"RECORD_TYPE","Values":["Credit","Refund"]}}}' \
  --query 'ResultsByTime[].[TimePeriod.Start,Total.UnblendedCost.Amount]' \
  --output text 2>&1) || { echo "$NOW ERROR: $OUT" >> "$LOG"; exit 1; }

{
  echo "$NOW AWS cost (USD, before credits; last day may be incomplete)"
  echo "$OUT"
} >> "$LOG"

ALERT=$(echo "$OUT" | python3 -c '
import sys
t = float(sys.argv[1])
rows = [l.split() for l in sys.stdin if l.strip()]
print("\n".join(f"{d}: {float(v):.2f} USD" for d, v in rows if float(v) > t))
' "$THRESHOLD")

if [ -n "$ALERT" ]; then
  notify "AWS cost above $THRESHOLD USD/day:
$ALERT" && echo "$NOW ALERT sent" >> "$LOG" || echo "$NOW ALERT FAILED to send" >> "$LOG"
fi
