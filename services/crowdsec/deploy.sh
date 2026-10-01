#!/usr/bin/env bash
# Deploy CrowdSec host configs from this repo onto the host.
# Run ON the host with sudo:  sudo -E ./deploy.sh
# Requires env var CROWDSEC_BOUNCER_KEY (the bouncer API key).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${CROWDSEC_BOUNCER_KEY:?Set CROWDSEC_BOUNCER_KEY first. Get the current key with: sudo cscli bouncers list (re-add with 'sudo cscli bouncers add <name>' if lost)}"

echo "==> Installing /etc/crowdsec/config.yaml"
cp "$SRC/config.yaml" /etc/crowdsec/config.yaml

echo "==> Installing bouncer config (key injected, mode 600)"
sed "s|\${CROWDSEC_BOUNCER_KEY}|$CROWDSEC_BOUNCER_KEY|g" \
  "$SRC/crowdsec-firewall-bouncer.yaml.template" \
  > /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
chmod 600 /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml

echo "==> Validating configs"
crowdsec -c /etc/crowdsec/config.yaml -t
crowdsec-firewall-bouncer -c /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml -t

echo "==> Restarting services"
systemctl restart crowdsec crowdsec-firewall-bouncer
sleep 3
systemctl is-active crowdsec crowdsec-firewall-bouncer

echo "==> Verifying"
cscli bouncers list
curl -sf http://127.0.0.1:6060/metrics -o /dev/null && echo "crowdsec metrics OK (:6060)"
curl -sf http://127.0.0.1:60601/metrics -o /dev/null && echo "bouncer metrics OK (:60601)"
echo "DEPLOY OK"
