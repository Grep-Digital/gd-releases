# Auth-in-a-Box — this edition

Facts about the running product. Procedures are in [USER-GUIDE.md](USER-GUIDE.md). Contracts are in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). The scenario pass is in [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

## Stack

| Piece | Value |
|---|---|
| API | FastAPI on Python 3.13, image `gd-authbox-dev:latest` |
| `gd-authbox` | 2.1.0 |
| `nexus-auth` | 4.0.0 |
| `nexus-common` | 3.4.0 |
| Keycloak | 24.0, realm `nexus-test` |
| Postgres | 16, database `authbox_lab`, volume `pgdata_lab`, host port `5433` |
| Gateway | Envoy on `:9000`, admin `:9901` |
| Device mTLS | Envoy `:1029` when the FIWARE link overlay is up |
| step-ca | Inside the compose network on `:9000` when `-Mode dev-pki` is up |
| Index `GET /authbox/` | `version` `7.0.0` |

On-prem uses database `authbox_production` and volume `pgdata_onprem`, with Caddy as the HTTPS edge. It does not share `pgdata_lab`.

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
| Health | `GET /authbox/health` | `200` `{"status":"ok"}` |
| Authorize | `GET .../auth/authorize` | `200`, field `url`, and `_sandbox_code_verifier` while HTTP sandbox is allowed |
| Callback | `GET .../auth/callback` | `200` when `code` is present, `400` when `code` is absent or `error` is set |
| Token | `POST .../auth/token` | Client-credentials tokens, and authorization-code exchange with the verifier from authorize. A form with no `grant_type` returns `422`. `grant_type=authorization_code` with no `code` returns `400` |
| Evaluate | `GET .../verifier/evaluate` | `200` for a token with `tid`; `401` with no bearer or a bad bearer; `403` when `required_role` is absent |
| MFA | `POST .../mfa/enroll`, `/challenge`, `/verify` | Enroll returns `secret`. Challenge plus verify with that secret returns `valid: true` |
| One-time code helper | `POST .../control/v1/mocks/generate-otp` | Direct access (API port 8000). `generate`, `code`, and `verify` |
| Machine tokens | `POST .../auth/token` `grant_type=client_credentials` | `200` for `nexus-sandbox` and for `nexus-m2m`; `401` for a wrong secret; `400` for blank credentials |
| Air-gap | `POST .../auth/edge/verify` | Direct access (API port 8000). `X-Username: airuser` returns `200` and role `operator`. `airuser_protected` with `X-Password: airpass` returns `200` and role `reader` |
| FIWARE | `POST .../auth/fiware/verify` | Headers alone return `401`. A bearer with `tid` returns `200`. `required_role=viewer` succeeds for `tenant_b_user` and fails for `testuser` |
| IUDX | `POST .../auth/iudx/verify` | Headers alone return `401`. After a bearer, `X-Iudx-Consent-Id` and `X-Iudx-Catalogue-Access` are copied onto the response. An artefact body does not set the consent id |
| Aadhaar | `POST .../auth/aadhaar/verify` | No `X-Aadhaar-Xml` returns `401`. XML with no UIDAI key configured returns `501` |
| Wallet | `POST .../auth/wallet/verify` | No wallet headers returns `501`. A verifiable presentation with a proof returns `200`. Invalid JSON returns `400`. A presentation without `proof` returns `401` |
| MCP | `POST .../mcp/validate`, `GET .../mcp/config` | No bearer returns `401`. `testuser` config returns `200`. `tenant_b_user` config returns `403` |
| URL tenants | `POST /authbox/admin/v1/tenants` and `.../instances` | Evaluate on `/authbox/org-a/dev/...` returns those URL fields. The same for `org-b` / `staging` |
| Login | authorize, then a password-grant token or an authorization-code exchange | Evaluate returns `200` |
| Machine ping | `GET .../auth/m2m/ping` | Bearer returns `200` `status` `ok`. No bearer returns `401` |
| Device trust | `POST .../auth/device-trust/register`, get, suspend, revoke | `testuser` registers `sensor-doc-1` as `trusted`. Suspend returns `suspended`. Revoke returns an empty `trust_level`. `ttl_sec` of 0 returns `400` |
| Device anomaly | `POST .../auth/fiware/device-anomaly` | Action `suspend` returns `200`. Any other action returns `400` |
| Token revoke | `POST .../auth/token/revoke` | Wrong `nexus-m2m` secret returns `401` and the token still pings. `changeme` returns `status` `revoked`, and the next ping is `401` |

FIWARE headers (`Fiware-Service`, `X-Fiware-Subject`, `X-Fiware-Roles`) and IUDX headers are correlation. They do not authenticate the caller. `X-Fiware-Roles` does not grant `required_role`.

## Lab directory

Realm `nexus-test`. Password-grant client `nexus-sandbox` / `changeme`. Machine client `nexus-m2m` / `changeme`. Users `testuser` / `testpass` and `tenant_b_user` / `testpass`. Browser clients `iot-admin-app` and `nodered` exist for those UIs. Realm roles are `admin`, `operator`, `viewer`, `device`, `config_read`, `data_scientist`. Air-gap role `reader` exists on the edge manifest, not as a realm role.

Seed runs from the API container entrypoint after Keycloak is up. The API image contains the seed program. A change to that program is in effect after the image is rebuilt and `authbox-api` is recreated. `pgdata_lab` keeps the realm across that recreate.
