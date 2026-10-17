#!/usr/bin/env bash
# Print the DeepSeek account balance using the key OpenCode stores; never print the key itself.
auth="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json"
[ -r "$auth" ] || exit 0
python -I - "$auth" <<'PY' 2>/dev/null || exit 0
import json, sys, urllib.request
key = json.load(open(sys.argv[1]))["deepseek"]["key"]
req = urllib.request.Request("https://api.deepseek.com/user/balance",
                             headers={"Authorization": "Bearer " + key, "Accept": "application/json"})
info = json.load(urllib.request.urlopen(req, timeout=20))["balance_infos"]
usd = next(i for i in info if i["currency"] == "USD")
print("${:.2f}".format(float(usd["total_balance"])))
PY
