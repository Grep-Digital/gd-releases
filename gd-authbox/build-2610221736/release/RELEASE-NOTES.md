# Auth-in-a-Box — this edition

This edition publishes **three builds**, not one runtime. Procedures are in [USER-GUIDE.md](USER-GUIDE.md). Contracts are in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). The progressive scenario pass is in [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Quick helpers: [helpers/README.md](helpers/README.md). Index: [README.md](README.md).

## Three builds

| Build | What is installed | Host ports | Issuer the API expects |
|---|---|---|---|
| **Base** | Postgres, Keycloak, authbox-api, Envoy | `:8080`, `:8000`, `:9000`, `:9901`, Postgres `:5433` | `http://localhost:8080/realms/nexus-test` |
| **Base Secure** | Same containers; lab API and Keycloak ports unpublished | `:9000`, `:9901`, Postgres `:5433` | `http://localhost:9000/realms/nexus-test` |
| **Base PKI** | Base Secure plus step-ca | Same as Base Secure; step-ca only inside its container | `http://localhost:9000/realms/nexus-test` |

Optional on **Base PKI** only: device mTLS `:1029` and MQTT `:8883` when those listeners are published. That overlay is not a fourth build.

| Topic | Where it is covered |
|---|---|
| Start / stop / Docker options per build | [USER-GUIDE.md](USER-GUIDE.md) — Starting each build |
| Contents, defaults, health, usage per component | [USER-GUIDE.md](USER-GUIDE.md) |
| Listening matrix, claims, routes, status codes | [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md) |
| Progressive scenarios Base → Secure → PKI (S-* and B-*) | [SCENARIO-TESTING.md](SCENARIO-TESTING.md) |
| Cert / mTLS quick tips | [USER-GUIDE.md](USER-GUIDE.md) §11, [helpers/](helpers/) |

## Manual verification (operator)

Run against containers that are already up for each installed build. Do not wipe `pgdata_lab`.

| Pass | Build | What to run | Expect |
|---|---|---|---|
| M-1 | Base | `bring-up`/`sandbox-ctl` up `-Package`/`-Mode` `base`; then `. .\helpers\set-build.ps1 -Build base`; `. .\helpers\health-build.ps1` | Lab ports open; health PASS |
| M-2 | Base | [SCENARIO-TESTING.md](SCENARIO-TESTING.md) S-01…S-85 (+ S-29b) with `$Access` `direct`; B-01 | S-* SKIP count 0; B-02…B-06 SKIP |
| M-3 | Base Secure | Install `base-secure`; remint tokens; set-build `base-secure`; health-build | Lab `:8000`/`:8080` closed; gateway health ok |
| M-4 | Base Secure | Re-run bearer groups + B-02, B-03; direct-only ids SKIP | B-01 and B-04…B-06 SKIP |
| M-5 | Base PKI | Install `base-pki`; set-build `base-pki`; health-build; tip-stepca-health | step-ca `ok`; gateway still healthy |
| M-6 | Base PKI | B-03…B-06; tip-mtls-ports; device-trust S-75…S-83 | B-05 may report ports closed if device listeners unpublished |
| M-7 | Optional device link | `base-pki -WithFiwareLink`; tip-mtls-ports | `:1029` / `:8883` open when published |

Offline/live ladder proofs (checkout): `tests/test_package_ladder_combos.py` and `devx/verify/run-package-ladder-live.ps1` (`down` only). Those are not the adopter scenario paste.

## Stack

| Piece | Value |
|---|---|
| API | FastAPI on Python 3.13, image `gd-authbox-dev:latest` |
| `gd-authbox` | 2.1.0 |
| `nexus-auth` | 4.0.0 |
| `nexus-common` | 3.4.0 |
| Keycloak | 24.0, realm `nexus-test` |
| Postgres | 16, database `authbox_lab`, volume `pgdata_lab`, host port `5433` |
| Gateway | Envoy on `:9000`, admin `:9901` (all three builds) |
| Device mTLS | Envoy `:1029` when that listener is published on Base PKI |
| step-ca | Port 9000 inside its container on Base PKI only |
| Index `GET /authbox/` | `version` `7.0.0` (direct / Base) |

On-prem uses database `authbox_production` and volume `pgdata_onprem`, with Caddy as the HTTPS edge. It is outside these three lab builds and does not share `pgdata_lab`.

## Identity

The sandbox URL is `/authbox/default/default/api/v1/`. The word `default` in that path is the URL tenant and the URL instance.

Access tokens carry claim `tid`. The user record stores attribute `tenant_id`. The password-grant client maps that attribute onto claim `tid`.

| Caller | How the token is minted | `tid` | `roles` |
|---|---|---|---|
| `testuser` | Password grant, client `nexus-sandbox` | `tenant_a` | includes `admin` and `operator` |
| `tenant_b_user` | Password grant, client `nexus-sandbox` | `tenant_b` | includes `viewer` |
| `nexus-m2m` | Client credentials | `tenant_a` | realm roles stay under `realm_access` |

Claim `roles` on the password-grant token is the list FIWARE role checks read. `realm_access.roles` is also present. A missing `tid` claim is rejected.

`GET .../verifier/evaluate` returns `tenant_id` and `instance_id` from the URL, and `subject_id` and `roles` from the token.

## What the API answers

| Area | Path | Result on this edition |
|---|---|---|
| Health | `GET /authbox/health` | `200` `{"status":"ok"}` on every build's `$API` |
| Authorize | `GET .../auth/authorize` | `200`, field `url`, and `_sandbox_code_verifier` while HTTP sandbox is allowed |
| Callback | `GET .../auth/callback` | `200` when `code` is present, `400` when `code` is absent or `error` is set |
| Token | `POST .../auth/token` | Client-credentials tokens, and authorization-code exchange with the verifier from authorize. A form with no `grant_type` returns `422`. `grant_type=authorization_code` with no `code` returns `400` |
| Evaluate | `GET .../verifier/evaluate` | `200` for a token with `tid`; `401` with no bearer or a bad bearer; `403` when `required_role` is absent. On Base Secure / Base PKI a missing bearer is Envoy plain-text `Jwt is missing` |
| MFA | `POST .../mfa/enroll`, `/challenge`, `/verify` | Enroll returns `secret`. Challenge plus verify with that secret returns `valid: true` |
| One-time code helper | `POST .../control/v1/mocks/generate-otp` | **Base** (API port 8000). `generate`, `code`, and `verify`. Gateway builds `SKIP` |
| Machine tokens | `POST .../auth/token` `grant_type=client_credentials` | `200` for `nexus-sandbox` and for `nexus-m2m`; `401` for a wrong secret; `400` for blank credentials |
| Air-gap | `POST .../auth/edge/verify` | **Base** (API port 8000). `AUTHBOX_EDGE_USER` with no password returns `401`. The same user with `AUTHBOX_EDGE_PASSWORD` and role `operator` returns `200`. `AUTHBOX_EDGE_PROTECTED_USER` with that password returns `200` and role `reader`. Gateway builds `SKIP` |
| FIWARE | `POST .../auth/fiware/verify` | Headers alone return `401` on Base; Envoy `Jwt is missing` on gateway. A bearer with `tid` returns `200`. `required_role=viewer` succeeds for `tenant_b_user` and fails for `testuser` |
| IUDX | `POST .../auth/iudx/verify` | Headers alone return `401` (or Envoy on gateway). After a bearer, `X-Iudx-Consent-Id` and `X-Iudx-Catalogue-Access` are copied onto the response. An artefact body does not set the consent id |
| Aadhaar | `POST .../auth/aadhaar/verify` | **Base**. No `X-Aadhaar-Xml` returns `401`. XML with no UIDAI key configured returns `501` |
| Wallet | `POST .../auth/wallet/verify` | **Base**. No wallet headers returns `501`. A verifiable presentation with a proof returns `200`. Invalid JSON returns `400`. A presentation without `proof` returns `401` |
| MCP | `POST .../mcp/validate`, `GET .../mcp/config` | No bearer returns `401` (or Envoy on gateway). `testuser` config returns `200`. `tenant_b_user` config returns `403` |
| URL tenants | `POST /authbox/admin/v1/tenants` and `.../instances` | Evaluate on `/authbox/org-a/dev/...` returns those URL fields. The same for `org-b` / `staging` |
| Login | authorize, then a password-grant token or an authorization-code exchange | Evaluate returns `200`. Authorization-code browser exchange is **Base** (S-74) |
| Machine ping | `GET .../auth/m2m/ping` | Bearer returns `200` `status` `ok`. No bearer returns `401` (or Envoy on gateway) |
| Device trust | `POST .../auth/device-trust/register`, get, suspend, revoke | All builds with a bearer. `testuser` registers `sensor-doc-1` as `trusted`. Suspend returns `suspended`. Revoke returns an empty `trust_level`. `ttl_sec` of 0 returns `400`. Emphasized on Base PKI with B-06 |
| Device anomaly | `POST .../auth/fiware/device-anomaly` | Action `suspend` returns `200`. Any other action returns `400` |
| Token revoke | `POST .../auth/token/revoke` | A wrong machine-client secret returns `401` and the token still pings. `NEXUS_AUTH_M2M_CLIENT_SECRET` returns `status` `revoked`, and the next ping is `401` |
| step-ca | inside `auth-sandbox-step-ca-1` | **Base PKI** only. Health `ok` (B-04 / tip script) |

FIWARE headers (`Fiware-Service`, `X-Fiware-Subject`, `X-Fiware-Roles`) and IUDX headers are correlation. They do not authenticate the caller. `X-Fiware-Roles` does not grant `required_role`.

## Lab directory

Realm `nexus-test`. Password-grant client id is `NEXUS_AUTH_CLIENT_ID`. Machine client id is `NEXUS_SIMULATOR_M2M_CLIENT_ID`. The two password-grant users are `AUTHBOX_USER_A` and `AUTHBOX_USER_B`. Browser clients `iot-admin-app` and `nodered` exist for those UIs. They are not released images. Realm roles are `admin`, `operator`, `viewer`, `device`, `config_read`, `data_scientist`. Air-gap role `reader` exists on the edge manifest, not as a realm role. Secret values are the environment names in [README.md](README.md).
