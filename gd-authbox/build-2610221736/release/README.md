# Auth-in-a-Box — three builds

This pack covers **three published builds**. Each build is a different installation: which containers are present, which host ports are open, and which checks apply. The builds share the same API image and the same realm. They do not share the same listening surface.

| Build | What is installed | Host ports that matter |
|---|---|---|
| **Base** | Postgres, Keycloak, authbox-api, Envoy | API `:8000`, Keycloak `:8080`, gateway `:9000`, admin `:9901`, Postgres `:5433` |
| **Base Secure** | Same containers; lab API and Keycloak ports unpublished | Gateway `:9000`, admin `:9901`, Postgres `:5433` |
| **Base PKI** | Base Secure plus step-ca | Same as Base Secure; step-ca only inside its container (internal `:9000`, not the host gateway) |

On **Base PKI**: step-ca is always present; device mTLS `:1029` and MQTT `:8883` are this pack’s device edge (confirm after start — see [USER-GUIDE.md](USER-GUIDE.md) §5.5.8). Tips: [helpers/README.md](helpers/README.md).

The documents link only inside `release/`. Helper scripts live in [helpers/](helpers/). They set the build variables and run health checks. They do not print secret values.

| File | What it is |
|---|---|
| [USER-GUIDE.md](USER-GUIDE.md) | End-user guide: stack pieces → packs → choose → install & run → operate |
| [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md) | Layout, claims, routes, status codes, build listening matrix |
| [SCENARIO-TESTING.md](SCENARIO-TESTING.md) | Progressive pass: Base → Base Secure → Base PKI (S-01…S-85 plus B-01…B-06) |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | What this edition answers for the three builds |
| [helpers/README.md](helpers/README.md) | Quick start scripts: set build, health, step-ca, mTLS port tips |

Call the HTTP API with **curl.exe** or **Postman**. The recorded pass is **Windows PowerShell 5.1 or PowerShell 7**. In PowerShell the name `curl` is an alias for `Invoke-WebRequest`, so the REST examples use `curl.exe`. A call that sends a secret uses `curl.exe --config` on a UTF-8 file with no byte-order mark. The file uses the environment names below. It does not contain a copied secret from this page.

Postman is not one of the released images. Install it yourself. Keycloak, Postgres, Envoy, and step-ca stay upstream images. The API image this product builds is tagged locally as `gd-authbox-dev:latest` (or the short tag from a handoff load). The Markdown and [helpers/](helpers/) in this pack are separate files the reader downloads — they are not layers inside that API image.

## Choose one build per session

Set `$Build` once. Pasting another build later changes which ports and components the later calls expect. Changing the running installation replaces that set. A short-lived check container is not that change.

```powershell
# Base — direct Keycloak/API ports and gateway both usable
$Build = "base"; $KC = "http://localhost:8080"; $API = "http://localhost:8000"
```

```powershell
# Base Secure or Base PKI — gateway only
$Build = "base-secure"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
# $Build = "base-pki"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

Or run [helpers/set-build.ps1](helpers/set-build.ps1). The issuer on the API must match `$KC` (`…/realms/nexus-test`).

## What each build contains

| Component | Base | Base Secure | Base PKI |
|---|---|---|---|
| Postgres (`authbox_lab`, host `:5433`) | yes | yes | yes |
| Keycloak (realm `nexus-test`) | yes (host `:8080`) | yes (host unpublished) | yes (host unpublished) |
| authbox-api (`gd-authbox-dev:latest`) | yes (host `:8000`) | yes (host unpublished) | yes (host unpublished) |
| Envoy gateway `:9000` / admin `:9901` | yes | yes | yes |
| step-ca | no | no | yes |
| Device `:1029` / MQTT `:8883` | no | no | yes when device edge enabled |

Defaults, health commands, and usage for each component are in [USER-GUIDE.md](USER-GUIDE.md). Contracts are in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). The progressive pass is [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

## Names you set before the first call

These documents name environment variables. They do not contain the values.

| Name | What it is |
|---|---|
| `NEXUS_AUTH_CLIENT_ID` | Password-grant client id |
| `NEXUS_AUTH_CLIENT_SECRET` | Password-grant client secret |
| `NEXUS_SIMULATOR_M2M_CLIENT_ID` | Machine client id |
| `NEXUS_AUTH_M2M_CLIENT_SECRET` | Machine client secret |
| `AUTHBOX_USER_A` | Password-grant user whose claim `tid` is `tenant_a` |
| `AUTHBOX_USER_A_PASSWORD` | Password for that user |
| `AUTHBOX_USER_B` | Password-grant user whose claim `tid` is `tenant_b` |
| `AUTHBOX_USER_B_PASSWORD` | Password for that user |
| `NEXUS_SIMULATOR_KEYCLOAK_USER` / `…_PASSWORD` | Same person as `AUTHBOX_USER_A` in the downloadable pack `.env` (alias before token calls — see [USER-GUIDE.md](USER-GUIDE.md) §5.2.6) |
| `NEXUS_SIMULATOR_TENANT_B_USER` / `…_PASSWORD` | Same person as `AUTHBOX_USER_B` in the downloadable pack `.env` |
| `AUTHBOX_EDGE_USER` | Edge user with role `operator`. The password is `AUTHBOX_EDGE_PASSWORD`. Username alone is `401` |
| `AUTHBOX_EDGE_PROTECTED_USER` | Edge user with role `reader` |
| `AUTHBOX_EDGE_PASSWORD` | Password for `AUTHBOX_EDGE_USER` and for `AUTHBOX_EDGE_PROTECTED_USER` |
| `KEYCLOAK_ADMIN` | Admin user already set inside the Keycloak container |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password already set inside the Keycloak container |
| `POSTGRES_USER` | Database user already set inside the Postgres container |
| `POSTGRES_PASSWORD` | Database password already set inside the Postgres container |
| `POSTGRES_DB` | Database name already set inside the Postgres container (`authbox_lab` on these builds) |
| `NEXUS_SIMULATOR_TOTP_SECRET` | One-time secret already set inside the API container |

A new PowerShell window has none of the scenario variables and no result list. Paste from [SCENARIO-TESTING.md](SCENARIO-TESTING.md) setup downward in one session, or dot-source a helper then continue.

## Editions in this image

| Piece | Edition |
|---|---|
| API image | Handoff: `gd-authbox:2.1.0` · Checkout lab: `gd-authbox-dev:latest` |
| Package `gd-authbox` | 2.1.0 |
| `nexus-auth` | 4.0.0 |
| `nexus-common` | 3.4.0 |
| Keycloak | `quay.io/keycloak/keycloak:24.0` |
| Postgres | `postgres:16-alpine` |
| Envoy | `envoyproxy/envoy:v1.30-latest` |
| step-ca (Base PKI) | `smallstep/step-ca:latest` |
| `GET /authbox/` field `version` | `7.0.0` |

Container names are `auth-sandbox-<service>-1`.
