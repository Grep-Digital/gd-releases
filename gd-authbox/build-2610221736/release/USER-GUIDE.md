# Auth-in-a-Box — every service, explained

What each container is, what it gives you, and how to call it.

HTTP examples are shown three ways: **curl.exe**, **Postman**, and **Windows PowerShell 5.1 or PowerShell 7**. PowerShell commands are a single line. In PowerShell the name `curl` is an alias for `Invoke-WebRequest`, so the REST examples use `curl.exe`.

Plain blocks are things you **run**. Indented, quoted blocks are the **response** you should get back.

```powershell
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
```

> ```
> /var/run/postgresql:5432 - accepting connections
> ```

Commands name the **access path**. Set it once per session from the compose mode you launched. The contract for claims, routes, and status codes is [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). The full pass is [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

| Access | Compose mode | Keycloak `$KC` | API `$API` |
|---|---|---|---|
| **Direct** | `base`, `min`, `dev`, `dev-pki` | `http://localhost:8080` | `http://localhost:8000` |
| **Gateway** | `dev-secure`, any `-WithFiwareLink` | `http://localhost:9000` | `http://localhost:9000` |

`dev` and `dev-pki` publish both access paths. `dev-secure` and a start with `-WithFiwareLink` publish gateway access and leave host ports 8000 and 8080 unpublished.

```powershell
$Access = "direct"; $KC = "http://localhost:8080"; $API = "http://localhost:8000"
```

Gateway access. Launch with `up -Mode dev-secure`, or add `-WithFiwareLink`.

```powershell
$Access = "gateway"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

The issuer on the API must be the same host as `$KC`. Direct is `http://localhost:8080/realms/nexus-test`. Gateway is `http://localhost:9000/realms/nexus-test`.

## Calling the API

Use the same host for the token and for the API call.

| Client | Direct access | Gateway access |
|---|---|---|
| PowerShell | `$API = "http://localhost:8000"` and `$KC = "http://localhost:8080"` | both variables `http://localhost:9000` |
| curl.exe | `curl.exe -sS "http://localhost:8000/authbox/health"` | `curl.exe -sS "http://localhost:9000/authbox/health"` |
| Postman | environment `api` = `http://localhost:8000`, `keycloak` = `http://localhost:8080` | both `http://localhost:9000` |

A bearer call in the three forms:

```powershell
curl.exe -sS "$API/authbox/default/default/api/v1/verifier/evaluate" -H "Authorization: Bearer $TokenA"
```

```powershell
Invoke-RestMethod -Uri "$API/authbox/default/default/api/v1/verifier/evaluate" -Headers @{ Authorization = "Bearer $TokenA" }
```

Postman: `GET {{api}}/authbox/default/default/api/v1/verifier/evaluate`, Authorization type Bearer, token `{{token_a}}`.

Compose project name is **`auth-sandbox`**. Container names are `auth-sandbox-<service>-1`.

---

## Contents

### Part I — The services

| Service | What you can do there |
|---|---|
| [1. Postgres](#1-postgres) | see the realm, the users, and the stored attributes |
| [2. Keycloak](#2-keycloak) | mint a token and read claim `tid` |
| [3. authbox-api](#3-authbox-api) | call health, authorize, evaluate, and the scenario routes |
| [4. Envoy](#4-envoy) | use gateway access and read a `401` |
| [5. step-ca](#5-step-ca) | ask the CA whether it is serving |
| [6. Caddy](#6-caddy-on-prem-edge) | the HTTPS edge on-prem |

### Part II — The platform

| Section | Covers |
|---|---|
| [7. Modes and access paths](#7-modes-and-access-paths) | which containers each mode runs, and the start command |
| [8. How the services fit together](#8-how-the-services-fit-together) | Postgres, Keycloak, the API, and Envoy |
| [9. Cross-service reference](#9-cross-service-reference) | names, lab credentials, health |
| [10. End-to-end verification](#10-end-to-end-verification) | the scenario pass |
| [Appendix A](#appendix-a--where-things-are-defined) | where each thing is defined |

---

# Part I — The services

## 1. Postgres

### 1.1 What it is

A single PostgreSQL 16 instance. Its client is Keycloak. Realms, users, clients, and sessions survive a container restart because they live here.

The API does not open a database connection. URL tenants created through the admin API live in the API process. Audit is written to the API log and to `/var/log/authbox/sandbox.csv`.

Keycloak waits until `pg_isready` succeeds, then runs its own schema migration.

### 1.2 What it provides

- Durable storage for the realm `nexus-test`.
- One lab database, `authbox_lab`, on volume `pgdata_lab`, for every `sandbox-ctl` lab mode.
- A separate on-prem database, `authbox_production`, on volume `pgdata_onprem`.
- Host port `5433` on lab modes.

### 1.3 What you can achieve

| Goal | Task |
|---|---|
| See that Postgres is accepting connections | [1.5.1](#151-readiness) |
| List realms and users | [1.5.2](#152-realms-and-users) |
| Read stored attributes | [1.5.3](#153-stored-attributes) |

### 1.4 Configuration

```text
image: postgres:16-alpine
POSTGRES_USER: nexus
POSTGRES_PASSWORD: nexus_lab
POSTGRES_DB: authbox_lab
ports: 5433:5432
volume: pgdata_lab
healthcheck: pg_isready -U nexus -d authbox_lab
```

`down` leaves `pgdata_lab` in place. `down-volumes` deletes it.

### 1.5 Tasks

**1.5.1 Readiness**

```powershell
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
```

> ```
> /var/run/postgresql:5432 - accepting connections
> ```

**1.5.2 Realms and users**

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT name FROM realm ORDER BY name;"
```

The list includes `nexus-test` and `master`.

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT username FROM user_entity WHERE realm_id = (SELECT id FROM realm WHERE name = 'nexus-test') ORDER BY username;"
```

The list includes `testuser`, `tenant_b_user`, `iot-operator`, and `iot-device`.

**1.5.3 Stored attributes**

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT u.username, ua.name, ua.value FROM user_attribute ua JOIN user_entity u ON u.id = ua.user_id WHERE u.username IN ('testuser','tenant_b_user') ORDER BY u.username, ua.name;"
```

`testuser` has attribute `tenant_id` = `tenant_a` and `clearance` = `high`. `tenant_b_user` has attribute `tenant_id` = `tenant_b` and `clearance` = `low`. The access token spells the tenant value as claim `tid`.

### 1.6 Verify

```powershell
docker inspect auth-sandbox-postgres-1 --format "{{json .State.Health.Status}}"
```

> ```
> "healthy"
> ```

### 1.7 Gotchas

The healthcheck passes the database name. Without `-d`, the probe asks for a database named `nexus` and Postgres logs `FATAL` on every probe while still reporting healthy.

A recreate of the API does not wipe `pgdata_lab`. A recreate of Postgres uses the same volume, so the realm remains.

## 2. Keycloak

### 2.1 What it is

Keycloak 24 is the identity provider. It stores the realm in Postgres and mints access tokens. The lab realm is `nexus-test`.

### 2.2 What it provides

- Password grant for `testuser` and `tenant_b_user`.
- Client credentials for `nexus-m2m`.
- Browser login for `nexus-sandbox`, `iot-admin-app`, and `nodered`.
- Claim `tid` and, on the password-grant client, claim `roles`.

### 2.3 What you can achieve

| Goal | Task |
|---|---|
| Confirm discovery for this access path | [2.5.1](#251-discovery) |
| Mint a password-grant token and read `tid` | [2.5.2](#252-password-grant) |
| Mint a machine token | [2.5.3](#253-machine-token) |
| List clients from inside the container | [2.5.4](#254-clients) |

### 2.4 Configuration

| Setting | Value |
|---|---|
| Image | `quay.io/keycloak/keycloak:24.0` |
| Admin | `admin` / `admin` |
| Database URL | `jdbc:postgresql://postgres:5432/authbox_lab` |
| Direct port | `:8080` |
| Gateway port | `:9000` via Envoy, path `/realms/` |

The public issuer is the host in the access path you launched: port 8080 on direct access, port 9000 on gateway access. The browser and the API use that same host. Inside the network the API fetches keys from `http://keycloak:8080/realms/nexus-test/protocol/openid-connect/certs`.

### 2.5 Tasks

**2.5.1 Discovery**

```powershell
(Invoke-WebRequest -Uri "$KC/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing).StatusCode
```

> ```
> 200
> ```

```powershell
curl.exe -sS -o NUL -w "%{http_code}" "$KC/realms/nexus-test/.well-known/openid-configuration"
```

Postman: `GET {{keycloak}}/realms/nexus-test/.well-known/openid-configuration`.

**2.5.2 Password grant**

```powershell
$raw = Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=password&client_id=nexus-sandbox&client_secret=changeme&username=testuser&password=testpass"; $p = $raw.access_token.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json; "tid=$($c.tid) roles=$($c.roles -join ',')"
```

> ```
> tid=tenant_a roles=offline_access,admin,default-roles-nexus-test,uma_authorization,operator
> ```

Role order can differ. `admin` and `operator` are present. The claim list has `tid` and has no `tenant_id`.

```powershell
curl.exe -sS -X POST "$KC/realms/nexus-test/protocol/openid-connect/token" -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=password&client_id=nexus-sandbox&client_secret=changeme&username=testuser&password=testpass"
```

Postman: `POST {{keycloak}}/realms/nexus-test/protocol/openid-connect/token`, body type x-www-form-urlencoded, fields `grant_type=password`, `client_id=nexus-sandbox`, `client_secret=changeme`, `username=testuser`, `password=testpass`. Save `access_token` as `token_a`. The PowerShell line above is what prints claim `tid`.

**2.5.3 Machine token**

```powershell
$raw = Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=client_credentials&client_id=nexus-m2m&client_secret=changeme"; $p = $raw.access_token.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json; "tid=$($c.tid)"
```

> ```
> tid=tenant_a
> ```

```powershell
curl.exe -sS -X POST "$KC/realms/nexus-test/protocol/openid-connect/token" -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=client_credentials&client_id=nexus-m2m&client_secret=changeme"
```

Postman: same URL as the password grant, body `grant_type=client_credentials`, `client_id=nexus-m2m`, `client_secret=changeme`. Save `access_token` as `token_m`.

**2.5.4 Clients**

On gateway access, host `:8080` is unpublished. Run the admin CLI inside the container.

```powershell
docker exec auth-sandbox-keycloak-1 /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin
```

```powershell
docker exec auth-sandbox-keycloak-1 /opt/keycloak/bin/kcadm.sh get clients -r nexus-test --fields clientId
```

The list includes `nexus-sandbox`, `nexus-m2m`, `iot-admin-app`, and `nodered`. The credential command is needed again after the Keycloak container is recreated.

### 2.6 Verify

A password-grant token for `testuser` evaluates at the API. That check is [S-16](SCENARIO-TESTING.md) in the scenario pass.

### 2.7 Gotchas

Use `$KC` for the access path you launched. A token from `:8080` fails evaluation on an API whose issuer is `:9000`, and the reverse.

The gateway does not route `/admin/`. A call to `http://localhost:9000/admin/...` is an unrouted path. The status matrix is in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

## 3. authbox-api

### 3.1 What it is

The Auth-in-a-Box API is a FastAPI application. It verifies tokens through `nexus-auth` 4.0.0 and `nexus-common` 3.4.0, and it exposes the scenario routes under `/authbox/{tenant}/{instance}/api/v1/`.

The seeded URL tenant and instance are both `default`. That path is the sandbox path. Claim `tid` is independent of it: `testuser` evaluates on `/authbox/default/default/...` and the response field `tenant_id` is `default`, while the token claim `tid` is `tenant_a`.

### 3.2 What it provides

- `GET /authbox/health`.
- Authorize, callback, and token.
- `GET .../verifier/evaluate`.
- MFA enroll, challenge, and verify.
- Edge verify, FIWARE verify, IUDX verify, Aadhaar verify, wallet verify.
- MCP validate and config.
- Admin create of URL tenants and instances.
- Machine ping, device-trust register, get, suspend, and revoke, device anomaly, and token revoke. Those checks are S-75 through S-85 in [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

`GET /authbox/` on direct access returns `version` `7.0.0`.

### 3.3 What you can achieve

| Goal | Task |
|---|---|
| Health | [3.5.1](#351-health) |
| Build a login URL | [3.5.2](#352-authorize) |
| Evaluate a token | [3.5.3](#353-evaluate) |
| Run every scenario | [SCENARIO-TESTING.md](SCENARIO-TESTING.md) |

### 3.4 Configuration

| Setting | Value |
|---|---|
| Image | `gd-authbox-dev:latest` |
| Package | `gd-authbox` 2.1.0 |
| Listen | `:8000` inside the container |
| Audience | `account` |
| HTTP sandbox | allowed, so authorize includes `_sandbox_code_verifier` |
| Manifest | `/app/tests/simulator/assets/discovery.json` |
| Continuous verify | on, session max age 30 minutes, state in the API process |

The program is copied into the image. After a change to `src/`, rebuild the image and recreate `authbox-api`. Restarting the old container runs the previous program. Seed runs from the entrypoint once Keycloak answers.

### 3.5 Tasks

**3.5.1 Health**

```powershell
Invoke-RestMethod "$API/authbox/health"
```

> ```
> status
> ------
> ok
> ```

```powershell
curl.exe -sS "$API/authbox/health"
```

Postman: `GET {{api}}/authbox/health`.

**3.5.2 Authorize**

```powershell
$auth = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize?state=doc-state"; "state=$($auth.state) verifier_len=$($auth._sandbox_code_verifier.Length)"
```

> ```
> state=doc-state verifier_len=43
> ```

The length is at least 43. `url` is a Keycloak authorization URL on `$KC`.

```powershell
curl.exe -sS "$API/authbox/default/default/api/v1/auth/authorize?state=doc-state"
```

Postman: `GET {{api}}/authbox/default/default/api/v1/auth/authorize?state=doc-state`.

**3.5.3 Evaluate**

Mint `$TokenA` with the password grant in [2.5.2](#252-password-grant), then:

```powershell
$ev = Invoke-RestMethod -Uri "$API/authbox/default/default/api/v1/verifier/evaluate" -Headers @{ Authorization = "Bearer $($raw.access_token)" }; "status=$($ev.status) tenant_id=$($ev.tenant_id) instance_id=$($ev.instance_id)"
```

> ```
> status=success tenant_id=default instance_id=default
> ```

`subject_id` is the token subject. `roles` includes `admin` and `operator`.

```powershell
curl.exe -sS "$API/authbox/default/default/api/v1/verifier/evaluate" -H "Authorization: Bearer $TokenA"
```

Postman: `GET {{api}}/authbox/default/default/api/v1/verifier/evaluate`, Authorization Bearer `{{token_a}}`. Mint `$TokenA` with the password grant in [2.5.2](#252-password-grant) before the curl line. The PowerShell evaluate line above uses `$raw.access_token` from that same grant.

### 3.6 Verify

```powershell
docker inspect auth-sandbox-authbox-api-1 --format "{{.State.Health.Status}}"
```

> ```
> healthy
> ```

```powershell
docker exec auth-sandbox-authbox-api-1 python -c "import importlib.metadata as m; print(m.version('nexus-auth'), m.version('nexus-common'))"
```

> ```
> 4.0.0 3.4.0
> ```

### 3.7 Gotchas

Evaluation of a token with an empty `tid` returns `401` and `{"detail":"Missing or invalid token"}`.

FIWARE and IUDX headers without a bearer return that same `401`. The headers are correlation.

`required_role` is enforced after the caller is accepted. `testuser` does not have realm role `viewer`. `tenant_b_user` does. Edge user `airuser` has manifest role `operator`. Edge role `reader` is not a realm role.

Calls with no bearer, including edge verify, Aadhaar, and wallet, use direct access (API port 8000). On gateway access, Envoy answers `/authbox/` before the API when the JWT is missing.

## 4. Envoy

### 4.1 What it is

Envoy is the gateway. It publishes Keycloak under `/realms/` and the API under `/authbox/`. Linked mode also publishes `/orion/` and `/iotagent/`.

### 4.2 What it provides

- One host port, `:9000`, for gateway access.
- JWT checks on `/authbox/`, `/orion/`, and `/iotagent/`.
- Envoy admin on `:9901`.
- Device mTLS on `:1029` when the FIWARE link overlay is up, and MQTT on `:8883`.

### 4.3 What you can achieve

| Goal | Task |
|---|---|
| See the gateway ready | [4.6.1](#461-ready) |
| Open discovery through the gateway | [4.6.2](#462-realms) |

### 4.4 Configuration

Routes are in `deploy/edge/envoy/envoy.yaml`. The secure overlay hides host `:8000` and `:8080`.

### 4.5 The filter chain

A request to a protected prefix hits the JWT filter, then the API. A request to any other prefix hits ext-authz, then the catch-all.

| What you sent | What you get |
|---|---|
| Protected path, no token | plain-text `401` `Jwt is missing` |
| Protected path, valid token, unknown API route | JSON `404` `{"detail":"Not Found"}` |
| Unrouted path, no token | JSON `403` |
| Unrouted path, valid token | plain-text `404` naming `/authbox/`, `/realms/`, `/orion/`, `/iotagent/` |

### 4.6 Tasks

**4.6.1 Ready**

```powershell
(Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode
```

> ```
> 200
> ```

```powershell
curl.exe -sS -o NUL -w "%{http_code}" "http://localhost:9901/ready"
```

**4.6.2 Realms**

```powershell
(Invoke-WebRequest -Uri "http://localhost:9000/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing).StatusCode
```

> ```
> 200
> ```

```powershell
curl.exe -sS -o NUL -w "%{http_code}" "http://localhost:9000/realms/nexus-test/.well-known/openid-configuration"
```

Postman: `GET http://localhost:9000/realms/nexus-test/.well-known/openid-configuration`.

### 4.7 Verify

Health of the API through the gateway, when that access path is the one you started:

```powershell
Invoke-RestMethod "http://localhost:9000/authbox/health"
```

> ```
> status
> ------
> ok
> ```

`/authbox/health` is served on the gateway. Routes that require a bearer still require one.

```powershell
curl.exe -sS "http://localhost:9000/authbox/health"
```

Postman: `GET http://localhost:9000/authbox/health`.

### 4.8 Gotchas

`/openapi.json` and `GET /authbox/` are read on direct access (API port 8000). The gateway does not treat `/openapi.json` as an API route.

Do not add a route for Keycloak `/admin/`.

## 5. step-ca

### 5.1 What it is

step-ca is the lab certificate authority. It is present when the stack is started with `-Mode dev-pki`. It listens on port `9000` inside its own container. That port is not the host's Envoy port `9000`.

### 5.2 What it provides

- A CA health check.
- Device certificates used by the Envoy `:1029` listener when devices are enrolled.

### 5.3 What you can achieve

| Goal | Task |
|---|---|
| See that the CA is serving | [5.5.1](#551-health) |

### 5.4 Configuration

The service is defined in `docker-compose.security.yaml`. The admin password file is mounted into the container and consumed as-is. The healthcheck runs `step ca health` against `https://localhost:9000` with the container's root certificate.

### 5.5 Tasks

**5.5.1 Health**

```powershell
docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

> ```
> ok
> ```

### 5.6 Verify

The container health status is `healthy` after the same probe succeeds.

### 5.7 Gotchas

`:9000` inside this container is step-ca. `:9000` on the host is Envoy. Certificate issue and revoke scripts live in `devx/pki/`. They talk to the CA in its container.

## 6. Caddy (on-prem edge)

### 6.1 What it is

On-prem, Caddy terminates HTTPS and forwards to Envoy. The lab modes in this guide do not start Caddy.

### 6.2 What it provides

- The HTTPS name used on the company LAN.
- The on-prem issuer host, which replaces `localhost` in the token issuer.

### 6.3 Configuration

`docker-compose.onprem.yaml` and `deploy/onprem/Caddyfile`. Postgres for that stack is `authbox_production` on `pgdata_onprem`.

### 6.4 What else changes on-prem

The database name, the volume, and the public issuer change. The claim name remains `tid`. The route shapes remain the shapes in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

### 6.5 Tasks

Bring-up is `.\devx\run-onprem-stack.ps1` from a checkout that has the on-prem env file in place. Health is still `GET /authbox/health` on the on-prem API base URL.

### 6.6 Gotchas

Do not point an on-prem stack at `pgdata_lab`. The lab file `docker-compose.postgres-lab.yaml` is for lab modes.

---

# Part II — The platform

## 7. Modes and access paths

### 7.1 Which containers each mode runs

| Mode | Postgres | Keycloak | API | Envoy | step-ca |
|---|---|---|---|---|---|
| `base`, `min` | lab singleton when merged | yes | yes | no | no |
| `dev` | `authbox_lab` | yes | yes | yes | no |
| `dev-secure` | `authbox_lab` | yes | yes | yes | no |
| `dev-pki` | `authbox_lab` | yes | yes | yes | yes |
| `dev-pki -WithFiwareLink` | `authbox_lab` | yes | yes | yes, plus `:1029` | yes |

`base` and `min` can run Keycloak on embedded H2 when the Postgres fragment is not merged. `sandbox-ctl` lab modes merge `authbox_lab`.

### 7.2 Which ports each mode opens

| Mode | API | Keycloak | Envoy | Postgres | Envoy admin |
|---|---|---|---|---|---|
| `dev`, `dev-pki` | `:8000` | `:8080` | `:9000` | `:5433` | `:9901` |
| `dev-secure`, FIWARE link | unpublished | unpublished | `:9000` | `:5433` | `:9901` |

FIWARE link also publishes `:1029` and `:8883` on localhost.

### 7.3 Choosing a mode

Use `dev` when you want direct access and the gateway access together. Use `dev-secure` when callers should use `:9000` only. Add `-Mode dev-pki` when you want step-ca. Add `-WithFiwareLink` when Orion and the IoT agent are linked and device mTLS is on `:1029`.

### 7.4 Commands for each mode

```powershell
.\devx\sandbox-ctl.ps1 up -Mode dev
```

```powershell
.\devx\sandbox-ctl.ps1 up -Mode dev-secure
```

```powershell
.\devx\sandbox-ctl.ps1 up -Mode dev-pki
```

```powershell
.\devx\sandbox-ctl.ps1 up -Mode dev-pki -WithFiwareLink
```

The files that command reads are listed in [README.md](README.md). They are part of the repository clone. Private wheels in `dist/` and lab certificates are not in the clone.

## 8. How the services fit together

The block diagram of these paths is in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

### 8.1 How Keycloak stores data in Postgres

Keycloak owns the schema. User attributes, including `tenant_id` and `clearance`, are rows in `user_attribute`. Roles are a separate mapping. The API never reads these tables.

### 8.2 How authbox-api works with Keycloak

The browser login URL is built from the public issuer (`localhost` on the access path you launched). The API fetches signing keys from Keycloak inside the Docker network. Evaluate checks the token, requires claim `tid`, and returns the URL tenant in field `tenant_id`.

Password grant and client credentials can be taken directly from Keycloak at `$KC/realms/nexus-test/protocol/openid-connect/token`, or through `POST .../auth/token` for client credentials and authorization-code exchange.

### 8.3 What Envoy fronts

Envoy forwards `/realms/` to Keycloak and `/authbox/` to the API. JWT on `/authbox/` is Envoy's check. The API still checks the token and the claim `tid`. Both can return `401`. The body tells them apart: plain text is Envoy, JSON is the API.

## 9. Cross-service reference

### 9.1 Container names

| Service | Container |
|---|---|
| Postgres | `auth-sandbox-postgres-1` |
| Keycloak | `auth-sandbox-keycloak-1` |
| API | `auth-sandbox-authbox-api-1` |
| Envoy | `auth-sandbox-envoy-1` |
| step-ca | `auth-sandbox-step-ca-1` |

### 9.2 Default credentials (lab only)

| Use | Value |
|---|---|
| Postgres | `nexus` / `nexus_lab`, database `authbox_lab` |
| Keycloak admin | `admin` / `admin` |
| Client `nexus-sandbox` | `changeme` |
| Client `nexus-m2m` | `changeme` |
| `testuser` | `testpass`, attribute `tenant_id=tenant_a`, roles `admin` and `operator` |
| `tenant_b_user` | `testpass`, attribute `tenant_id=tenant_b`, role `viewer` |
| `iot-operator` | `operator123` |
| `iot-device` | `device123` |
| Edge `airuser` | no password, role `operator` |
| Edge `airuser_protected` | `airpass`, role `reader` |

### 9.3 Health checks

| Check | Command |
|---|---|
| Postgres | `docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab` |
| API | `Invoke-RestMethod "$API/authbox/health"` |
| Keycloak | `Invoke-WebRequest "$KC/realms/nexus-test/.well-known/openid-configuration"` |
| Envoy | `Invoke-WebRequest http://localhost:9901/ready` |
| step-ca | the command in [5.5.1](#551-health) |

## 10. End-to-end verification

Run [SCENARIO-TESTING.md](SCENARIO-TESTING.md) in the same session after `$Access`, `$KC`, and `$API` above are set. Each group in that file has the call flow, then the same call in curl.exe and Postman, then the PowerShell line. Each scenario prints `PASS` or `FAIL`. Checks that need direct access print `SKIP` when `$Access` is `gateway`. The pass is S-01 through S-85, plus S-29b.

One failure line means that layer. A JSON `401` on evaluate with a fresh password-grant token means the token issuer and `NEXUS_AUTH_ISSUER` disagree, or claim `tid` is absent. A plain-text `401` means Envoy rejected the JWT before the API.

## Appendix A — Where things are defined

| Thing | Defined in |
|---|---|
| Lab Postgres | `docker-compose.postgres-lab.yaml` |
| Keycloak, API, Envoy | `docker-compose.dev.yaml` |
| gateway access | `docker-compose.dev.secure.yaml` |
| step-ca | `docker-compose.security.yaml` |
| Device mTLS publish | `docker-compose.fiware-link.yaml` |
| On-prem and Caddy | `docker-compose.onprem.yaml`, `deploy/onprem/Caddyfile` |
| Realm and claim mappers | `src/seed_data.py` |
| Routes | `src/routes/` |
| Gateway routes | `deploy/edge/envoy/envoy.yaml` |
| Edge users | image path `/app/tests/simulator/assets/discovery.json` |
| Mode bring-up | `devx/sandbox-ctl.ps1` |

Related pages in this pack: [README.md](README.md), [RELEASE-NOTES.md](RELEASE-NOTES.md), [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md), [SCENARIO-TESTING.md](SCENARIO-TESTING.md).
