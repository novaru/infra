import sqlite3, json, sys, os
# Usage: export_dash.py <grafana.db> <out_dir>
# Exports patched dashboards as provisioning JSON (strips internal id).
DB, OUT = sys.argv[1], sys.argv[2]
UIDS = {"ceuwj6n4mjmrkf": "crowdsec-monitoring.json",
        "crowdsec-fw-bouncer": "crowdsec-firewall-bouncer.json"}
con = sqlite3.connect(DB)
for uid, fname in UIDS.items():
    row = con.execute("SELECT title, data FROM dashboard WHERE uid=?", (uid,)).fetchone()
    if not row:
        print("MISSING:", uid)
        continue
    d = json.loads(row[1])
    d.pop("id", None)
    path = os.path.join(OUT, fname)
    with open(path, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    print("EXPORTED:", row[0], "->", path)
