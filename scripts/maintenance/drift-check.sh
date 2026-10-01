#!/usr/bin/env bash
# Read-only drift report: live host state vs the ~/infra repo.
# This script NEVER writes, commits, pushes, or restarts anything.
# Exit 0 = no drift, 1 = drift detected (systemd-timer friendly).
set -u

REPO="$HOME/infra"
drift=0

flag() { drift=1; printf 'DRIFT: %s\n' "$*"; }
ok()   { printf 'OK: %s\n' "$*"; }

[ -d "$REPO/.git" ] || { echo "repo missing at $REPO"; exit 2; }
cd "$REPO" || exit 2

# 1. Uncommitted repo changes
if [ -n "$(git status --porcelain)" ]; then
  flag "uncommitted changes in repo:"
  git status --short
else
  ok "git tree clean"
fi

# 2. CrowdSec main config
if diff -q /etc/crowdsec/config.yaml "$REPO/services/crowdsec/config.yaml" >/dev/null 2>&1; then
  ok "crowdsec config.yaml matches repo"
else
  flag "/etc/crowdsec/config.yaml differs from repo (run diff, then deploy.sh or commit)"
fi

# 3. Bouncer config (ignoring the secret api_key line)
if diff <(grep -v '^api_key:' /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml 2>/dev/null) \
        <(grep -v '^api_key:' "$REPO/services/crowdsec/crowdsec-firewall-bouncer.yaml.template") \
        >/dev/null 2>&1; then
  ok "bouncer yaml matches repo template"
else
  flag "bouncer yaml differs from repo template"
fi

# 4. Services alive
for svc in crowdsec crowdsec-firewall-bouncer fail2ban; do
  if [ "$(systemctl is-active "$svc" 2>/dev/null)" = "active" ]; then
    ok "$svc active"
  else
    flag "$svc not active"
  fi
done

# 5. Prometheus scrape targets for crowdsec jobs
targets="$(curl -s --max-time 10 http://127.0.0.1:9090/api/v1/targets 2>/dev/null || true)"
if [ -z "$targets" ]; then
  flag "prometheus unreachable at 127.0.0.1:9090"
else
  for job in crowdsec crowdsec-bouncer; do
    health="$(printf '%s' "$targets" | python3 -c "
import json,sys
d = json.load(sys.stdin)
m = [t['health'] for t in d['data']['activeTargets'] if t['scrapePool']=='$job']
print(m[0] if m else 'missing')")"
    if [ "$health" = "up" ]; then
      ok "prometheus target $job up"
    else
      flag "prometheus target $job is '$health'"
    fi
  done
fi

if [ "$drift" -eq 0 ]; then
  echo "DRIFT-CHECK CLEAN"
else
  echo "DRIFT-CHECK FOUND ISSUES (see DRIFT lines above)"
fi
exit "$drift"
