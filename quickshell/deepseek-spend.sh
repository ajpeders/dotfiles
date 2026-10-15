#!/usr/bin/env bash
# Read only connection status and aggregate costs; never expose OpenCode credentials.
connection=$(timeout 20s opencode api get /api/integration/deepseek 2>/dev/null) || exit 0
printf '%s' "$connection" | python -c 'import json,sys; x=json.load(sys.stdin); sys.exit(0 if x.get("data", {}).get("connections") else 1)' || exit 0
stats=$(timeout 20s opencode api get /api/experimental/session/stats 2>/dev/null) || exit 0
printf '%s' "$stats" | python -c '
import json, sys
data = json.load(sys.stdin).get("data", {})
cost = sum(float(item.get("cost") or 0) for item in data.get("models", [])
           if item.get("model", {}).get("providerID") == "deepseek")
print("${:.2f}".format(cost))
'
