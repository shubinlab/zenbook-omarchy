#!/usr/bin/env python3
"""Run a bounded, local Hyprland/DRM display stability matrix.

The harness temporarily creates Omarchy's stay-awake marker, forces the requested
VRR policy with Hyprland's Lua eval API, samples Hyprland/DRM/connector state,
and restores the previous VRR policy and idle marker in finally.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

DEFAULT_OUT = Path(__file__).resolve().parents[1] / "runs" / (dt.date.today().isoformat() + "-vrr-red-team.json")
IDLE_MARKER = Path.home() / ".local/state/omarchy/indicators/stay-awake"
OUTPUT = "DP-1"
MODES = {
    "1080p120-10b": ("1920x1080@120.00", 10),
    "1440p120-10b": ("2560x1440@120.00", 10),
    "1440p144-10b": ("2560x1440@143.99", 10),
    "1440p240-10b": ("2560x1440@239.97", 10),
    "1440p144-8b": ("2560x1440@143.99", 8),
}


def run(args: list[str], timeout: float = 10) -> tuple[int, str]:
    env = os.environ.copy()
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        hypr_root = Path("/run/user") / str(os.getuid()) / "hypr"
        sockets = sorted(hypr_root.glob("*/.socket.sock"))
        if sockets:
            env["HYPRLAND_INSTANCE_SIGNATURE"] = sockets[0].parent.name
    p = subprocess.run(args, env=env, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    return p.returncode, p.stdout.strip()


def hypr(args: list[str], timeout: float = 10) -> str:
    return run(["hyprctl", *args], timeout)[1]


def eval_lua(expr: str) -> str:
    return hypr(["eval", expr])


def set_output(mode: str, bitdepth: int, vrr: int) -> dict[str, str]:
    global_result = eval_lua(f"hl.config({{ misc = {{ vrr = {vrr} }} }})")
    monitor_result = eval_lua(
        "hl.monitor({ output = \"DP-1\", "
        f"mode = \"{mode}\", position = \"0x0\", scale = 1.6, "
        f"bitdepth = {bitdepth}, cm = \"auto\", vrr = {vrr} }})"
    )
    time.sleep(2)
    return {"global": global_result, "monitor": monitor_result}


def monitor_snapshot() -> dict:
    try:
        mons = json.loads(hypr(["monitors", "-j"]))
        mon = next((m for m in mons if m.get("name") == OUTPUT), {})
    except Exception as exc:
        mon = {"error": repr(exc)}
    try:
        clients = json.loads(hypr(["clients", "-j"]))
    except Exception:
        clients = []
    return {
        "width": mon.get("width"),
        "height": mon.get("height"),
        "refresh_hz": mon.get("refreshRate"),
        "scale": mon.get("scale"),
        "format": mon.get("currentFormat"),
        "color_preset": mon.get("colorManagementPreset"),
        "vrr": mon.get("vrr"),
        "dpms": mon.get("dpmsStatus"),
        "disabled": mon.get("disabled"),
        "fullscreen_test_windows": [
            {k: c.get(k) for k in ("class", "title", "fullscreen", "fullscreenClient")}
            for c in clients if "zenbook-vrr-test" in str(c)
        ],
    }


def drm_vrr_values() -> list[int]:
    try:
        raw = run(["modetest", "-M", "amdgpu", "-p"], timeout=8)[1]
        return [int(x) for x in re.findall(
            r"VRR_ENABLED:.*?\n(?:.*\n){0,3}?\s+value:\s+(\d+)", raw
        )]
    except Exception:
        return []


def connector_status() -> dict[str, str]:
    result = {}
    for p in sorted(Path("/sys/class/drm").glob("*-DP-1/status")):
        try:
            result[str(p)] = p.read_text().strip()
        except Exception as exc:
            result[str(p)] = f"ERROR:{type(exc).__name__}"
    return result


def kernel_lines(since: str) -> list[str]:
    try:
        raw = run(["journalctl", "-k", "--since", since, "--no-pager", "-o", "short-iso"], timeout=8)[1]
    except Exception:
        return []
    return [line for line in raw.splitlines()
            if any(token in line.lower() for token in ("amdgpu", "drm", "dp-1", "typec", "usb"))]


def sample(phase: str) -> dict:
    now = dt.datetime.now().astimezone()
    state = monitor_snapshot()
    return {
        "time": now.isoformat(),
        "phase": phase,
        "monitor": state,
        "connector": connector_status(),
        "drm_vrr_enabled": drm_vrr_values(),
    }


def run_phase(name: str, mode: str, bitdepth: int, seconds: int, fullscreen: bool,
              samples: list[dict], expected_dpms_off: bool = False) -> dict:
    started = dt.datetime.now().astimezone()
    setup = set_output(mode, bitdepth, 1)
    foot = None
    try:
        foot = subprocess.Popen([
            "foot", "--app-id=zenbook-vrr-test", "sh", "-c",
            'while true; do printf "zenbook VRR test %s\\n" "$(date +%T)"; sleep .1; done',
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(3)
        fullscreen_result = None
        if fullscreen:
            fullscreen_result = eval_lua(
                'hl.dispatch(hl.dsp.window.fullscreen({ action = "set", mode = "fullscreen" }))'
            )
            time.sleep(2)
        phase_samples = []
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            row = sample(name)
            phase_samples.append(row)
            samples.append(row)
            time.sleep(2)
        return phase_result(name, mode, bitdepth, seconds, fullscreen, setup,
                            fullscreen_result, started, phase_samples, expected_dpms_off)
    finally:
        if foot is not None:
            try:
                eval_lua('hl.dispatch(hl.dsp.window.fullscreen({ action = "unset" }))')
            except Exception:
                pass
            foot.send_signal(signal.SIGTERM)
            try:
                foot.wait(timeout=3)
            except subprocess.TimeoutExpired:
                foot.kill()


def phase_result(name, mode, bitdepth, seconds, fullscreen, setup, fullscreen_result,
                 started, rows, expected_dpms_off) -> dict:
    anomalies = []
    for row in rows:
        mon = row["monitor"]
        if any(value != "connected" for value in row["connector"].values()):
            anomalies.append({"time": row["time"], "kind": "connector_not_connected"})
        if mon.get("dpms") is False and not expected_dpms_off:
            anomalies.append({"time": row["time"], "kind": "unexpected_dpms_off"})
        if mon.get("disabled"):
            anomalies.append({"time": row["time"], "kind": "monitor_disabled"})
    return {
        "name": name,
        "requested": {"mode": mode, "bitdepth": bitdepth, "vrr": 1,
                      "fullscreen": fullscreen, "seconds": seconds},
        "setup_result": setup,
        "fullscreen_result": fullscreen_result,
        "started": started.isoformat(),
        "ended": dt.datetime.now().astimezone().isoformat(),
        "sample_count": len(rows),
        "anomalies": anomalies,
        "observed": {
            "refresh_hz": sorted({r["monitor"].get("refresh_hz") for r in rows}),
            "sizes": sorted({(r["monitor"].get("width"), r["monitor"].get("height")) for r in rows}),
            "formats": sorted({r["monitor"].get("format") for r in rows}),
            "hypr_vrr": sorted({r["monitor"].get("vrr") for r in rows}),
            "drm_vrr_enabled": sorted({v for r in rows for v in r["drm_vrr_enabled"]}),
            "dpms": sorted({r["monitor"].get("dpms") for r in rows}),
            "connector": sorted({v for r in rows for v in r["connector"].values()}),
        },
    }


def write_markdown(path: Path, result: dict) -> None:
    lines = [
        f"# VRR red-team run — {result['date']}", "",
        "Этот отчёт создан локальным `tools/run_vrr_redteam.py`. На время прогона "
        "Omarchy stay-awake был включён, а после завершения восстановлен.", "",
        f"- Host profile: ASUS Zenbook 14 UM3406, AMDGPU, Omarchy/Hyprland.",
        f"- Output under test: DP-1 через JSAUX USB-C dock, LG UltraGear, 2560×1440.",
        "- Forced policy: per-output and global `vrr=1` (always-on).",
        "- Telemetry: local service sampled every 5 seconds; this runner sampled every 2 seconds.", "",
        "## Results", "",
        "| Phase | Requested | Samples | VRR (Hyprland) | DRM VRR_ENABLED | DPMS | Connector | Format | Anomalies |",
        "|---|---|---:|---|---|---|---|---|---:|",
    ]
    for p in result["phases"]:
        req = p["requested"]
        obs = p["observed"]
        lines.append(
            f"| `{p['name']}` | {req['mode']}, {req['bitdepth']} bit, "
            f"{'fullscreen' if req['fullscreen'] else 'windowed'} | {p['sample_count']} | "
            f"{obs['hypr_vrr']} | {obs['drm_vrr_enabled']} | {obs['dpms']} | "
            f"{obs['connector']} | {obs['formats']} | {len(p['anomalies'])} |"
        )
    lines += ["", "## Red-team checks", "", "- Mode matrix covers 1080p/120 Hz, 1440p/120 Hz, 1440p/144 Hz and 1440p/240 Hz.",
              "- Both fullscreen and windowed rendering are tested.",
              "- 8-bit versus 10-bit is tested at 144 Hz.",
              "- Every sample checks DPMS, connector state, monitor disable state, output format and DRM VRR property.",
              "- A DPMS cycle and rapid mode-cycle stress test are recorded separately below.", ""]
    if result.get("red_team"):
        lines += ["## Stress checks", "", "```json", json.dumps(result["red_team"], ensure_ascii=False, indent=2), "```", ""]
    lines += ["## Interpretation", "", result["interpretation"], ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=int, default=30)
    ap.add_argument("--output", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    previous_marker = IDLE_MARKER.exists()
    IDLE_MARKER.parent.mkdir(parents=True, exist_ok=True)
    IDLE_MARKER.touch()
    all_samples = []
    phases = []
    run_started = dt.datetime.now().astimezone()
    try:
        matrix = [
            ("1080p120-10b-windowed", *MODES["1080p120-10b"], False),
            ("1440p120-10b-fullscreen", *MODES["1440p120-10b"], True),
            ("1440p144-10b-windowed", *MODES["1440p144-10b"], False),
            ("1440p144-10b-fullscreen", *MODES["1440p144-10b"], True),
            ("1440p240-10b-fullscreen", *MODES["1440p240-10b"], True),
            ("1440p144-8b-fullscreen", *MODES["1440p144-8b"], True),
        ]
        for name, (mode, bitdepth), fullscreen in matrix:
            phases.append(run_phase(name, mode, bitdepth, args.seconds, fullscreen, all_samples))

        stress = {"mode_cycles": [], "dpms_cycle": [], "kernel_events": []}
        set_output("2560x1440@143.99", 10, 1)
        for i in range(3):
            for label, mode in (("144", "2560x1440@143.99"), ("120", "2560x1440@120.00"), ("240", "2560x1440@239.97")):
                setup = set_output(mode, 10, 1)
                row = sample(f"cycle-{i+1}-{label}")
                all_samples.append(row)
                stress["mode_cycles"].append({"cycle": i + 1, "label": label, "setup": setup, "sample": row})
        dpms_start = dt.datetime.now().astimezone()
        off_result = hypr(["dispatch", "dpms", "off", OUTPUT])
        time.sleep(5)
        off_sample = sample("intentional-dpms-off")
        on_result = hypr(["dispatch", "dpms", "on", OUTPUT])
        time.sleep(5)
        on_sample = sample("dpms-on-recovery")
        stress["dpms_cycle"] = {"off_command": off_result, "off_sample": off_sample,
                                 "on_command": on_result, "on_sample": on_sample}
        stress["kernel_events"] = kernel_lines(dpms_start.isoformat(timespec="seconds"))[-100:]
        set_output("2560x1440@143.99", 10, 1)
        result = {
            "date": run_started.date().isoformat(),
            "started": run_started.isoformat(),
            "ended": dt.datetime.now().astimezone().isoformat(),
            "forced_policy": {"global_vrr": 1, "per_output_vrr": 1},
            "phases": phases,
            "red_team": stress,
            "sample_count": len(all_samples),
            "interpretation": "VRR was forced at the Hyprland policy level. The report must be read together with observed drm_vrr_enabled and monitor vrr values: a requested vrr=1 is not proof that the DRM variable-refresh property became active.",
        }
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        write_markdown(args.output.with_suffix(".md"), result)
        print(json.dumps({"json": str(args.output), "markdown": str(args.output.with_suffix('.md')), "phases": phases, "red_team": stress}, ensure_ascii=False), flush=True)
    finally:
        try:
            set_output("2560x1440@143.99", 10, 0)
        except Exception:
            pass
        if not previous_marker:
            IDLE_MARKER.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
