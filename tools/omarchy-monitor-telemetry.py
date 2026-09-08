#!/usr/bin/env python3
import datetime as dt
import hashlib
import json
import os
import subprocess
import time
from pathlib import Path

BASE = Path.home() / ".local/state/omarchy/monitor-telemetry"
BASE.mkdir(parents=True, exist_ok=True)
os.umask(0o077)
seen_kernel = set()
previous_signature = None

def hypr_env():
    env = os.environ.copy()
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        root = Path("/run/user") / str(os.getuid()) / "hypr"
        sockets = sorted(root.glob("*/.socket.sock"))
        if sockets:
            env["HYPRLAND_INSTANCE_SIGNATURE"] = sockets[0].parent.name
    return env

def run(args, timeout=4):
    try:
        p = subprocess.run(args, env=hypr_env(), text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        return p.stdout.strip()
    except Exception as e:
        return "ERROR:" + type(e).__name__

def monitors():
    raw = run(["hyprctl", "monitors", "-j"])
    try:
        data = json.loads(raw)
        result = []
        for m in data:
            result.append({
                "name": m.get("name"),
                "width": m.get("width"),
                "height": m.get("height"),
                "refresh_hz": m.get("refreshRate"),
                "scale": m.get("scale"),
                "format": m.get("currentFormat"),
                "color_preset": m.get("colorManagementPreset"),
                "vrr": m.get("vrr"),
                "disabled": m.get("disabled"),
                "dpms": m.get("dpmsStatus"),
                "x": m.get("x"),
                "y": m.get("y"),
            })
        return result
    except Exception:
        return [{"raw": raw[:1000]}]

def connector_status():
    result = {}
    for p in sorted(Path("/sys/class/drm").glob("*-DP-1/status")):
        try:
            result[str(p)] = p.read_text().strip()
        except Exception as e:
            result[str(p)] = "ERROR:" + type(e).__name__
    return result

def edid_hash():
    result = {}
    for p in sorted(Path("/sys/class/drm").glob("*-DP-1/edid")):
        try:
            b = p.read_bytes()
            result[str(p)] = hashlib.sha256(b).hexdigest() if b else "empty"
        except Exception as e:
            result[str(p)] = "ERROR:" + type(e).__name__
    return result

def idle_state():
    path = Path.home() / ".local/state/omarchy/indicators/stay-awake"
    return {"stay_awake_file": path.exists()}

def lid_state():
    states = []
    for p in sorted(Path("/proc/acpi/button/lid").glob("*/state")):
        try:
            states.append(p.read_text().strip())
        except Exception:
            pass
    return states

def usb_hub_snapshot():
    result = []
    for p in sorted(Path("/sys/bus/usb/devices").glob("*/idVendor")):
        try:
            if p.read_text().strip().lower() != "2109":
                continue
            root = p.parent
            def read(name):
                q = root / name
                try:
                    return q.read_text().strip()
                except Exception:
                    return None
            result.append({
                "device": root.name,
                "vendor": read("idVendor"),
                "product_id": read("idProduct"),
                "product": read("product"),
                "manufacturer": read("manufacturer"),
                "speed": read("speed"),
            })
        except Exception:
            pass
    return result

def kernel_events():
    since = (dt.datetime.now() - dt.timedelta(seconds=8)).isoformat(timespec="seconds")
    raw = run(["journalctl", "-k", "--since", since, "--no-pager", "-o", "short-iso"], timeout=5)
    events = []
    for line in raw.splitlines():
        low = line.lower()
        if not any(x in low for x in ("amdgpu", "drm", "dp-1", "typec", "usb")):
            continue
        key = hashlib.sha256(line.encode(errors="replace")).hexdigest()
        if key in seen_kernel:
            continue
        seen_kernel.add(key)
        if len(seen_kernel) > 2000:
            seen_kernel.clear()
        events.append(line)
    return events

def config_errors():
    raw = run(["hyprctl", "configerrors"])
    return raw[-2000:] if raw else ""

def write(entry):
    now = dt.datetime.now().astimezone()
    path = BASE / ("telemetry-" + now.strftime("%Y-%m-%d") + ".jsonl")
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")

while True:
    now = dt.datetime.now().astimezone()
    mons = monitors()
    status = connector_status()
    edid = edid_hash()
    signature = json.dumps({
        "monitors": mons,
        "connector": status,
        "edid": edid,
        "lid": lid_state(),
    }, sort_keys=True, ensure_ascii=False)
    entry = {
        "time": now.isoformat(),
        "type": "sample",
        "lid": lid_state(),
        "idle": idle_state(),
        "connector": status,
        "edid_sha256": edid,
        "monitors": mons,
        "usb_via_2109": usb_hub_snapshot(),
        "hypr_config_errors": config_errors(),
        "kernel_events": kernel_events(),
    }
    if previous_signature is not None and signature != previous_signature:
        entry["type"] = "change"
        entry["previous_signature_sha256"] = hashlib.sha256(previous_signature.encode()).hexdigest()
    previous_signature = signature
    write(entry)
    time.sleep(5)
