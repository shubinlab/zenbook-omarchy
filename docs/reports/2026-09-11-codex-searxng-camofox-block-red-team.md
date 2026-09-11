# Codex SearXNG/Camofox Block Red-Team Report

Date: 2026-09-11

## Scope

This test measures the current host's egress path. It does not claim to be a
simultaneous Russia/United States geo-test: confirmed blocks vary by ISP/ASN,
and the United States has no single nationwide website block list comparable to
Russia's registry. A legal domain seizure, sanctions restriction, login wall,
CAPTCHA, and network censorship are recorded as different outcomes.

OONI's live API was used as the external evidence source. It reports recent
`confirmed=true` Russia measurements for the ten selected domains below. The
local Camofox test was read-only: create tab, wait, accessibility snapshot,
close tab. No cookies, credentials, uploads, downloads, clicks, or proxy
evasion were used.

## Ten-domain experiment

| Domain | OONI recent confirmed sample | Camofox result from this host |
| --- | --- | --- |
| instagram.com | yes | snapshot/content reachable |
| facebook.com | yes | snapshot/login wall reachable |
| twitter.com | yes | snapshot/login wall reachable |
| linkedin.com | yes | snapshot/content/privacy wall reachable |
| bbc.com | yes | snapshot/content reachable |
| bsky.app | yes | snapshot/content reachable |
| censor.net | yes | snapshot/content reachable |
| carnegie.ru | yes | snapshot/content reachable |
| amnezia.org | yes | snapshot/content reachable |
| paperpaper.io | yes | snapshot/content reachable |

Conclusion: the OONI-confirmed label is network-specific, not proof that every
Russian ISP blocks every request. The current host did not reproduce a hard
transport block for these domains. HTTP 200 was not treated as proof of useful
content; login, privacy, and challenge walls were kept visible to the agent.

## Chromium comparison channel

The same ten URLs were opened in a separate real `/usr/bin/chromium` process
using a fresh temporary profile and the active VPN egress. All ten rendered an
HTTP page; the observable differences were content, login/privacy walls, or
thin client-side rendering, not a transport error. This is a control result for
the current egress, not evidence that the sites are reachable from every ISP.

Two complex read-only tasks were then repeated through both routes:

| Task | SearXNG | Camofox | Chromium control |
| --- | --- | --- | --- |
| Bank of Russia key-rate page | official `cbr.ru` result with current 14.00% data | accessibility snapshot contained the key-rate page | rendered title and current 14.00% rows |
| CISA KEV catalog | official `cisa.gov` result | accessibility snapshot contained catalog and CVE entries | rendered catalog, search controls, and CVE entries |

The Codex CUA browser connector was unavailable in this session, so the
Chromium control used the locally launched real Chromium process over its
loopback debugging interface. The temporary profile was removed after the
test. No proxy, cookie, credential, or anti-bot bypass was added.

## Red-team conditions

- SearXNG without an engine/domain constraint returned unrelated Facebook and
  Roblox results for official-domain queries.
- `site:` syntax alone is not a hard allowlist because external engines may
  ignore it.
- Camofox returned HTTP 200 for pages that were only login or CAPTCHA walls.
- Camofox `/health` can be healthy while no browser is connected; a real tab
  snapshot is required for readiness.
- Unknown tab IDs, missing `userId`, and `file://` navigation were rejected.
- A clean environment without `~/.local/bin` could not find
  `searxng-search`; absolute-path or environment registration is required.
- `--raw --limit 3` returned more than three upstream results; raw mode is not
  a hard output-size boundary.

## Production change retained

The local SearXNG bridge now supports:

- `--engine google` and repeated `--engine` selectors, translated to SearXNG
  engine syntax;
- repeated `--domain` hostname constraints;
- post-filtering by exact hostname or subdomain before normalized JSON reaches
  an agent;
- rejection of `--raw --domain`, because raw output intentionally preserves
  upstream data and cannot be treated as a safety boundary.

The production checks passed for both `cbr.ru` and `cisa.gov`; all returned URLs
matched the requested domain. Invalid domain syntax and raw/domain misuse were
rejected, and a nonexistent domain returned zero results. No Camofox bypass,
external bind, cookie import, proxy chain, or global service change was
promoted.

## Source basis

- [OONI Explorer](https://explorer.ooni.org/) and [OONI API](https://api.ooni.io/)
  for network measurements.
- [OONI Russia findings](https://explorer.ooni.org/findings) for current and
  historical Russia blocking cases.
- [Internet Society Pulse Russia analysis](https://pulse.internetsociety.org/en/shutdowns/content-blocking-in-russia-26-february-2022/)
  for ISP variance and media-site blocking context.
- [SearXNG Search API](https://docs.searxng.org/dev/search_api.html?highlight=format)
  and [search syntax](https://docs.searxng.org/user/search-syntax.html) for
  API and engine-selection behavior.
- [Camofox Browser security and API documentation](https://github.com/jo-inc/camofox-browser)
  for loopback binding, session isolation, health, and snapshot behavior.
- [U.S. Department of Justice domain-seizure example](https://www.justice.gov/opa/pr/justice-department-fbi-disable-13-websites-backed-suspected-chinese-agents-sought-sensitive)
  for the distinction between U.S. legal seizure/takedown and nationwide ISP
  censorship.
