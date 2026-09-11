# Local SearXNG search bridge

`searxng-search` is a bounded, user-scoped client for the local SearXNG instance at `http://127.0.0.1:8080`.

The default output is normalized JSON for Hermes, Codex, and other local agents:

    searxng-search --limit 10 "query"

Use `--raw` when the caller needs the upstream SearXNG JSON shape:

    searxng-search --raw --category news --time-range day "query"

Supported controls are `--category`, `--language`, `--time-range`, `--page`, `--limit`, `--timeout`, and `--url`.

The bridge does not open result pages or claim that snippets are verified evidence. Use Camofox or another browser/fetch layer to inspect selected source URLs.
