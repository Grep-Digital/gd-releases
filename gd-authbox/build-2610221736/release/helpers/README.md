# Quick helpers

Scripts for the three builds described in [../README.md](../README.md). They set session variables and run health or tip checks. They do not print secret values. They do not start or replace containers.

| Script | What it does |
|---|---|
| [set-build.ps1](set-build.ps1) | Sets `$Build`, `$KC`, `$API`, and `$Access` for one build |
| [health-build.ps1](health-build.ps1) | Runs the minimum health checks for that build |
| [tip-stepca-health.ps1](tip-stepca-health.ps1) | Base PKI: `step ca health` inside `auth-sandbox-step-ca-1` |
| [tip-mtls-ports.ps1](tip-mtls-ports.ps1) | Base PKI: TCP probe host `:1029` and `:8883` when device listeners are published |

**Create / renew certificates (Base PKI only):** use the scripts that already ship in the Base PKI zip under pack-root `devx/pki/` — `issue-client-cert.ps1` (create) and `refresh-client-cert.ps1` (renew). Walkthrough: [../USER-GUIDE.md](../USER-GUIDE.md) §5.6.6–§5.6.9.

## Set the build

From the `release/helpers` folder, or with the full path:

```powershell
. .\set-build.ps1 -Build base
. .\set-build.ps1 -Build base-secure
. .\set-build.ps1 -Build base-pki
```

Then:

```powershell
. .\health-build.ps1
```

On Base PKI only:

```powershell
. .\tip-stepca-health.ps1
. .\tip-mtls-ports.ps1
# From the unpacked pack root (not this helpers folder):
# .\devx\pki\issue-client-cert.ps1 -CommonName demo-device-1
# .\devx\pki\refresh-client-cert.ps1 -CommonName demo-device-1
```

| `$Build` | `$KC` | `$API` | `$Access` |
|---|---|---|---|
| `base` | `http://localhost:8080` | `http://localhost:8000` | `direct` |
| `base-secure` | `http://localhost:9000` | `http://localhost:9000` | `gateway` |
| `base-pki` | `http://localhost:9000` | `http://localhost:9000` | `gateway` |

After `set-build.ps1`, continue the checklist in [../SCENARIO-TESTING.md](../SCENARIO-TESTING.md) or the cert walkthrough in [../USER-GUIDE.md](../USER-GUIDE.md) §5.6. Contracts: [../TECHNICAL-REFERENCE.md](../TECHNICAL-REFERENCE.md).

## Tips covered here

| Tip | Script | Pass looks like |
|---|---|---|
| step-ca serving | `tip-stepca-health.ps1` | prints `ok` |
| Device listeners published | `tip-mtls-ports.ps1` | `1029=open` / `8883=open`, or `closed` when unpublished |
| Gateway after PKI | `health-build.ps1` with `-Build base-pki` | API `ok`, Envoy admin ready, step-ca `ok`, lab ports closed |
| Create leaf | pack `devx/pki/issue-client-cert.ps1` | writes `.crt` / `.key` (default `deploy/pki/certs/clients`) |
| Renew leaf | pack `devx/pki/refresh-client-cert.ps1` | revokes prior leaf if present, then re-issues; prints `Refreshed` |

Full create / renew / expiry walkthrough: [../USER-GUIDE.md](../USER-GUIDE.md) §5.6.6–§5.6.9. When `:1029` is open, HTTP device-trust scenarios are S-75 through S-83 in [../SCENARIO-TESTING.md](../SCENARIO-TESTING.md).
