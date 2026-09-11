
# SearXNG Agent and Omarchy Hardening Implementation Plan

> For agentic workers: use superpowers:executing-plans to implement this plan task-by-task with a verification checkpoint after every task.

Goal: Stabilize the local SearXNG service, expose a bounded normalized/raw search interface to Hermes, Codex, and other local agents, preserve Telegram, Hermes gateway, Camofox/Node, and Voxtype, and complete the approved Omarchy package, storage, and crash-risk cleanup.

Architecture: Keep SearXNG loopback-only at 127.0.0.1:8080. Add a user-scoped Python CLI using only the standard library; return normalized OSINT JSON by default and upstream JSON with --raw. Hermes keeps its existing SearXNG backend and Camofox remains the browser/fetch layer. System cleanup uses Omarchy or standard systemd commands, with backups and rollback checks.

Tech Stack: Arch Linux, Omarchy CLI, Docker Compose, SearXNG, Valkey, Python 3 standard library, Bash, systemd user units, curl, jq, fwupd, smartmontools, nvme-cli.

Spec: docs/superpowers/specs/2026-09-11-searxng-agent-integration-design.md

## Global Constraints

- SearXNG remains reachable only through 127.0.0.1:8080.
- All target agents are host processes owned by the user; no LAN, VPN, public, or container bridge is required.
- The canonical agent interface is a user-scoped searxng-search command.
- Default output is normalized OSINT JSON; --raw returns the original SearXNG JSON response.
- Hermes gateway configuration, permissions, version, delegation, and tool policy remain unchanged.
- Telegram autostart, Hermes gateway, Camofox/Node, and Voxtype remain enabled and are not removal candidates.
- Agents never receive access to /var/run/docker.sock.
- Never edit /usr/share/omarchy/.
- Every changed configuration receives a timestamped backup and tested rollback.
- Every task ends with positive verification, adversarial/red-team verification, OSINT/reference verification, and a recorded result.

---

### Task 1: Capture baseline and evidence checkpoint

Files:
- Create: runs/2026-09-11-searxng-omarchy-baseline/ (ignored runtime evidence only)
- Read: /home/totem/.local/share/searxng/docker-compose.yml
- Read: /home/totem/.local/share/searxng/.env
- Read: /home/totem/.local/bin/hermes-healthcheck
- Read: /home/totem/.hermes/config.yaml

Interfaces:
- Produces package versions, service states, ports, process RSS, SearXNG HTTP behavior, Compose metadata, and ownership/mode metadata without secrets.

- [ ] Step 1: Capture package and service state.

    mkdir -p /home/totem/Work/zenbook-omarchy/runs/2026-09-11-searxng-omarchy-baseline
    pacman -Q asusctl rog-control-center fwupd smartmontools nvme-cli 2>&1
    systemctl --failed --no-pager
    systemctl is-enabled fstrim.timer; systemctl is-active fstrim.timer
    systemctl --user is-active app-org.telegram.desktop@autostart.service
    systemctl --user is-active hermes-gateway.service camofox.service voxtype.service hermes-healthcheck.timer

Expected: protected services are active; fwupd, smartmontools, and nvme-cli are missing before Task 6; fstrim.timer is disabled/inactive before Task 6.

- [ ] Step 2: Capture HTTP, process, and ownership probes.

    ss -ltnp | rg ':8080\b'
    curl --fail --silent --show-error --max-time 10 http://127.0.0.1:8080/ -o /dev/null -w 'root_http=%{http_code} latency=%{time_total}\n'
    curl --fail --silent --show-error --max-time 15 'http://127.0.0.1:8080/search?q=omarchy&format=json' | jq -e '.query == "omarchy" and (.results | type == "array")' >/dev/null
    ps -eo user,pid,rss,cmd --sort=-rss | rg -i 'telegram|hermes|camofox|voxtype|quickshell|searxng|valkey' | head -80
    stat -c '%U %G %a %n' /home/totem/.local/share/searxng/.env /home/totem/.local/share/searxng/core-config-final3/settings.yml

Expected: root and JSON endpoints return 200, JSON has a result array, and no credentials are copied into evidence.

