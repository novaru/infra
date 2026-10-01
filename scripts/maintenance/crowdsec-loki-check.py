"""Validate the CrowdSec host-log LogQL queries used by the Grafana dashboards.
Runs read-only queries against Loki (default http://127.0.0.1:3100).

Usage: python3 crowdsec-loki-check.py [--loki URL] [--hours 24]
Exit 0 if ban lines are found and scenario/IP extraction yields series.
"""
import argparse
import json
import sys
import time
import urllib.parse
import urllib.request

BAN_LIST = '{job="crowdsec"} |~ "ban on Ip"'


def instant_query(hours):
    return ('sum by (scenario, ip) (count_over_time({job="crowdsec"} |~ "ban on Ip" '
            '| regexp `(?P<scenario>\\S+) by ip (?P<source_ip>\\S+)` '
            '| label_format scenario="{{.scenario}}", ip="{{.source_ip}}" '
            f'[{hours}h]))')


def loki(loki_base, path, expr, hours):
    now = int(time.time())
    qs = urllib.parse.urlencode({
        "query": expr, "limit": 5,
        "start": str((now - hours * 3600) * 1000000000),
        "end": str(now * 1000000000),
    })
    url = loki_base.rstrip("/") + "/loki/api/v1/" + path + "?" + qs
    with urllib.request.urlopen(url, timeout=15) as r:
        return json.loads(r.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loki", default="http://127.0.0.1:3100")
    ap.add_argument("--hours", type=int, default=24)
    args = ap.parse_args()

    r1 = loki(args.loki, "query_range", BAN_LIST, args.hours)
    entries = sum(len(s.get("values", [])) for s in r1["data"]["result"])
    print(f"ban lines in last {args.hours}h: {entries}")

    r2 = loki(args.loki, "query", instant_query(args.hours), args.hours)
    series = r2["data"]["result"]
    print(f"scenario/ip series: {len(series)}")
    for item in series[:10]:
        print("  ", item.get("metric"), "->", item.get("value", [None, None])[1])

    if entries == 0 or not series:
        print("WARN: no CrowdSec ban data in window "
              "(idle host, or promtail/Loki pipeline broken - check both)")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
