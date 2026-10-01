# Maintenance scripts

Read-only helpers. Nothing here writes to the host - except `deploy.sh`
under `services/crowdsec/`, which is the one explicit deploy path.

## Scripts

- `crowdsec-loki-check.py` - validates the host-log LogQL queries behind the
  CrowdSec Grafana dashboards against Loki. Exit 0 + series output means the
  pipeline (crowdsec.log -> promtail -> Loki -> dashboard queries) is healthy.
  Non-zero usually means "no bans in window" (idle), not breakage - check
  `cscli alerts list` to tell the difference.
- `export-dashboards.py` - dumps Grafana dashboards from the live SQLite DB
  to provisioning JSON (strips internal `id`, keeps `uid`). Used to refresh
  `services/monitoring/grafana/provisioning/dashboards/` after intentional
  UI changes (note: provisioned dashboards have `allowUiUpdates: false`, so
  the normal flow is edit the JSON, not the UI).

## History (2026-10-01 session, for context)

Grafana showed "No data" for CrowdSec. Causes found and fixed:

1. Prometheus `crowdsec` target DOWN - CrowdSec bound `:6060` to `127.0.0.1`,
   unreachable from Docker. Fixed in `services/crowdsec/config.yaml`
   (`listen_addr: 0.0.0.0`).
2. No firewall bouncer existed (`cscli bouncers list` empty) - installed
   `crowdsec-firewall-bouncer`, nftables mode, metrics on `:60601`, scrape job
   in `prometheus.yml`. Template + `deploy.sh` under `services/crowdsec/`.
3. Dashboards assumed a Docker CrowdSec (`{container="crowdsec-lapi"}`) plus
   metrics this setup never exposes (`cs_appsec_*`, `cs_lapi_bouncer_*`,
   `fw_bouncer_processed_packets`). Rewrote to host logs (`{job="crowdsec"}`)
   and live metrics (`cs_active_decisions`, `cs_node_hits_ko_total`, ...).
   The one-off DB patch is superseded by the provisioned JSON files - do not
   re-run ad-hoc DB edits; edit the JSON and let provisioning apply it.
