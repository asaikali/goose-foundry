#!/bin/bash
set -euo pipefail

# Simple integration test for goosed on Cloud Foundry.
# Usage: ./test.sh "optional message"
#
# If GOOSED_URL is not set, this script will derive it from the goosed
# manifest and the currently deployed CF app (via `cf app`).

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found in PATH"
  exit 1
fi

MANIFEST_PATH="${GOOSED_MANIFEST:-apps/goosed/manifest.yml}"

if [ -z "${GOOSED_URL:-}" ]; then
  if ! command -v cf >/dev/null 2>&1; then
    echo "Error: cf CLI not found in PATH"
    exit 1
  fi
  if [ ! -f "$MANIFEST_PATH" ]; then
    echo "Error: $MANIFEST_PATH not found"
    exit 1
  fi

  APP_NAME="${GOOSED_APP_NAME:-$(awk '/- name:/{print $3; exit}' "$MANIFEST_PATH" | tr -d '\"')}"
  if [ -z "$APP_NAME" ]; then
    echo "Error: Could not determine app name from $MANIFEST_PATH"
    exit 1
  fi

  ROUTE="$(cf app "$APP_NAME" | awk '
    /^routes:/ {
      sub(/^routes:[[:space:]]*/, "", $0);
      if (length($0)) { print $0; exit }
      inroutes=1; next
    }
    inroutes && NF>0 { print $0; exit }
  ' | head -n 1)"

  ROUTE="${ROUTE%%,*}"
  ROUTE="$(echo "$ROUTE" | xargs)"

  if [ -z "$ROUTE" ]; then
    echo "Error: Could not determine route for app $APP_NAME"
    echo "Set GOOSED_URL or GOOSED_APP_NAME explicitly."
    exit 1
  fi

  GOOSED_URL="https://$ROUTE"
fi

SECRET_KEY="${GOOSED_SECRET_KEY:-change-me-to-a-real-secret}"
PROVIDER="${GOOSE_PROVIDER:-openai}"
MODEL="${GOOSE_MODEL:-gpt-4o}"
MESSAGE="${1:-Hello, what can you do?}"

echo "Using GOOSED_URL=$GOOSED_URL"

echo "=== Checking status ==="
echo "+ curl -s $GOOSED_URL/status"
curl -s "$GOOSED_URL/status"
echo ""

echo ""
echo "=== Starting agent ==="
echo "+ curl -s -X POST $GOOSED_URL/agent/start ..."
START_RESPONSE=$(curl -s -X POST "$GOOSED_URL/agent/start" \
  -H "Content-Type: application/json" \
  -H "X-Secret-Key: $SECRET_KEY" \
  -d '{"working_dir": "/tmp"}')

echo "$START_RESPONSE" | jq .

SESSION_ID=$(echo "$START_RESPONSE" | jq -r '.id')

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
  echo "Error: Failed to extract session ID"
  exit 1
fi

echo ""
echo "=== Setting provider: $PROVIDER / $MODEL ==="
PROVIDER_BODY=$(cat <<EOF
{
  "provider": "$PROVIDER",
  "model": "$MODEL",
  "session_id": "$SESSION_ID"
}
EOF
)
echo "+ curl -s -X POST $GOOSED_URL/agent/update_provider -d '$PROVIDER_BODY'"
PROVIDER_RESPONSE=$(curl -s -w "\n--- HTTP %{http_code} ---" -X POST "$GOOSED_URL/agent/update_provider" \
  -H "Content-Type: application/json" \
  -H "X-Secret-Key: $SECRET_KEY" \
  -d "$PROVIDER_BODY")
echo "$PROVIDER_RESPONSE"

REPLY_BODY=$(cat <<EOF
{
  "session_id": "$SESSION_ID",
  "user_message": {
    "role": "user",
    "created": 0,
    "content": [{"type": "text", "text": "$MESSAGE"}],
    "metadata": {"userVisible": true, "agentVisible": true}
  }
}
EOF
)

echo ""
echo "=== Session ID: $SESSION_ID ==="
echo "=== Sending message: $MESSAGE ==="
echo "+ curl -N -s -X POST $GOOSED_URL/reply ..."
echo ""

echo "--- Raw response ---"
RAW=$(curl -N -s -w "\n--- HTTP %{http_code} ---" -X POST "$GOOSED_URL/reply" \
  -H "Content-Type: application/json" \
  -H "X-Secret-Key: $SECRET_KEY" \
  -d "$REPLY_BODY")

echo "$RAW"
echo ""
echo "--- Parsed SSE events ---"
echo "$RAW" | while IFS= read -r line; do
  if [[ "$line" == data:* ]]; then
    echo "${line#data: }" | jq . 2>/dev/null || echo "$line"
  fi
done

echo ""
echo "=== Stopping agent ==="
echo "+ curl -s -X POST $GOOSED_URL/agent/stop ..."
curl -s -X POST "$GOOSED_URL/agent/stop" \
  -H "Content-Type: application/json" \
  -H "X-Secret-Key: $SECRET_KEY" \
  -d "{\"session_id\": \"$SESSION_ID\"}" | jq . 2>/dev/null

echo "Done."
