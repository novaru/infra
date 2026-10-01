# CrowdSec host configs (source of truth)

These files deploy the host-level CrowdSec setup. The monitoring stack
(`../monitoring`) only scrapes the metrics; the configs here define them.

| File | Deploys to | Notes |
|---|---|---|
| `config.yaml` | `/etc/crowdsec/config.yaml` | Prometheus on `0.0.0.0:6060` so Docker Prometheus can scrape via `host.docker.internal`. Was `127.0.0.1` (scrape `connection refused`, empty Grafana panels). |
| `crowdsec-firewall-bouncer.yaml.template` | `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` | nftables mode, Prometheus on `0.0.0.0:60601`. API key injected at deploy time, never stored in git. |

## Deploy

```bash
export CROWDSEC_BOUNCER_KEY="$(sudo cscli bouncers list -o json | jq -r '.[0].api_key')"
# if the key is lost: sudo cscli bouncers delete <name> && sudo cscli bouncers add <name>
sudo -E ./deploy.sh
```

The script validates both configs (`-t`), restarts the services, and checks
the `:6060` / `:60601` metrics endpoints.

## Out of scope (intentionally not versioned)

- Bouncer API keys and LAPI credentials (`*.local`, `*_credentials.yaml`) - secrets, host-only.
- fail2ban runs stock `jail.conf` defaults (no `jail.local`) - nothing to version.
- `/var/lib/crowdsec` decisions DB and community blocklist - runtime state, covered by backups not git.
