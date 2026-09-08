# Telemetry

Telemetry is an optional profile capability, never a prerequisite for the
bootstrap. A profile may install a user systemd service when its collector and
privacy boundary are documented.

Collectors should write only to a user state directory, use restrictive file
permissions, and avoid credentials, serial numbers, EDID hashes, hostnames and
raw audio. Local evidence belongs in the ignored `runs/` directory. Publish
only an aggregate report after sanitizing it.

The Zenbook profile's implementation and fields are documented in its
[telemetry evidence page](../evidence/telemetry.md).
