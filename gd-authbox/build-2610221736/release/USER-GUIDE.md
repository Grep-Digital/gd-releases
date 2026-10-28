# Auth-in-a-Box — every service, explained

What each **build** installs, what each container is, the defaults it ships with, how to health-check it, and how to call it.

HTTP examples are shown three ways: **curl.exe**, **Postman**, and **Windows PowerShell 5.1 or PowerShell 7**. PowerShell commands are a single line. In PowerShell the name `curl` is an alias for `Invoke-WebRequest`, so the REST examples use `curl.exe`.

Plain blocks are things you **run**. Indented, quoted blocks are the **response** you should get back.

```powershell
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
```

> ```
> /var/run/postgresql:5432 - accepting connections
> ```

There are **three builds**. Choose one per session. The contract for claims, routes, and status codes is [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). The progressive pass is [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Quick scripts: [helpers/README.md](helpers/README.md). Index: [README.md](README.md).

## Three builds

| Build | `$Build` | `$KC` / `$API` | Present |
|---|---|---|---|
| **Base** | `base` | `http://localhost:8080` / `http://localhost:8000` (gateway `:9000` also open) | Postgres, Keycloak, API, Envoy |
| **Base Secure** | `base-secure` | both `http://localhost:9000` | Same; host `:8080`/`:8000` unpublished |
| **Base PKI** | `base-pki` | both `http://localhost:9000` | Base Secure + step-ca (+ optional device `:1029`/`:8883`) |

```powershell
$Build = "base"; $KC = "http://localhost:8080"; $API = "http://localhost:8000"
```

```powershell
$Build = "base-secure"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

```powershell
$Build = "base-pki"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

The issuer on the API must be the same host as `$KC`. Base uses `http://localhost:8080/realms/nexus-test`. Base Secure and Base PKI use `http://localhost:9000/realms/nexus-test`.

### Build matrix — defaults that matter

| Setting | Base | Base Secure | Base PKI |
|---|---|---|---|
| Postgres DB name | `authbox_lab` | `authbox_lab` | `authbox_lab` |
| Postgres host port | `5433` | `5433` | `5433` |
| Keycloak realm | `nexus-test` | `nexus-test` | `nexus-test` |
| Public issuer host | `:8080` (lab) | `:9000` (gateway) | `:9000` (gateway) |
| API redirect / gateway URL | may use lab or gateway | gateway `:9000` | gateway `:9000` |
| step-ca | absent | absent | present (container-only `:9000`) |
| Device listeners | absent | absent | optional when published |

Environment **names** (not values) are in [README.md](README.md). Component defaults and health are under each service below and in [§9](#9-cross-service-reference).

### Per-build health (first check)

| Build | Minimum health |
|---|---|
| Base | Postgres `pg_isready`; `GET http://localhost:8000/authbox/health`; Keycloak discovery on `:8080`; Envoy `http://localhost:9901/ready`; optional `GET http://localhost:9000/authbox/health` |
| Base Secure | Postgres; `GET http://localhost:9000/authbox/health`; Envoy admin `:9901/ready`; TCP to `:8000`/`:8080` must fail |
| Base PKI | Same as Base Secure, plus [§5.5.1](#551-health) step-ca `ok` |

Or run [helpers/health-build.ps1](helpers/health-build.ps1) after [helpers/set-build.ps1](helpers/set-build.ps1).

## Starting each build

Yes — start, stop, and Docker options for each build live in this guide. The API image alone (`docker run` of `gd-authbox-dev:latest`) is not a supported install: the process waits for Keycloak on the compose network. Use one of the three builds below.

### Prerequisites

- Docker Engine with Compose v2
- Windows PowerShell 5.1 / PowerShell 7, or bash
- This product checkout (compose files and the lab controller ship with the clone; they are not inside `release/`)
- A repo-root `.env` whose **names** match [README.md](README.md). Do not paste secret values into this guide. Copy from `.env.example` when `.env` is missing, then set the secrets yourself

Optional: set `SANDBOX_IMAGE` to a published API tag (for example a GHCR build) before start. When unset, the compose file uses the local image name `gd-authbox-dev:latest`.

### What each start brings up

| Build | Compose overlays (in order) | Containers | Host ports after start |
|---|---|---|---|
| **Base** | lab Postgres + `docker-compose.dev.yaml` | Postgres, Keycloak, authbox-api, Envoy | `:8080`, `:8000`, `:9000`, `:9901`, Postgres `:5433` |
| **Base Secure** | Base + `docker-compose.dev.secure.yaml` | Same four | `:9000`, `:9901`, Postgres `:5433` (lab `:8080`/`:8000` unpublished) |
| **Base PKI** | Base Secure + `docker-compose.security.yaml` | Same four + step-ca | Same as Base Secure; step-ca only inside its container |
| **Base PKI + device link** | Base PKI + FIWARE device listeners | Same as Base PKI | Also `:1029` (mTLS) and `:8883` (MQTT) when that option is used |

Changing build replaces that set. Do not use `down-volumes` / `-Volumes` unless you intend to wipe `pgdata_lab` (the realm).

### Preferred start — bring-up kit

From the checkout `bring-up/` folder:

```powershell
cd bring-up
.\configure.ps1
# Edit repo-root .env — set secret values for the names in README.md
.\start.ps1 -Package base
.\start.ps1 -Package base-secure
.\start.ps1 -Package base-pki
.\start.ps1 -Package base-pki -WithFiwareLink
.\stop.ps1 -Package base          # same -Package you started; volumes kept
# .\stop.ps1 -Package base -Volumes   # destructive: removes pgdata_lab
```

```bash
cd bring-up
./configure.sh
# Edit repo-root .env
./start.sh --package base
./start.sh --package base-secure
./start.sh --package base-pki
./start.sh --package base-pki --with-fiware-link
./stop.sh --package base
```

`configure` checks Docker and creates `.env` from `.env.example` when missing. It does not start containers and does not print secrets.

Published API image example:

```powershell
$env:SANDBOX_IMAGE = "ghcr.io/grep-digital/gd-authbox:build-N"
.\start.ps1 -Package base-pki
```

### Lab controller — same builds

The bring-up scripts call `devx/sandbox-ctl`. From the repo root:

| Command | Meaning |
|---|---|
| `.\devx\sandbox-ctl.ps1 up -Mode base` | Start **Base** |
| `.\devx\sandbox-ctl.ps1 up -Mode base-secure` | Start **Base Secure** |
| `.\devx\sandbox-ctl.ps1 up -Mode base-pki` | Start **Base PKI** |
| `.\devx\sandbox-ctl.ps1 up -Mode base-pki -WithFiwareLink` | Base PKI + device `:1029` / `:8883` |
| `.\devx\sandbox-ctl.ps1 status -Mode base-secure` | Show container/health for that mode |
| `.\devx\sandbox-ctl.ps1 down -Mode base` | Stop; **keep** volumes |
| `.\devx\sandbox-ctl.ps1 down-volumes -Mode base` | Stop and **remove** volumes including `pgdata_lab` |

Bash: `./devx/sandbox-ctl.sh` with the same verbs and `--mode` / `--with-fiware-link`.

### Docker / controller options

| Option | Where | Meaning |
|---|---|---|
| `-Package` / `--package` | bring-up `start` / `stop` | `base` \| `base-secure` \| `base-pki` |
| `-Mode` / `--mode` | `sandbox-ctl` | Same three names |
| `-Timeout` / `--timeout` | both (ctl; bring-up passes through) | Readiness wait **15–600** s (ctl default **60**; bring-up start default **180**) |
| `-Interval` / `--interval` | `sandbox-ctl` | Poll every **1–30** s (default **2**) |
| `-WithFiwareLink` / `--with-fiware-link` | both | Device listeners; **requires** Base PKI |
| `-Volumes` / `down-volumes` | stop / ctl | Destructive volume wipe |
| `SANDBOX_IMAGE` | environment before start | Override API image tag |
| `COMPOSE_HTTP_TIMEOUT` / `DOCKER_CLIENT_TIMEOUT` | environment | Compose/Docker client waits (ctl sets **120** when unset) |

Deprecated mode aliases (`core*`, `dev*`, `dist`, `min`) still resolve on the controller but print DEPRECATED. Prefer `base` / `base-secure` / `base-pki`.

### Useful Docker commands after start

Container names are `auth-sandbox-<service>-1`.

```powershell
docker ps --filter "name=auth-sandbox-"
docker inspect auth-sandbox-authbox-api-1 --format "{{.State.Health.Status}}"
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
docker logs --tail 80 auth-sandbox-authbox-api-1
docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

After the build is up, set session hosts with [helpers/set-build.ps1](helpers/set-build.ps1), confirm with [helpers/health-build.ps1](helpers/health-build.ps1), then continue from [Calling the API](#calling-the-api) and [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

## Calling the API

Use the same host for the token and for the API call. On **Base**, both lab and gateway hosts work when those ports are open. On **Base Secure** and **Base PKI**, use the gateway host only.

| Client | Base (lab ports) | Base Secure / Base PKI |
|---|---|---|
| PowerShell | `$API = "http://localhost:8000"` and `$KC = "http://localhost:8080"` | both `http://localhost:9000` |
| curl.exe | `curl.exe -sS "http://localhost:8000/authbox/health"` | `curl.exe -sS "http://localhost:9000/authbox/health"` |
| Postman | `api` = `:8000`, `keycloak` = `:8080` | both `:9000` |

A bearer call in the three forms:

```powershell
curl.exe -sS "$API/authbox/default/default/api/v1/verifier/evaluate" -H "Authorization: Bearer $TokenA"
```

```powershell
Invoke-RestMethod -Uri "$API/authbox/default/default/api/v1/verifier/evaluate" -Headers @{ Authorization = "Bearer $TokenA" }
```

Postman: `GET {{api}}/authbox/default/default/api/v1/verifier/evaluate`, Authorization type Bearer, token `{{token_a}}`.

Container names are `auth-sandbox-<service>-1`.

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
| [Starting each build](#starting-each-build) | prerequisites, Docker options, start/stop per build |
| [7. Ports by build](#7-ports-by-build) | which ports each build publishes |
| [8. How the services fit together](#8-how-the-services-fit-together) | Postgres, Keycloak, the API, and Envoy |
| [9. Cross-service reference](#9-cross-service-reference) | container names, environment names, health by build |
| [10. End-to-end verification](#10-end-to-end-verification) | progressive scenario pass |
| [11. Quick tips — certs and mTLS](#11-quick-tips--certs-and-mtls) | Base PKI helpers |
| [Appendix A](#appendix-a--running-containers) | containers by build |

---

# Part I — The services

## 1. Postgres

Builds: **Base**, **Base Secure**, **Base PKI** (all three).

### 1.1 What it is

A single PostgreSQL 16 instance. Its client is Keycloak. Realms, users, clients, and sessions survive a container restart because they live here.

The API does not open a database connection. URL tenants created through the admin API live in the API process. Audit is written to the API log and to `/var/log/authbox/sandbox.csv`.

Keycloak waits until `pg_isready` succeeds, then runs its own schema migration.

### 1.2 What it provides

- Durable storage for the realm `nexus-test`.
- One lab database, `authbox_lab`, on volume `pgdata_lab`, whenever the lab containers are the ones running.
- A separate on-prem database, `authbox_production`, on volume `pgdata_onprem`, when that deployment is the one running.
- Host port `5433` when the lab database publishes it.

### 1.3 What you can achieve

| Goal | Task |
|---|---|
| See that Postgres is accepting connections | [1.5.1](#151-readiness) |
| List realms and users | [1.5.2](#152-realms-and-users) |
| Read stored attributes | [1.5.3](#153-stored-attributes) |

### 1.4 Configuration

```text
image: postgres:16-alpine
POSTGRES_USER: already set in the container
POSTGRES_PASSWORD: already set in the container
POSTGRES_DB: authbox_lab on the lab containers
ports: 5433:5432
volume: pgdata_lab
healthcheck: pg_isready -U nexus -d authbox_lab
```

Replacing the Postgres container keeps the volume `pgdata_lab`. Deleting that volume deletes the realm.

### 1.5 Tasks

#### 1.5.1 Readiness

```powershell
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
```

> ```
> /var/run/postgresql:5432 - accepting connections
> ```

#### 1.5.2 Realms and users

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT name FROM realm ORDER BY name;"
```

The list includes `nexus-test` and `master`.

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT username FROM user_entity WHERE realm_id = (SELECT id FROM realm WHERE name = 'nexus-test') ORDER BY username;"
```

The list includes `testuser`, `tenant_b_user`, `iot-operator`, and `iot-device`.

#### 1.5.3 Stored attributes

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

Builds: **Base** (host `:8080`), **Base Secure** / **Base PKI** (gateway `:9000` only).

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
| Admin | `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD`, already set inside the Keycloak container |
| Database URL | `jdbc:postgresql://postgres:5432/authbox_lab` |
| Direct port | `:8080` |
| Gateway port | `:9000` via Envoy, path `/realms/` |

The public issuer is the host for the build: port 8080 on Base, port 9000 on Base Secure and Base PKI. The browser and the API use that same host. Inside the network the API fetches keys from `http://keycloak:8080/realms/nexus-test/protocol/openid-connect/certs`.

### 2.5 Tasks

#### 2.5.1 Discovery

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

#### 2.5.2 Password grant

```powershell
$raw = Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=password&client_id=nexus-sandbox&client_secret=$env:NEXUS_AUTH_CLIENT_SECRET&username=$env:AUTHBOX_USER_A&password=$env:AUTHBOX_USER_A_PASSWORD"; $p = $raw.access_token.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json; "tid=$($c.tid) roles=$($c.roles -join ',')"
```

> ```
> tid=tenant_a roles=offline_access,admin,default-roles-nexus-test,uma_authorization,operator
> ```

Role order can differ. `admin` and `operator` are present. The claim list has `tid` and has no `tenant_id`.

Write the form body to a UTF-8 file with no byte-order mark. The secret fields are `NEXUS_AUTH_CLIENT_SECRET`, `AUTHBOX_USER_A`, and `AUTHBOX_USER_A_PASSWORD`. Then `curl.exe --config` that file. Do not put those values on the `curl.exe` command line.

Postman: `POST {{keycloak}}/realms/nexus-test/protocol/openid-connect/token`, body type x-www-form-urlencoded. The secret fields are the Postman variables `NEXUS_AUTH_CLIENT_SECRET`, `AUTHBOX_USER_A`, and `AUTHBOX_USER_A_PASSWORD`. Save `access_token` as `token_a`. The PowerShell line above is what prints claim `tid`.

#### 2.5.3 Machine token

```powershell
$raw = Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=client_credentials&client_id=$env:NEXUS_SIMULATOR_M2M_CLIENT_ID&client_secret=$env:NEXUS_AUTH_M2M_CLIENT_SECRET"; $p = $raw.access_token.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json; "tid=$($c.tid)"
```

> ```
> tid=tenant_a
> ```

Write the form body to a UTF-8 file with no byte-order mark. The secret field is `NEXUS_AUTH_M2M_CLIENT_SECRET`. Then `curl.exe --config` that file. Do not put that value on the `curl.exe` command line.

Postman: same URL as the password grant, body `grant_type=client_credentials`. The client id variable is `NEXUS_SIMULATOR_M2M_CLIENT_ID`. The secret variable is `NEXUS_AUTH_M2M_CLIENT_SECRET`. Save `access_token` as `token_m`.

#### 2.5.4 Clients
On gateway access, host `:8080` is unpublished. Run the admin CLI inside the container.

```powershell
docker exec auth-sandbox-keycloak-1 sh -c '/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD"'
```

```powershell
docker exec auth-sandbox-keycloak-1 /opt/keycloak/bin/kcadm.sh get clients -r nexus-test --fields clientId
```

The list includes `nexus-sandbox`, `nexus-m2m`, `iot-admin-app`, and `nodered`. The credential command is needed again after the Keycloak container is recreated.

### 2.6 Verify

A password-grant token for `testuser` evaluates at the API. That check is [S-16](SCENARIO-TESTING.md) in the scenario pass.

### 2.7 Gotchas

Use `$KC` for the switch you set. A token from `:8080` fails evaluation on an API whose issuer is `:9000`, and the reverse.

The gateway does not route `/admin/`. A call to `http://localhost:9000/admin/...` is an unrouted path. The status matrix is in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

## 3. authbox-api

Builds: **Base** (host `:8000`), **Base Secure** / **Base PKI** (gateway `:9000` only).

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

The program is already in the image. Seed has already run. Restarting the same container runs that same program.

If any of these is empty inside the API container, seed stops and the API process does not stay up: `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `NEXUS_AUTH_CLIENT_SECRET`, `NEXUS_AUTH_M2M_CLIENT_SECRET`, `NEXUS_SIMULATOR_KEYCLOAK_PASSWORD`, `NEXUS_SIMULATOR_TENANT_B_PASSWORD`, `NEXUS_SIMULATOR_IOT_OPERATOR_PASSWORD`, `NEXUS_SIMULATOR_IOT_DEVICE_PASSWORD`. The image does not invent a value. The caller names `AUTHBOX_USER_A_PASSWORD`, `AUTHBOX_USER_B_PASSWORD`, and `AUTHBOX_EDGE_PASSWORD` are copies of values already set in the containers.

### 3.5 Tasks

#### 3.5.1 Health

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

#### 3.5.2 Authorize

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

#### 3.5.3 Evaluate
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

`required_role` is enforced after the caller is accepted. `AUTHBOX_USER_A` does not have realm role `viewer`. `AUTHBOX_USER_B` does. `AUTHBOX_EDGE_USER` has manifest role `operator` and requires `AUTHBOX_EDGE_PASSWORD`. Username alone is `401`. Edge role `reader` is not a realm role.

Calls with no bearer, including edge verify, Aadhaar, and wallet, use direct access (API port 8000). On gateway access, Envoy answers `/authbox/` before the API when the JWT is missing.

## 4. Envoy

Builds: **Base**, **Base Secure**, **Base PKI** (all three). Device `:1029` / `:8883` optional on Base PKI.

### 4.1 What it is

Envoy is the gateway. It publishes Keycloak under `/realms/` and the API under `/authbox/`. When the device listener is published it also publishes `/orion/` and `/iotagent/`.

### 4.2 What it provides

- One host port, `:9000`, for gateway access.
- JWT checks on `/authbox/`, `/orion/`, and `/iotagent/`.
- Envoy admin on `:9901`.
- Device mTLS on `:1029` when that listener is published, and MQTT on `:8883`.

### 4.3 What you can achieve

| Goal | Task |
|---|---|
| See the gateway ready | [4.6.1](#461-ready) |
| Open discovery through the gateway | [4.6.2](#462-realms) |

### 4.4 Configuration

On Base Secure and Base PKI, host ports 8000 and 8080 are not published. The gateway answers on port 9000.

### 4.5 The filter chain

A request to a protected prefix hits the JWT filter, then the API. A request to any other prefix hits ext-authz, then the catch-all.

| What you sent | What you get |
|---|---|
| Protected path, no token | plain-text `401` `Jwt is missing` |
| Protected path, valid token, unknown API route | JSON `404` `{"detail":"Not Found"}` |
| Unrouted path, no token | JSON `403` |
| Unrouted path, valid token | plain-text `404` naming `/authbox/`, `/realms/`, `/orion/`, `/iotagent/` |

### 4.6 Tasks

#### 4.6.1 Ready

```powershell
(Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode
```

> ```
> 200
> ```

```powershell
curl.exe -sS -o NUL -w "%{http_code}" "http://localhost:9901/ready"
```

#### 4.6.2 Realms

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

Builds: **Base PKI** only.

### 5.1 What it is

step-ca is the certificate authority. It is present when the PKI container is already running. It listens on port `9000` inside its own container. That port is not the host's gateway port `9000`.

### 5.2 What it provides

- A CA health check.
- Device certificates used by the Envoy `:1029` listener when devices are enrolled.

### 5.3 What you can achieve

| Goal | Task |
|---|---|
| See that the CA is serving | [5.5.1](#551-health) |

### 5.4 Configuration

The CA container is already running when this check applies. Its admin password file is inside the container. The health check runs `step ca health` against `https://localhost:9000` with the container's root certificate. The password is not printed.

### 5.5 Tasks

#### 5.5.1 Health

```powershell
docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

> ```
> ok
> ```

### 5.6 Verify

The container health status is `healthy` after the same probe succeeds.

### 5.7 Gotchas

`:9000` inside this container is step-ca. `:9000` on the host is the gateway. A certificate check that needs the CA starts from the commands in this section. It does not replace the running containers.

## 6. Caddy (on-prem edge)

Builds: none of the three lab builds. Production-shaped deployment only.

### 6.1 What it is

On the production-shaped deployment, Caddy terminates HTTPS and forwards to the gateway. The lab ports in this guide are the host ports on this machine. Caddy is not part of that lab listener.

### 6.2 What it provides

- The HTTPS name used on the company LAN.
- The on-prem issuer host, which replaces `localhost` in the token issuer.

### 6.3 Configuration

That deployment joins the identity gateway and does not publish the lab ports 8000 and 8080. Postgres for that deployment is `authbox_production` on `pgdata_onprem`.

### 6.4 What else changes on-prem

The database name, the volume, and the public issuer change. The claim name remains `tid`. The route shapes remain the shapes in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

### 6.5 Tasks

Health is `GET /authbox/health` on the API base URL of the deployment that is already running.

### 6.6 Gotchas

The on-prem database volume is `pgdata_onprem`. The lab database volume is `pgdata_lab`. They are different databases.

---

# Part II — The platform

## 7. Ports by build

| Build | API | Keycloak | Gateway | Admin | Postgres | step-ca | Device |
|---|---|---|---|---|---|---|---|
| **Base** | `:8000` | `:8080` | `:9000` | `:9901` | `:5433` | — | — |
| **Base Secure** | unpublished | unpublished | `:9000` | `:9901` | `:5433` | — | — |
| **Base PKI** | unpublished | unpublished | `:9000` | `:9901` | `:5433` | container only | `:1029`/`:8883` when published |

Changing which build is installed replaces that set. A short-lived check container is not that change. Progressive calls are in [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

The production-shaped deployment (Caddy HTTPS, `authbox_production`) is outside these three lab builds. See [§6](#6-caddy-on-prem-edge).

## 8. How the services fit together

The block diagram of these paths is in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

### 8.1 How Keycloak stores data in Postgres

Keycloak owns the schema. User attributes, including `tenant_id` and `clearance`, are rows in `user_attribute`. Roles are a separate mapping. The API never reads these tables.

### 8.2 How authbox-api works with Keycloak

The browser login URL is built from the public issuer for the build you set. The API fetches signing keys from Keycloak inside the Docker network. Evaluate checks the token, requires claim `tid`, and returns the URL tenant in field `tenant_id`.

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

### 9.2 Environment names

Values are not written here. Set them in the session before the scenario pass. The names are listed in [README.md](README.md).

| Use | Name |
|---|---|
| Database user, password, and database | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` |
| Keycloak admin inside the Keycloak container | `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD` |
| Password-grant client | `NEXUS_AUTH_CLIENT_ID`, `NEXUS_AUTH_CLIENT_SECRET` |
| Machine client | `NEXUS_SIMULATOR_M2M_CLIENT_ID`, `NEXUS_AUTH_M2M_CLIENT_SECRET` |
| User whose claim `tid` is `tenant_a`, roles include `admin` and `operator` | `AUTHBOX_USER_A`, `AUTHBOX_USER_A_PASSWORD` |
| User whose claim `tid` is `tenant_b`, role `viewer` | `AUTHBOX_USER_B`, `AUTHBOX_USER_B_PASSWORD` |
| Edge user, role `operator`. Username alone is `401` | `AUTHBOX_EDGE_USER`, `AUTHBOX_EDGE_PASSWORD` |
| Edge user, role `reader` | `AUTHBOX_EDGE_PROTECTED_USER`, `AUTHBOX_EDGE_PASSWORD` |
| One-time secret inside the API container | `NEXUS_SIMULATOR_TOTP_SECRET` |

### 9.3 Health checks by build

| Check | Command | Base | Base Secure | Base PKI |
|---|---|---|---|---|
| Postgres | `docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab` | yes | yes | yes |
| API | `Invoke-RestMethod "$API/authbox/health"` | `:8000` or `:9000` | `:9000` | `:9000` |
| Keycloak | `Invoke-WebRequest "$KC/realms/nexus-test/.well-known/openid-configuration"` | `:8080` or `:9000` | `:9000` | `:9000` |
| Envoy | `Invoke-WebRequest http://localhost:9901/ready` | yes | yes | yes |
| step-ca | [5.5.1](#551-health) | no | no | yes |
| Lab ports closed | TCP `:8000`/`:8080` fail | no (open) | yes | yes |

### 9.4 Component defaults (names only)

| Component | Default that the build expects |
|---|---|
| Postgres | DB `authbox_lab`, user name `POSTGRES_USER`, host publish `5433` |
| Keycloak | Realm `nexus-test`, admin names `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` |
| authbox-api | Image `gd-authbox-dev:latest`; issuer host matches the build; seeded clients use the `NEXUS_*` and `AUTHBOX_*` names |
| Envoy | Gateway `:9000`, admin `:9901`; JWT on `/authbox/` |
| step-ca | Only on Base PKI; health inside the container against its own `:9000` |

## 10. End-to-end verification

Run [SCENARIO-TESTING.md](SCENARIO-TESTING.md) in one session after `$Build`, `$KC`, and `$API` are set. Progress through **Base**, then **Base Secure**, then **Base PKI** as that file directs. Each group has the call flow, then curl.exe and Postman, then the PowerShell line. Each scenario prints `PASS`, `FAIL`, or `SKIP`.

One failure line means that layer. A JSON `401` on evaluate with a fresh password-grant token means the token issuer and the API issuer disagree, or claim `tid` is absent. A plain-text `401` means Envoy rejected the JWT before the API.

## 11. Quick tips — certs and mTLS

These tips apply only when **Base PKI** is the installed build. Scripts: [helpers/README.md](helpers/README.md).

| Tip | What it proves | Script |
|---|---|---|
| step-ca health | CA answers `ok` inside the container | [helpers/tip-stepca-health.ps1](helpers/tip-stepca-health.ps1) |
| Device ports | TCP `:1029` / `:8883` when listeners are published | [helpers/tip-mtls-ports.ps1](helpers/tip-mtls-ports.ps1) |
| Gateway still healthy after PKI | `GET http://localhost:9000/authbox/health` and admin `:9901/ready` | [helpers/health-build.ps1](helpers/health-build.ps1) with `$Build = "base-pki"` |

Device certificate enrollment and FIWARE edge proofs that need a second product are not in this pack. When device listeners are published, use the port tip above, then the device-trust scenarios in [SCENARIO-TESTING.md](SCENARIO-TESTING.md) that the Base PKI section lists.

## Appendix A — Running containers

| Container | Base | Base Secure | Base PKI |
|---|---|---|---|
| `auth-sandbox-postgres-1` | `:5433` → `authbox_lab` | same | same |
| `auth-sandbox-keycloak-1` | host `:8080` | host unpublished | host unpublished |
| `auth-sandbox-authbox-api-1` | host `:8000` | host unpublished | host unpublished |
| `auth-sandbox-envoy-1` | `:9000`, `:9901` | `:9000`, `:9901` | same; optional `:1029`/`:8883` |
| `auth-sandbox-step-ca-1` | absent | absent | present |

Related pages in this pack: [README.md](README.md), [RELEASE-NOTES.md](RELEASE-NOTES.md), [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md), [SCENARIO-TESTING.md](SCENARIO-TESTING.md).