- [ ] Step 3: Run baseline red-team checks.

    curl --fail --max-time 3 http://127.0.0.1:8080/healthz >/dev/null
    ! curl --silent --max-time 3 http://127.0.0.1:8081/healthz >/dev/null
    ! rg -n -i 'secret|token|password|api[_-]?key' /home/totem/Work/zenbook-omarchy/runs/2026-09-11-searxng-omarchy-baseline

Expected: the known endpoint works, an unused endpoint fails, and the evidence directory has no secret-bearing lines.

- [ ] Step 4: Record official SearXNG references for Search API, JSON format, bind_address, secret_key, and limiter behavior.

- [ ] Step 5: Confirm the repository already ignores runs/; do not modify unrelated tracked user changes.

### Task 2: Make SearXNG maintainable and startup-aware

Files:
- Modify: /home/totem/.local/share/searxng/docker-compose.yml
- Modify: /home/totem/.local/share/searxng/.env
- Migrate: /home/totem/.local/share/searxng/core-config-final3/settings.yml only after backup
- Modify: /home/totem/.local/bin/hermes-healthcheck
- Read: /home/totem/.local/bin/hermes-start-searxng
- Read: /home/totem/.local/bin/hermes-refresh-searxng

Interfaces:
- Consumes Task 1 ownership, image, and readiness evidence.
- Produces a loopback-only SearXNG stack with deliberate image version, valid JSON, healthy Valkey, and bounded readiness behavior.

- [ ] Step 1: Back up SearXNG files.

    backup_dir="$HOME/.local/share/searxng/backups/$(date +%Y%m%d-%H%M%S)"
    sudo install -d -m 700 "$backup_dir"
    sudo cp -a "$HOME/.local/share/searxng/docker-compose.yml" "$HOME/.local/share/searxng/.env" "$HOME/.local/share/searxng/core-config-final3" "$backup_dir/"
    sudo chown -R "$USER:$USER" "$backup_dir"

Expected: a readable, user-owned backup exists and the original secret-bearing files are not made world-readable.

- [ ] Step 2: Resolve image and probe capabilities.

    cd "$HOME/.local/share/searxng"
    sudo docker compose config
    sudo docker image inspect searxng-core --format '{{.Config.Image}}' 2>/dev/null || true
    sudo docker exec searxng-core sh -c 'command -v wget || command -v curl || command -v python' 2>/dev/null

Use only a probe binary present in the image.

- [ ] Step 3: Move configuration into a user-maintainable path with mode 0700 for the directory and 0600 for secret-bearing files. Update the bind mount only after a container read test. Preserve the old path in the backup.

- [ ] Step 4: Pin the architecture-compatible SearXNG image tag or digest after checking the current published image. Record the previous value for rollback; do not leave SEARXNG_VERSION=latest.

- [ ] Step 5: Recreate and validate.

    sudo docker compose config
    sudo docker compose up -d
    sudo docker compose ps
    curl --fail --silent --show-error --max-time 10 http://127.0.0.1:8080/healthz
    curl --fail --silent --show-error --max-time 20 'http://127.0.0.1:8080/search?q=Arch+Linux&format=json' | jq -e '.results | type == "array"' >/dev/null

Expected: both containers run, healthz succeeds, and JSON search returns an array.

- [ ] Step 6: Red-team loopback, malformed input, logs, and Docker-socket isolation.

    ss -ltnp | rg ':8080\b' | rg '127\.0\.0\.1'
    curl --silent --max-time 5 'http://127.0.0.1:8080/search?q=%00&format=json' | jq -e 'type == "object"' >/dev/null || true
    sudo docker compose logs --tail=100 core valkey | rg -i 'secret|token|password' && exit 1 || true

Expected: loopback-only binding, bounded malformed-input behavior, no secret logs, and no user agent access to Docker control.

- [ ] Step 7: Compare the result with current official SearXNG container, Search API, and server-settings documentation; record deviations.

### Task 3: Add the normalized/raw local agent bridge

Files:
- Create: profiles/zenbook-um3406ka/search/searxng-search
- Create: profiles/zenbook-um3406ka/search/README.md
- Create: profiles/zenbook-um3406ka/search/doctor.sh
- Modify: scripts/bootstrap.sh only if the existing profile installation pattern requires registration
- Install target: /home/totem/.local/bin/searxng-search

Interfaces:
- Consumes GET /search JSON from Task 2.
- Produces searxng-search QUERY [options], normalized JSON by default, and upstream JSON with --raw.

