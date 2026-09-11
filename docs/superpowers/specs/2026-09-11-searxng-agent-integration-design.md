# SearXNG Agent Integration Design

**Date:** 2026-09-11

**Status:** Proposed for user review

## Goal

Provide one reliable, local-only SearXNG search plane for Hermes, Codex, and other user-owned agents on the Omarchy laptop, while preserving Telegram, Hermes gateway, Camofox/Node, and Voxtype and reducing avoidable service, memory, and configuration risk.

## Decisions

- SearXNG remains reachable only through `127.0.0.1:8080`.
- All target agents are host processes owned by the user; no LAN, VPN, public, or container bridge is required for the first implementation.
- The canonical agent interface is a user-scoped `searxng-search` command.
- The default output is normalized OSINT JSON. `--raw` returns the original SearXNG JSON response.
- The first Codex integration uses the local shell interface. Codex's existing built-in live web search is not replaced.
- An MCP adapter is optional and deferred until the CLI contract is proven useful.
- Hermes gateway configuration, permissions, version, delegation, and tool policy remain unchanged. Only the SearXNG readiness/health path may be adjusted within the approved local scope.
- Camofox remains the controlled browser/fetch layer for opening selected sources; SearXNG is the discovery layer.

## Current evidence and constraints

- The local SearXNG root and JSON search endpoints currently return HTTP 200.
- Hermes already declares `web.backend: searxng` and uses Camofox as its browser backend.
- The Hermes healthcheck has had a transient SearXNG failure during startup and later successful checks.
- The Compose file uses `SEARXNG_VERSION=latest`; the implementation must test and then pin a known-good image tag or digest.
- The active SearXNG settings file is owned by `systemd-network` and is mode `0600`, so ordinary user maintenance and backup are currently obstructed. Ownership changes must be staged and verified before any overwrite.
- The Compose containers run under the system Docker daemon. Agents must never receive access to `/var/run/docker.sock`; they use the HTTP API only.
- Telegram autostart, Hermes gateway, Camofox/Node, and Voxtype are protected workloads. Their memory and reliability are measured before tuning; they are not removal candidates.
- Omarchy packaged files under `/usr/share/omarchy/` are read-only reference material and must not be edited.

## Architecture

```text
Hermes web backend ───────┐
Codex/local shell agent ───┼─> searxng-search ─> 127.0.0.1:8080/search
Other local agents ───────┘             │
                                       ├─> normalized JSON
                                       └─> --raw SearXNG JSON

Selected result URL ─> Camofox controlled browser ─> agent analysis
```

`searxng-search` is intentionally not a long-running service. It validates input, calls the already-running SearXNG HTTP endpoint, applies bounded retries and timeouts, normalizes results, removes exact URL duplicates, and preserves provenance fields. It must not expose Docker control, credentials, or filesystem access to callers.

The normalized contract contains at least `query`, `category`, `language`, `time_range`, `requested_at`, `instance`, and a bounded `results` array. Each result contains `title`, `url`, `content`, `engine`, `publishedDate` when available, and a stable deduplication key. The raw mode is an escape hatch for callers that need fields not yet normalized.

## OSINT behavior

The first test matrix covers:

- Russian and English general searches.
- News and time-range searches for day, month, and year.
- `site:` queries and explicit engine/category selectors.
- Technical and scientific queries.
- Empty results, engine timeouts, CAPTCHA/429 responses, malformed JSON, duplicate URLs, and oversized result sets.
- Source diversity and provenance retention, so an agent can distinguish discovery results from fetched primary-source content.

The bridge does not claim that search snippets are verified facts. Agents must fetch and cite the underlying page when evidence matters. Search results are discovery evidence; Camofox or another fetcher supplies page-level evidence.

## Reliability and security

- Keep the bind address loopback-only.
- Keep a non-default secret and avoid printing settings or environment secrets in diagnostics.
- Add a readiness probe that distinguishes "service starting" from "service failed".
- Add bounded request timeout, retry, and response-size limits in the bridge.
- Pin the SearXNG image after a clean test; upgrades are deliberate and reversible.
- Validate Valkey connectivity if limiter or other stateful features require it.
- Add Compose health information and log rotation/resource limits only after measuring current behavior.
- Keep the SearXNG configuration in a user-maintainable, backed-up path without weakening secret permissions.
- Keep Hermes, Camofox, Voxtype, and Telegram on loopback or their current least-exposure settings.

## Staged execution and gates

Each stage follows the same gate: capture baseline, make one bounded change, run positive tests, run adversarial/red-team tests, compare against current official documentation or upstream issue data, record rollback, and only then continue.

1. **Baseline and ownership:** capture packages, units, ports, process RSS, Compose state, configuration metadata, and current healthcheck behavior without printing secrets.
2. **SearXNG core:** repair configuration ownership/maintenance flow, validate JSON/API settings, add readiness behavior, test Valkey, and pin the tested image.
3. **Agent bridge:** add the user-scoped normalized/raw CLI, unit tests for parsing and limits, and live integration tests against `127.0.0.1:8080`.
4. **Hermes path:** verify that Hermes's existing SearXNG backend uses the same endpoint and that startup does not produce a false failure; do not alter gateway policy.
5. **Codex/local agents:** document and test shell invocation from the current trusted `/home/totem/Work` environment. Evaluate MCP only after the CLI passes its acceptance tests.
6. **Protected workloads:** measure Telegram, Hermes gateway, Camofox/Node, and Voxtype under idle and representative use; apply only reversible, user-approved tuning.
7. **System hygiene:** perform the separately approved `rog-control-center` removal, install `fwupd`, `smartmontools`, and `nvme-cli`, configure `fstrim.timer`, and then re-test Quickshell and the desktop service set.

## Acceptance criteria

- SearXNG remains loopback-only and answers both HTML and JSON probes as configured.
- Hermes healthcheck is green after boot and does not report a false negative while SearXNG is becoming ready.
- `searxng-search example --json` returns bounded normalized JSON; `searxng-search example --raw` returns the upstream JSON shape; both fail clearly when SearXNG is unavailable.
- At least one Codex shell invocation and one Hermes search path use the same local API and preserve source URLs.
- Red-team tests cannot access Docker control, secrets, arbitrary local files, or an unbounded response.
- Protected services remain enabled and functional, with before/after memory and failure evidence.
- Every changed configuration has a timestamped backup and a tested rollback command.
- Verification output is sanitized before it is added to repository evidence or documentation.

## Out of scope

- Publishing SearXNG to the internet or LAN.
- Changing Hermes gateway permissions, model/version, delegation, or global policy.
- Removing Telegram, Hermes, Camofox/Node, Voxtype, or their data.
- Editing `/usr/share/omarchy/`.
- Treating snippets, AI summaries, or search rankings as source verification.
