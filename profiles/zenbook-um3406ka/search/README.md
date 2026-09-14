# Local SearXNG search bridge

`searxng-search` is a bounded, user-scoped client for the local SearXNG instance at `http://127.0.0.1:8080`.

The default output is normalized JSON for Hermes, Codex, and other local agents:

    searxng-search --limit 10 "query"

Use `--raw` when the caller needs the upstream SearXNG JSON shape:

    searxng-search --raw --category news --time-range day "query"

Supported controls are `--category`, `--language`, `--time-range`, `--page`, `--limit`, `--timeout`, `--engine`, `--domain`, and `--url`.

For higher-confidence OSINT, select an engine and require a hostname. The normalized output drops results outside the requested domain:

    searxng-search --engine google --domain cisa.gov "Known Exploited Vulnerabilities Catalog"

`--domain` is intentionally incompatible with `--raw`; raw mode preserves the upstream response and is not a domain-safety boundary.

The bridge does not open result pages or claim that snippets are verified evidence. Use Camofox or another browser/fetch layer to inspect selected source URLs.

## Lifecycle owner

The optional local SearXNG Compose stack is owned by the root systemd unit
`searxng.service`. The unit template is portable and renders the local
Compose path from `SEARXNG_DIR` (default:
`$HOME/.local/share/searxng`); no username or private path is committed.

Install it only when the Compose directory is already present and Docker is
intended to be enabled:

```bash
SEARXNG_DIR="$HOME/.local/share/searxng" \
  ./profiles/zenbook-um3406ka/search/apply.sh --apply
./profiles/zenbook-um3406ka/search/apply.sh --check
./profiles/zenbook-um3406ka/search/doctor.sh
```

`--apply` uses visible `pkexec` authentication, backs up an existing unit in
user state, validates the rendered unit, enables Docker and waits for the
loopback `/healthz` endpoint. Use the profile doctor as the acceptance check;
do not create a second manual `docker compose` lifecycle owner.
