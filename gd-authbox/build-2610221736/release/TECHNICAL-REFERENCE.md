# Auth-in-a-Box — technical reference

Contracts for the **three builds** described in [USER-GUIDE.md](USER-GUIDE.md) and [README.md](README.md). The progressive pass is [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Quick tips: [helpers/README.md](helpers/README.md).

The API prefix below is `/authbox/{tenant}/{instance}/api/v1`. The seeded path is `/authbox/default/default/api/v1`.

## Three builds (listening matrix)

Containers for one build are already running. Changing the installed build replaces that set. A short-lived check container is not that change.

| Build | `$Build` | Host `:8080` / `:8000` | Gateway `:9000` / admin `:9901` | step-ca | Device `:1029` / `:8883` |
|---|---|---|---|---|---|
| **Base** | `base` | published | published | absent | absent |
| **Base Secure** | `base-secure` | unpublished | published | absent | absent |
| **Base PKI** | `base-pki` | unpublished | published | present | optional when published |

| Build | Components present | Default issuer the API expects |
|---|---|---|
| Base | Postgres, Keycloak, authbox-api, Envoy | `http://localhost:8080/realms/nexus-test` (gateway also open) |
| Base Secure | Same containers; lab ports unpublished | `http://localhost:9000/realms/nexus-test` |
| Base PKI | Base Secure + step-ca | `http://localhost:9000/realms/nexus-test` |

Postgres on every lab build: database `authbox_lab`, volume `pgdata_lab`, host `:5433`. Inside the network Keycloak uses `postgres:5432`. Defaults and health: [USER-GUIDE.md](USER-GUIDE.md) §1–§5 and §9.

## Layout

```mermaid
flowchart TB
  subgraph callers [Callers]
    ps[PowerShell]
    curl[curl.exe]
    postman[Postman]
    device[Device client]
  end

  subgraph basePorts [Base host ports 8000 and 8080]
    apiHost["API host port 8000"]
    kcHost["Keycloak host port 8080"]
  end

  subgraph edge [All builds: gateway port 9000]
    caddy[Caddy HTTPS on-prem]
    envoy["Envoy host port 9000"]
    admin["Envoy admin port 9901"]
    mtls["Device mTLS port 1029"]
  end

  subgraph net [Running containers]
    api["authbox-api container port 8000"]
    kc["Keycloak 24 realm nexus-test"]
    pg[("Postgres 16 authbox_lab volume pgdata_lab")]
    ca["step-ca on Base PKI container port 9000"]
  end

  ps --> apiHost
  ps --> kcHost
  curl --> apiHost
  curl --> kcHost
  postman --> apiHost
  postman --> kcHost
  ps --> envoy
  curl --> envoy
  postman --> envoy
  device --> mtls
  caddy --> envoy
  apiHost --> api
  kcHost --> kc
  envoy -->|"/authbox/ JWT then API"| api
  envoy -->|"/realms/"| kc
  mtls --> envoy
  admin --> envoy
  api -->|"JWKS and token at keycloak:8080"| kc
  kc -->|"realms users clients sessions"| pg
  ca -->|"device certificates"| envoy
```

**Base** calls the API on port 8000 and Keycloak on port 8080. Host port 9000 is also open. **Base Secure** and **Base PKI** call both on port 9000; host ports 8000 and 8080 are unpublished. Setting `$Build` / `$Access` in the session does not start containers and does not replace the running set.

Envoy forwards `/authbox/` to the API and `/realms/` to Keycloak. On `/authbox/`, `/orion/`, and `/iotagent/` Envoy checks the JWT before the API sees the call. A missing JWT is plain text `Jwt is missing`. A JSON `401` `{"detail":"Missing or invalid token"}` is the API. Keycloak `/admin/` is not routed. Use `kcadm.sh` inside `auth-sandbox-keycloak-1`.

On-prem, Caddy terminates HTTPS and forwards to Envoy. That stack uses database `authbox_production` and volume `pgdata_onprem`. It is outside the three lab builds. The API does not open a database connection. step-ca listens on port 9000 inside its container. That port is not host Envoy port 9000.

## Access paths by build

| Build | `$Access` | Keycloak base `$KC` | API base `$API` | Token issuer |
|---|---|---|---|---|
| Base | `direct` | `http://localhost:8080` | `http://localhost:8000` | `http://localhost:8080/realms/nexus-test` |
| Base Secure | `gateway` | `http://localhost:9000` | `http://localhost:9000` | `http://localhost:9000/realms/nexus-test` |
| Base PKI | `gateway` | `http://localhost:9000` | `http://localhost:9000` | `http://localhost:9000/realms/nexus-test` |

| Build | Host ports that matter |
|---|---|
| Base | Keycloak `:8080`, API `:8000`, gateway `:9000`, admin `:9901`, Postgres `:5433` |
| Base Secure | `:9000`, `:9901`, Postgres `:5433`. Host `:8000` and `:8080` unpublished |
| Base PKI | Same as Base Secure, plus step-ca inside its container. Device `:1029` / MQTT `:8883` when those listeners are published |
| Production-shaped (not a lab build) | HTTPS in front of the gateway. Database `authbox_production` |

## Claims

| Name | Where it lives | Value on this edition |
|---|---|---|
| `tid` | Access token | `tenant_a` for `testuser` and `nexus-m2m`. `tenant_b` for `tenant_b_user` |
| `tenant_id` | User attribute in Postgres | Same values as `tid`. It is not the access-token claim name |
| `roles` | Access token, password grant | Realm roles for that user. FIWARE `required_role` reads this claim |
| `realm_access.roles` | Access token | Keycloak's own role object |
| `clearance` | Access token, from the user attribute | `high` for `testuser`, `low` for `tenant_b_user` |
| `fiware_service`, `fiware_servicepath`, `fiware_tenant` | Access token, from user attributes | Present on `testuser` |

`GET .../verifier/evaluate` response fields:

| Field | Source |
|---|---|
| `status` | `success` when the token is accepted |
| `subject_id` | Token subject |
| `roles` | Token roles |
| `tenant_id` | `{tenant}` in the URL |
| `instance_id` | `{instance}` in the URL |

A token whose `tid` claim is empty is rejected with `401` and body `{"detail":"Missing or invalid token"}`.

## Callers

| Name | Secret or password | Grant | Realm roles |
|---|---|---|---|
| `NEXUS_AUTH_CLIENT_ID` | `NEXUS_AUTH_CLIENT_SECRET` | Authorization code and password | — |
| `NEXUS_SIMULATOR_M2M_CLIENT_ID` | `NEXUS_AUTH_M2M_CLIENT_SECRET` | Client credentials | service account |
| Client `iot-admin-app` | `NEXUS_AUTH_CLIENT_SECRET` | Browser login | — |
| Client `nodered` | `NEXUS_AUTH_CLIENT_SECRET` | Browser login | — |
| `AUTHBOX_USER_A` | `AUTHBOX_USER_A_PASSWORD` | Password | `admin`, `operator` |
| `AUTHBOX_USER_B` | `AUTHBOX_USER_B_PASSWORD` | Password | `viewer` |
| IoT operator user | `NEXUS_SIMULATOR_IOT_OPERATOR_PASSWORD` | Password | `operator` |
| IoT device user | `NEXUS_SIMULATOR_IOT_DEVICE_PASSWORD` | Password | `device` |
| `AUTHBOX_EDGE_USER` | `AUTHBOX_EDGE_PASSWORD` | `X-Username` and `X-Password` on edge verify. Username alone is `401` | manifest role `operator` |
| `AUTHBOX_EDGE_PROTECTED_USER` | `AUTHBOX_EDGE_PASSWORD` | `X-Username` and `X-Password` | manifest role `reader` |

Realm role names: `admin`, `operator`, `viewer`, `device`, `config_read`, `data_scientist`. `reader` is an edge-manifest role.

Keycloak admin commands run inside `auth-sandbox-keycloak-1` and read `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` from that container. The gateway does not publish `/admin/`.

## Routes

| Method and path | Auth | Success |
|---|---|---|
| `GET /authbox/health` | none | `200` `{"status":"ok"}` |
| `GET /authbox/` | none on direct access | `200`, `version` `7.0.0` |
| `GET /openapi.json` | none on direct access | `200` OpenAPI document |
| `GET .../auth/authorize` | none | `200` `url`, `state`, `_sandbox_code_verifier`, `_sandbox_note` |
| `GET .../auth/callback?code=` | none | `200`, `next_step` contains `/auth/token` |
| `GET .../auth/callback` | none | `400` when `code` is absent |
| `GET .../auth/callback?error=access_denied` | none | `400`, detail contains `access_denied` |
| `POST .../auth/token` | form body | `200` `access_token`, `token_type` `Bearer` |
| `POST .../auth/token` with no `grant_type` | form body | `422` |
| `POST .../auth/token` `grant_type=authorization_code` and no `code` | form body | `400` |
| `GET .../verifier/evaluate` | `Authorization: Bearer` | `200` as in the claims table |
| `POST .../mfa/enroll` | Bearer | `200` `secret` |
| `POST .../mfa/challenge` | Bearer, form `secret` | `200` `code` |
| `POST .../mfa/verify` | Bearer, form `secret` and `verify_code` | `200` `valid` |
| `POST .../control/v1/mocks/generate-otp` | none, direct access | form `mode` of `generate`, `code`, or `verify` |
| `POST .../auth/edge/verify` | `X-Username` and `X-Password` | `200` `status` `success`. Username alone is `401` |
| `POST .../auth/fiware/verify` | Bearer, optional correlation headers | `200` `status` `success` |
| `POST .../auth/iudx/verify` | Bearer, optional correlation headers | `200`, copies consent id and catalogue access |
| `POST .../auth/aadhaar/verify` | `X-Aadhaar-Xml` | `501` while no UIDAI key is configured |
| `POST .../auth/wallet/verify` | `X-Vp` | `200` for a presentation that includes `proof` |
| `POST .../mcp/validate` | Bearer | `200` `status` `success` |
| `GET .../mcp/config` | Bearer with `admin`, `operator`, or `config_read` | `200` for `testuser`, `403` for `tenant_b_user` |
| `POST /authbox/admin/v1/tenants` | Bearer | creates a URL tenant |
| `POST /authbox/admin/v1/tenants/{tenant}/instances` | Bearer | creates a URL instance |

The numbered pass in [SCENARIO-TESTING.md](SCENARIO-TESTING.md) calls every row above, and S-75 through S-85 call the routes in the next table.

| Method and path | Auth | Success body |
|---|---|---|
| `POST .../auth/token/revoke` | form `token`, `client_id`, `client_secret` | `status` `revoked`. Wrong client is `401`. Missing fields are `400` |
| `GET .../auth/m2m/ping` | Bearer | `status` `ok`. No bearer is `401` |
| `POST .../auth/device-trust/register` | Bearer with role `admin` or `operator` | JSON `device_id`, `trust_level`, `ttl_sec`. `ttl_sec` of 0 is `400` |
| `GET .../auth/device-trust/{device_id}` | Bearer with role `admin` or `operator` | `trust_level` |
| `POST .../auth/device-trust/suspend` | Bearer with role `admin` or `operator` | `trust_level` `suspended` |
| `POST .../auth/device-trust/revoke` | Bearer with role `admin` or `operator` | `trust_level` empty |
| `POST .../auth/fiware/device-anomaly` | Bearer with role `admin` or `operator` | JSON `action` of `suspend` or `revoke`. Any other action is `400` |

`required_role` is a query parameter on evaluate, edge verify, and FIWARE verify. The role must be on the token or the edge manifest. A missing role is `403` after the caller has been accepted. An unknown caller is `401`.

## FIWARE and IUDX headers

| Header | Effect |
|---|---|
| `Fiware-Service` | Copied as correlation on a successful FIWARE verify |
| `X-Fiware-Subject` | Correlation. It does not become `subject_id` |
| `X-Fiware-Roles` | Correlation. It does not satisfy `required_role` |
| `X-Iudx-Consent-Id` | Copied to `iudx_consent_id` after the bearer is accepted |
| `X-Iudx-Catalogue-Access` | Copied to `iudx_catalogue_access` after the bearer is accepted |
| `X-Consent-Artefact` | Ignored. It does not set `iudx_consent_id` |

The same `401` body is returned when those headers arrive without a bearer.

## Wallet and Aadhaar bodies

Aadhaar accepts header `X-Aadhaar-Xml`. Header `X-Aadhaar-Otp` alone returns `401`. XML while no UIDAI public key is configured returns `501`.

Wallet header `X-Vp` is a JSON verifiable presentation. These fields are required for `200`: `type` including `VerifiablePresentation`, `holder`, `verifiableCredential`, and `proof`. The response `subject_id` contains `did:key:`. The response `tenant_id` is the URL tenant (`default` on the seeded path). No wallet header returns `501`. Invalid JSON returns `400`. A presentation without `proof` returns `401`.

## Status codes

On direct access the API answers. On gateway access, Envoy's JWT filter runs first on `/authbox/`, `/orion/`, and `/iotagent/`.

| Path | Credential | Status | Body | Produced by |
|---|---|---|---|---|
| Routed and protected | none | `401` | `Jwt is missing` | Envoy |
| Routed and protected | bad signature or audience | `401` | `Jwt verification fails` | Envoy |
| Routed and protected | valid token, no such route | `404` | `{"detail":"Not Found"}` | API |
| Unrouted | none | `403` | `{"detail":"missing bearer token"}` | API ext-authz |
| Unrouted | token the API rejects | `401` | `{"detail":"Missing or invalid token"}` | API ext-authz |
| Unrouted | valid token | `404` | `Auth-Box gateway - use /authbox/, /realms/, /orion/, or /iotagent/` | Envoy |
| API, no bearer | none | `401` | `{"detail":"Missing or invalid token"}` | API |
| API, accepted caller, role missing | Bearer or edge user | `403` | forbidden | API |
| API, form missing `grant_type` | token form | `422` | validation error | API |
| API, authorization code grant with no `code` | form `grant_type=authorization_code` | `400` | `'code' is required` | API |

A plain-text `401` is Envoy. A JSON `401` is the API. The two `404` bodies distinguish an unrouted gateway path from a path that reached the API.

Gateway prefixes are `/authbox/`, `/realms/`, `/orion/`, and `/iotagent/`. Keycloak `/admin/` is not one of them. Admin commands run with `kcadm.sh` inside `auth-sandbox-keycloak-1`.

## Token endpoint forms

Password grant, sent to `$KC/realms/nexus-test/protocol/openid-connect/token`:

```text
grant_type=password, client_id from NEXUS_AUTH_CLIENT_ID, client_secret from NEXUS_AUTH_CLIENT_SECRET, username from AUTHBOX_USER_A, password from AUTHBOX_USER_A_PASSWORD
```

Client credentials, same URL:

```text
grant_type=client_credentials, client_id from NEXUS_SIMULATOR_M2M_CLIENT_ID, client_secret from NEXUS_AUTH_M2M_CLIENT_SECRET
```

API token, `POST $API/authbox/default/default/api/v1/auth/token`:

| `grant_type` | Fields |
|---|---|
| `client_credentials` | `client_id` and `client_secret`. An omitted field uses `NEXUS_AUTH_CLIENT_ID` and `NEXUS_AUTH_CLIENT_SECRET` already set in the API process. If either is empty, the response is `400` and the detail is `client_id and client_secret are required` |
| `authorization_code` | `code`, `code_verifier`, `redirect_uri` |

## Environment on `authbox-api`

| Variable | Base | Base Secure / Base PKI |
|---|---|---|
| `NEXUS_AUTH_ISSUER` | `http://localhost:8080/realms/nexus-test` | `http://localhost:9000/realms/nexus-test` |
| `NEXUS_AUTH_INTERNAL_ISSUER` | `http://keycloak:8080/realms/nexus-test` | same |
| `NEXUS_AUTH_FIWARE_JWKS_URL` | `http://keycloak:8080/realms/nexus-test/protocol/openid-connect/certs` | same |
| `NEXUS_AUTH_CLIENT_ID` | set in the container | same |
| `NEXUS_AUTH_CLIENT_SECRET` | set in the container | same |
| `NEXUS_AUTH_AUDIENCE` | `account` | same |
| `NEXUS_AUTH_M2M_CLIENT_SECRET` | set in the container | same |
| `NEXUS_AUTH_ALLOW_HTTP_SANDBOX` | `true` | `true` |
| `NEXUS_AUTH_ROLE_CLAIM` | `realm_access` | same |
| `NEXUS_SIMULATOR_TOTP_SECRET` | set in the container | same |
| `NEXUS_AUTH_CONTINUOUS_VERIFY` | `true` | same |
| `NEXUS_AUTH_SESSION_MAX_AGE_MINUTES` | `30` | same |

The tenant claim name the API reads is `tid`.

If any of these is empty inside the API container, seed stops and the API process does not stay up: `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `NEXUS_AUTH_CLIENT_SECRET`, `NEXUS_AUTH_M2M_CLIENT_SECRET`, `NEXUS_SIMULATOR_KEYCLOAK_PASSWORD`, `NEXUS_SIMULATOR_TENANT_B_PASSWORD`, `NEXUS_SIMULATOR_IOT_OPERATOR_PASSWORD`, `NEXUS_SIMULATOR_IOT_DEVICE_PASSWORD`. The scenario names `AUTHBOX_USER_A_PASSWORD`, `AUTHBOX_USER_B_PASSWORD`, and `AUTHBOX_EDGE_PASSWORD` are the caller's copies of those values. The image does not invent a value when one of the container variables is empty.

## How long state lasts

These lists are inside the API process. Replacing that container clears them. The numbered pass does not request a device certificate, so it does not depend on certificate lifetime.

| State | How long it lasts | After it ends |
|---|---|---|
| Continuous-verify session | 30 minutes (`NEXUS_AUTH_SESSION_MAX_AGE_MINUTES`) | The numbered pass does not wait out that window |
| Device trust from register | `ttl_sec` seconds. The default is 86400. `ttl_sec` of 0 is `400` with detail `ttl_sec must be > 0` | `GET .../auth/device-trust/{device_id}` returns `200` and `trust_level` is empty |
| Device trust from suspend | Until revoke, or until the API process is replaced | `trust_level` is `suspended` while the entry remains |
| Revoked-token list | Until the access token's expiry. A token with no expiry stays on the list for 3600 seconds | While the entry remains, `GET .../auth/m2m/ping` is `401` and the detail is `token_revoked`. After the entry is gone, that detail is not returned for this reason |

## Data and networks

| Item | Lab builds (all three) | On-prem |
|---|---|---|
| Database | `authbox_lab` | `authbox_production` |
| Volume | `pgdata_lab` | `pgdata_onprem` |
| User / password | `POSTGRES_USER` / `POSTGRES_PASSWORD` | `POSTGRES_USER` / `POSTGRES_PASSWORD` |
| Healthcheck | `pg_isready -U nexus -d authbox_lab` | `pg_isready` with `authbox_production` |

| Network | Who is on it |
|---|---|
| `public-net` | Postgres, Keycloak, API, Envoy |
| `auth-internal` | Keycloak, API, Envoy |
| `airgap-net` | API |

The API has no Postgres connection. Realms, users, clients, and sessions are Keycloak's tables. Audit goes to the API log and to `/var/log/authbox/sandbox.csv`. Continuous-verification session state is inside the API process. Session max age is 30 minutes.

## Images

This pack describes the API image `gd-authbox-dev:latest`. Keycloak `quay.io/keycloak/keycloak:24.0` and Postgres `postgres:16-alpine` stay upstream. A browser UI is not one of these images. **Base** publishes ports 8000 and 8080 (and gateway 9000). **Base Secure** and **Base PKI** publish gateway 9000 only. Device mTLS on port 1029 is present only when that listener is already published on Base PKI. Starters: [helpers/README.md](helpers/README.md).