- [ ] Step 1: Document exact options: --raw, --category, --language, --time-range day|month|year, --page, --limit, --timeout, --url, and --help. Document exit codes 0 success, 2 invalid arguments, 3 SearXNG unavailable, 4 malformed response, and 5 bounded response rejected.

- [ ] Step 2: Write failing tests for duplicate URLs, missing fields, malformed JSON, result limits, metadata, raw passthrough, and timeout mapping; run them and record expected failures.

- [ ] Step 3: Implement with Python urllib.request, urllib.parse, and json only. Reject empty queries, cap query length at 1000 characters, cap results at 50 by default, cap response bytes at 2 MiB, use a 15-second default timeout, and never print request headers or environment secrets.

- [ ] Step 4: Run unit tests and install the executable.

    searxng-search --help
    searxng-search --limit 5 'Arch Linux' | jq -e '.results | length <= 5' >/dev/null
    searxng-search --raw --limit 3 'Omarchy' | jq -e '.query == "Omarchy"' >/dev/null

- [ ] Step 5: Red-team invalid options, empty/oversized queries, unavailable endpoint, malformed upstream response, and response-size limit. Confirm no filesystem path, Docker socket, secret, or unbounded result is reachable.

- [ ] Step 6: Verify category, language, time-range, and site: queries against official SearXNG Search API parameter names.

### Task 4: Repair and verify the Hermes search path

Files:
- Modify: /home/totem/.local/bin/hermes-healthcheck
- Read: /home/totem/.hermes/config.yaml
- Read: /home/totem/.config/systemd/user/hermes-healthcheck.service
- Read: /home/totem/.config/systemd/user/hermes-healthcheck.timer

Interfaces:
- Consumes stable SearXNG health and CLI behavior from Tasks 2–3.
- Produces a healthcheck that reports readiness accurately without changing Hermes gateway policy or version.

- [ ] Step 1: Reproduce healthcheck behavior after a controlled SearXNG restart and while ready; capture status and sanitized output.

- [ ] Step 2: Add bounded SearXNG retries only to the healthcheck: three attempts, two seconds apart. Keep Camofox and Hermes checks. Do not make the healthcheck start Docker or alter gateway policy.

- [ ] Step 3: Verify systemd.

    systemctl --user daemon-reload
    systemctl --user start hermes-healthcheck.service
    systemctl --user status hermes-healthcheck.service --no-pager
    journalctl --user -u hermes-healthcheck.service -n 30 --no-pager

Expected: all three services report ok when ready.

- [ ] Step 4: Stop only SearXNG, verify bounded failure, restore it, and verify success. Confirm Hermes gateway, Camofox, and Telegram remain running.

- [ ] Step 5: Verify Hermes backend expectations against current Hermes documentation. Leave undocumented settings unchanged.

### Task 5: Measure protected workloads and apply only reversible tuning

Files:
- Read/possibly modify after evidence: /home/totem/.config/voxtype/config.toml
- Read/possibly modify after evidence: /home/totem/.config/systemd/user/camofox.service
- Read/possibly modify after evidence: /home/totem/.config/systemd/user/hermes-gateway.service
- Read-only verify: /home/totem/.config/autostart/org.telegram.desktop.desktop

Interfaces:
- Produces before/after resource evidence and narrowly scoped tuning while preserving requested functionality.

- [ ] Step 1: Take five idle RSS samples over one minute for Telegram, Hermes, Camofox/Node, Voxtype, and Quickshell. Record restart counts, ports, and sanitized error counts.

- [ ] Step 2: Run one Hermes SearXNG query, one Camofox page session, one Telegram idle/network check without sending a message, and one Voxtype test using its configured remote endpoint. Record peak RSS and latency.

- [ ] Step 3: Verify Voxtype model availability/language detection/no fallback, Camofox stale-process/profile accumulation, Hermes reconnect behavior, and Telegram DNS/network warnings. Do not delete profiles or caches.

- [ ] Step 4: Apply only evidence-backed reversible timeouts, stale-process cleanup hooks, or model/runtime settings. Do not disable autostart or remove a protected workload.

- [ ] Step 5: Restart or fault-test one user service at a time where safe; verify recovery and roll back regressions.

### Task 6: Complete approved package, firmware, storage, and trim work

Files:
- Modify system package state through Omarchy only.
- Modify systemd enablement through systemctl only.
- Never edit /usr/share/omarchy/.

