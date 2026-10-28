# Quick helpers

Scripts for the three builds described in [../README.md](../README.md). They set session variables and run health or tip checks. They do not print secret values. They do not start or replace containers.

| Script | What it does |
|---|---|
| [set-build.ps1](set-build.ps1) | Sets `$Build`, `$KC`, `$API`, and `$Access` for one build |
| [health-build.ps1](health-build.ps1) | Runs the minimum health checks for that build |
| [tip-stepca-health.ps1](tip-stepca-health.ps1) | Base PKI: `step ca health` inside `auth-sandbox-step-ca-1` |
| [tip-mtls-ports.ps1](tip-mtls-ports.ps1) | Base PKI: TCP probe host `:1029` and `:8883` when device listeners are published |

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
```

| `$Build` | `$KC` | `$API` | `$Access` |
|---|---|---|---|
| `base` | `http://localhost:8080` | `http://localhost:8000` | `direct` |
| `base-secure` | `http://localhost:9000` | `http://localhost:9000` | `gateway` |
| `base-pki` | `http://localhost:9000` | `http://localhost:9000` | `gateway` |

After `set-build.ps1`, continue the progressive pass in [../SCENARIO-TESTING.md](../SCENARIO-TESTING.md). Component defaults and health tables are in [../USER-GUIDE.md](../USER-GUIDE.md). Contracts: [../TECHNICAL-REFERENCE.md](../TECHNICAL-REFERENCE.md).

## Tips covered here

| Tip | Script | Pass looks like |
|---|---|---|
| step-ca serving | `tip-stepca-health.ps1` | prints `ok` |
| Device listeners published | `tip-mtls-ports.ps1` | `1029=open` / `8883=open`, or `closed` when unpublished |
| Gateway after PKI | `health-build.ps1` with `-Build base-pki` | API `ok`, Envoy admin ready, step-ca `ok`, lab ports closed |

Device certificate enrollment and FIWARE edge proofs that need a second product are not in these scripts. When `:1029` is open, use the HTTP device-trust scenarios (S-75 through S-83) in [../SCENARIO-TESTING.md](../SCENARIO-TESTING.md).
