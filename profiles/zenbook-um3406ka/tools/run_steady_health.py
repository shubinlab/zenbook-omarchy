#!/usr/bin/env python3
from __future__ import annotations
import datetime as dt
import json
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "runs" / (dt.date.today().isoformat() + "-steady-health.json")


def run(args, timeout=8):
    env = os.environ.copy()
    p = subprocess.run(args, env=env, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    return p.stdout.strip()


def monitor():
    mons = json.loads(run(["hyprctl", "monitors", "-j"]))
    m = next(x for x in mons if x.get("name") == "DP-1")
    return {k: m.get(k) for k in ("width", "height", "refreshRate", "scale",
                                  "currentFormat", "colorManagementPreset",
                                  "dpmsStatus", "vrr", "disabled")}


def drm_vrr():
    raw = run(["modetest", "-M", "amdgpu", "-p"])
    return [int(x) for x in re.findall(
        r"VRR_ENABLED:.*?\n(?:.*\n){0,3}?\s+value:\s+(\d+)", raw
    )]


def session():
    raw = run(["loginctl", "show-session", os.environ.get("XDG_SESSION_ID", "1"),
               "-p", "State", "-p", "IdleHint", "-p", "LockedHint"])
    return dict(line.split("=", 1) for line in raw.splitlines() if "=" in line)


def usb_hubs():
    out = []
    for p in sorted(Path("/sys/bus/usb/devices").glob("*/idVendor")):
        root = p.parent
        try:
            if p.read_text().strip() != "2109":
                continue
            def read(name):
                try: return (root / name).read_text().strip()
                except Exception: return None
            out.append({"device": root.name, "product_id": read("idProduct"),
                        "product": read("product"), "speed": read("speed")})
        except Exception:
            continue
    return out


def net_stats():
    p = Path("/sys/class/net/enp101s0f3u1u4/statistics")
    out = {}
    for name in ("rx_bytes", "tx_bytes", "rx_errors", "tx_errors", "rx_dropped", "tx_dropped"):
        try: out[name] = int((p / name).read_text())
        except Exception: out[name] = None
    return out


def sample():
    return {"time": dt.datetime.now().astimezone().isoformat(),
            "monitor": monitor(), "drm_vrr_enabled": drm_vrr(),
            "connector": Path("/sys/class/drm/card1-DP-1/status").read_text().strip(),
            "session": session(), "usb_hubs": usb_hubs(), "network": net_stats()}


def main():
    started = dt.datetime.now().astimezone()
    rows = []
    for _ in range(30):
        rows.append(sample())
        time.sleep(2)
    result = {"started": started.isoformat(), "ended": dt.datetime.now().astimezone().isoformat(),
              "sample_count": len(rows), "samples": rows}
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    stable = all(r["monitor"]["dpmsStatus"] is True and r["monitor"]["vrr"] is True
                  and r["monitor"]["disabled"] is False and r["connector"] == "connected"
                  and r["session"].get("IdleHint") == "no"
                  and r["session"].get("LockedHint") == "no"
                  for r in rows)
    lines = [f"# Steady-state health — {started.date().isoformat()}", "",
             f"Duration: 60 seconds; samples: {len(rows)}.", "",
             f"- Stable monitor/session/connector result: **{stable}**",
             f"- Modes observed: {sorted({(r['monitor']['width'], r['monitor']['height'], r['monitor']['refreshRate']) for r in rows})}",
             f"- Formats: {sorted({r['monitor']['currentFormat'] for r in rows})}",
             f"- Hyprland VRR: {sorted({r['monitor']['vrr'] for r in rows})}",
             f"- DRM VRR values: {sorted({v for r in rows for v in r['drm_vrr_enabled']})}",
             f"- DPMS values: {sorted({r['monitor']['dpmsStatus'] for r in rows})}",
             f"- Connector values: {sorted({r['connector'] for r in rows})}",
             f"- Session IdleHint: {sorted({r['session'].get('IdleHint') for r in rows})}",
             f"- Session LockedHint: {sorted({r['session'].get('LockedHint') for r in rows})}",
             "- The raw JSON contains only selected fields and no monitor serial, EDID hash or kernel log lines.", ""]
    OUT.with_suffix(".md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"json": str(OUT), "markdown": str(OUT.with_suffix('.md')), "stable": stable}, ensure_ascii=False))

if __name__ == "__main__":
    main()