Interfaces:
- Produces no ROG GUI, preserved asusctl/asusd, installed diagnostics tools, active weekly trim, and verified device/firmware information.

- [ ] Step 1: Remove only the GUI.

    omarchy pkg drop rog-control-center
    pacman -Q rog-control-center 2>&1
    pacman -Q asusctl
    systemctl is-active asusd
    asusctl info --show-supported

Expected: GUI absent, asusctl and asusd healthy.

- [ ] Step 2: Red-team ASUS removal: verify no unexpected package removal, supported charge/platform controls, active asusd, and no new failed system unit.

- [ ] Step 3: Install requested tools.

    omarchy pkg add fwupd smartmontools nvme-cli
    pacman -Q fwupd smartmontools nvme-cli
    fwupdmgr --version
    smartctl --version
    nvme version

- [ ] Step 4: Run fwupdmgr get-devices, fwupdmgr get-updates, smartctl --scan-open, and nvme list. Treat no-device or permission results as evidence, not as silent success. Do not perform firmware updates.

- [ ] Step 5: Enable and test weekly trim.

    sudo systemctl enable --now fstrim.timer
    systemctl is-enabled fstrim.timer
    systemctl is-active fstrim.timer
    systemctl list-timers fstrim.timer --no-pager
    sudo systemctl start fstrim.service
    sudo journalctl -u fstrim.service -n 30 --no-pager

Verify Btrfs root remains mounted with ssd and compression, with no duplicate daily trim timer or conflicting discard option.

- [ ] Step 6: Red-team hardware changes: confirm trim scheduling, asusd/power profiles, and read-only SMART/NVMe/fwupd discovery. Firmware changes remain separately gated.

- [ ] Step 7: Compare tool and fstrim behavior with current official documentation and Arch package metadata.

### Task 7: Reduce Quickshell crash risk and validate desktop configuration

Files:
- Modify only user config through Omarchy commands: ~/.config/omarchy/shell.json, plugin state, and ~/.config/hypr/bindings.lua if duplicate bindings remain.
- Never modify /usr/share/omarchy/.

Interfaces:
- Produces reduced third-party hot-reload risk, no duplicate F13 binding, and fresh Quickshell/Hyprland verification.

- [ ] Step 1: Record omarchy plugin list --json and duplicate F13 blocks. Create timestamped backups.

- [ ] Step 2: Disable io.github.matheusmedrado.omadock first with omarchy plugin disable io.github.matheusmedrado.omadock, restart the shell, and verify before considering another plugin. Preserve io.github.moneytosms.asus until asusctl replacement behavior is confirmed.

- [ ] Step 3: Monitor Quickshell RSS, coredumps, user journal, and plugin reload messages for at least two minutes. Confirm bar, notifications, network/power widgets, and protected services. Restore backup on regression.

- [ ] Step 4: If duplicate bindings remain, keep one F13 Voxtype block; run hyprctl reload, hyprctl configerrors, and hyprctl binds; verify the physical key and Voxtype status.

- [ ] Step 5: Compare observed hot-reload behavior with current Omarchy/Quickshell upstream reports. Report mitigation and remaining upstream risk separately; do not claim an upstream code fix.

### Task 8: Final acceptance and sanitized handoff

Files:
- Modify relevant wiki/ evidence documentation only after sanitized results.
- Read CHANGELOG.md, tools/ci-check.sh, and tools/check-public-repo.sh.

- [ ] Step 1: Verify SearXNG loopback/API, normalized/raw CLI, Hermes healthcheck, Camofox, Voxtype, Telegram autostart, asusd, tools, fstrim.timer, no failed units, and no new coredump for tested desktop components.

- [ ] Step 2: Run from zenbook-omarchy/:

    ./tools/ci-check.sh
    ./tools/check-public-repo.sh
    git diff --check

Do not stage or rewrite unrelated pre-existing modifications.

- [ ] Step 3: Red-team final state: no public SearXNG listener, no Docker socket exposure, no secrets in tracked files/evidence, no protected service removal, no unexpected package removals, no failed units, and rollback for every changed file.

- [ ] Step 4: Document only sanitized outcomes. Report unresolved issues as UNVERIFIED or BLOCKED and do not claim completion without fresh evidence for every required acceptance criterion.
