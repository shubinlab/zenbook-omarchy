# Cross-check against existing shubinlab work — 2026-09-08

The audit reviewed the existing Zenbook, backup, voice-input, OSINT and dotfiles repositories through the authenticated GitHub CLI. Private repository contents were used for local cross-checking but are not copied into this public repository.

The GitHub check was repeated on 2026-09-08. `zenbook-omarchy` is at public commit `b7acb31`; the related private Zenbook, voice-input, OSINT and backup repositories remain available to the authenticated account, and the public Zenbook verification pack remains the freshest related public reference. Their README guidance was treated as methodology, not as proof that another distribution's tuning belongs on Omarchy.

## Reused practices

- The private Zenbook Ubuntu audit repository: keep a read-only baseline, require evidence before firmware/kernel/power changes, avoid writing serials and raw logs to Git, and separate live state from claims.
- The Zenbook CachyOS install/verify pack: use verify gates, rollback paths, thermal/power experiments and CI; its APST and tuning recommendations are treated as hypotheses, not transplanted into Omarchy.
- The private Zenbook voice-input repository: keep health gates explicit and store recordings or raw user data outside Git.
- The private backup/CICD repository: fail closed on verification errors and keep evidence separate from payloads.
- The private OSINT inventory repository: record source, acquisition time, scope, caveat and claim status; do not bypass access controls.

## Applied here

- Every display experiment blocks Omarchy idle and systemd idle/sleep/lid actions.
- A sample is invalid when the session becomes idle or locked, the inhibitor disappears, DP-1 disconnects, DPMS changes unexpectedly or the monitor is disabled.
- Public reports are sanitized before commit; private telemetry remains under the user state directory.
- System changes are kept in `~/.config`, with a checked-in copy of the intended monitor override. `/usr/share/omarchy` is not edited.
- The current audit separates `confirmed`, `candidate improvement` and `not justified` decisions.
- The expanded component run records thermal peaks, a controlled memory test, temporary storage I/O, camera/microphone checks, gateway loss, and post-test display state while keeping the raw system debug output outside Git.
