#!/usr/bin/env python3
"""Monitor NeoAnt GitHub Actions builds (v2)"""
import urllib.request, json, time, sys

TOKEN=*** + "gVLUdyViusIsYMm2a90HYmrMhhK117Ez8"
BASE = "https://api.github.com/repos/zhaocaimao008/neo-ant"
RUN_NAMES = {"Build All", "Build iOS IPA", "Build Windows EXE"}

def api(path):
    req = urllib.request.Request(f"{BASE}{path}",
        headers={"Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github.v3+json"})
    return json.loads(urllib.request.urlopen(req).read())

print("📡 Monitoring NeoAnt CI builds...\n", flush=True)

for attempt in range(40):
    time.sleep(30)
    runs = api("/actions/runs?per_page=5")
    
    active = [r for r in runs['workflow_runs'] if r['status'] != 'completed']
    completed = [r for r in runs['workflow_runs'] if r['status'] == 'completed']
    
    # Show active
    for r in active:
        elapsed = (time.time() - time.mktime(time.strptime(r['created_at'][:19], '%Y-%m-%dT%H:%M:%S'))) / 60
        print(f"  ⏳ {r['name'][:20]:20s} {r['status']:10s} ({elapsed:.0f}min)", flush=True)
    
    # Show completed
    for r in completed[:3]:
        icon = '✅' if r['conclusion'] == 'success' else '❌'
        print(f"  {icon} {r['name'][:20]:20s} {r['conclusion']:10s}", flush=True)
    
    print(flush=True)
    
    if not active:
        print("🎉 All builds finished!\n", flush=True)
        for r in completed[:3]:
            if r['conclusion'] == 'success':
                arts = api(f"/actions/runs/{r['id']}/artifacts")
                print(f"📦 {r['name']}:")
                print(f"   {r['html_url']}")
                for art in arts.get('artifacts', []):
                    size = art['size_in_bytes'] / 1024 / 1024
                    print(f"   📎 {art['name']} ({size:.1f}MB)")
                    print(f"   https://github.com/zhaocaimao008/neo-ant/actions/runs/{r['id']}/artifacts/{art['id']}")
        sys.exit(0)

print("⏰ Timed out")
