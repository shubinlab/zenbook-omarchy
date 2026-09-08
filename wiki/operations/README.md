# Operations

| Task | Procedure |
|---|---|
| Rebuild | [Recovery guide](../../docs/recovery.md) |
| Check profile without changes | `./scripts/bootstrap.sh --profile zenbook-um3406ka --check` |
| Test monitor/VRR | [Protected experiment](experiments.md) |
| Check voice | `./profiles/zenbook-um3406ka/voice/doctor.sh` |
| Check terminal | `terminal-doctor` |
| Inspect telemetry | [Profile telemetry](../../profiles/zenbook-um3406ka/docs/telemetry.md) |
| Read the conclusion | [Audit](../../profiles/zenbook-um3406ka/docs/audit.md) |

Every experiment must record the active profile, power-management guards,
requested mode, observed mode, result and rollback state. Raw logs stay local.
