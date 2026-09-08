#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import json
import os
import re
import signal
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "runs"
STAMP = dt.date.today().isoformat()
OUT = RUNS / f"{STAMP}-component-audit.json"


def cmd(args: list[str], timeout: int = 30) -> dict:
    try:
        p = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        return {"returncode": p.returncode, "output": p.stdout[-4000:]}
    except Exception as exc:
        return {"returncode": None, "output": str(exc)}


def monitor() -> dict:
    r = cmd(["hyprctl", "monitors", "-j"])
    try:
        m = next(x for x in json.loads(r["output"]) if x.get("name") == "DP-1")
        return {k: m.get(k) for k in ("width", "height", "refreshRate", "scale",
                                      "currentFormat", "dpmsStatus", "vrr", "disabled")}
    except Exception:
        return {"error": r["output"][-500:]}


def temps() -> dict:
    r = cmd(["sensors", "-j"])
    try:
        data = json.loads(r["output"])
        out = {}
        for chip, values in data.items():
            for key, fields in values.items():
                if isinstance(fields, dict):
                    for field, value in fields.items():
                        if field.endswith("_input") and isinstance(value, (int, float)):
                            if any(s in key.lower() for s in ("cpu", "tctl", "edge", "composite", "temp")):
                                out[f"{chip}:{key}:{field}"] = value
        return out
    except Exception:
        return {"raw_unparsed": r["output"][-1000:]}


def sample() -> dict:
    return {
        "time": dt.datetime.now().astimezone().isoformat(),
        "monitor": monitor(),
        "temperatures_c": temps(),
        "memory": cmd(["free", "-b"])["output"].splitlines()[-2:],
        "load": Path("/proc/loadavg").read_text().strip(),
        "connector": Path("/sys/class/drm/card1-DP-1/status").read_text().strip(),
    }


def phase(name: str, args: list[str], duration: int, timeout: int) -> dict:
    started = dt.datetime.now().astimezone()
    proc = subprocess.Popen(args, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, start_new_session=True)
    rows = []
    deadline = time.monotonic() + duration
    while proc.poll() is None and time.monotonic() < deadline:
        rows.append(sample())
        time.sleep(2)
    if proc.poll() is None:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=3)
        except Exception:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    try:
        output, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        output, _ = proc.communicate()
        output = (exc.stdout or "") + output
    rows.append(sample())
    return {"name": name, "started": started.isoformat(),
            "ended": dt.datetime.now().astimezone().isoformat(),
            "returncode": proc.returncode, "output": output[-2000:],
            "samples": rows}


def main() -> None:
    started = dt.datetime.now().astimezone()
    phases = []
    phases.append({"name": "baseline", "samples": [sample() for _ in range(3)]})

    if shutil.which("openssl"):
        phases.append(phase("cpu_sha256", ["openssl", "speed", "-seconds", "20",
                                            "-multi", "8", "sha256"], 30, 5))

    memory_code = (
        "import hashlib,time; n=1024*1024*1024; b=bytearray(n); "
        "[b.__setitem__(i,((i//4096)&255)) for i in range(0,n,4096)]; "
        "print(hashlib.sha256(b).hexdigest()); time.sleep(8)"
    )
    phases.append(phase("memory_alloc_hash", ["python3", "-c", memory_code], 25, 10))

    if os.access("/dev/mapper/root", os.R_OK):
        phases.append(phase("nvme_read_only", ["dd", "if=/dev/mapper/root", "of=/dev/null",
                                                "bs=4M", "count=256", "iflag=direct",
                                                "status=none"], 30, 10))
    else:
        phases.append({"name": "nvme_read_only", "skipped": "no read access to mapped root"})

    camera = "/dev/video0" if Path("/dev/video0").exists() else None
    if camera and shutil.which("v4l2-ctl"):
        phases.append({"name": "camera_stream", "result": cmd(
            ["timeout", "15", "v4l2-ctl", "--device", camera, "--stream-mmap",
             "--stream-count=30", "--stream-to=/dev/null"], 20)})
    else:
        phases.append({"name": "camera_stream", "skipped": "camera or v4l2-ctl unavailable"})

    gateway = None
    route = cmd(["ip", "route", "show", "default"])["output"]
    match = re.search(r"default via ([0-9.]+)", route)
    if match:
        gateway = match.group(1)
    phases.append({"name": "ethernet_gateway_ping", "gateway": gateway,
                   "result": cmd(["ping", "-c", "10", "-W", "1", gateway], 20)
                   if gateway else {"skipped": "no default gateway"}})

    kernel = cmd(["journalctl", "-b", "-k", "-p", "0..3",
                  "--no-pager", "-o", "short-iso"], 20)["output"]
    phases.append({"name": "final", "samples": [sample() for _ in range(3)],
                   "kernel_error_line_count": len([x for x in kernel.splitlines() if x.strip()])})

    result = {"started": started.isoformat(), "ended": dt.datetime.now().astimezone().isoformat(),
              "host_scope": "selected non-sensitive health fields",
              "phases": phases}
    RUNS.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = [f"# Component audit — {STAMP}", "",
             "Safe component checks were run under the test wrapper with idle, sleep and lid actions inhibited.", ""]
    for p in phases:
        name = p["name"]
        if "skipped" in p:
            lines.append(f"- **{name}**: skipped — {p['skipped']}")
            continue
        result_obj = p.get("result")
        rc = p.get("returncode", result_obj.get("returncode") if isinstance(result_obj, dict) else None)
        samples = p.get("samples", [])
        lines.append(f"- **{name}**: return code `{rc}`; samples `{len(samples)}`.")
        if name == "ethernet_gateway_ping" and isinstance(result_obj, dict):
            text = result_obj.get("output", "")
            summary = next((x.strip() for x in text.splitlines() if "packet loss" in x), "summary unavailable")
            lines.append(f"  - {summary}")
    lines += ["", "The JSON contains selected health data and command summaries; monitor serials, EDID hashes and raw USB identifiers are excluded.", ""]
    OUT.with_suffix(".md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"json": str(OUT), "markdown": str(OUT.with_suffix('.md'))}, ensure_ascii=False))


if __name__ == "__main__":
    main()
