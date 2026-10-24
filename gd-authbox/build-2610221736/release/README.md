# Auth-in-a-Box

Auth-in-a-Box is a Keycloak 24 and Postgres 16 service with a FastAPI identity service in front of it. The gateway listens on port 9000. When the PKI containers are running, step-ca issues device certificates. The CA listens on port 9000 inside its own container. That port is not host port 9000.

These five documents are the operator pack. They link only to each other. The containers are already running.

| File | What it is |
|---|---|
| [USER-GUIDE.md](USER-GUIDE.md) | Each service: what it is, how to call it, how to check it |
| [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md) | Layout, claims, routes, and status codes |
| [SCENARIO-TESTING.md](SCENARIO-TESTING.md) | Every scenario: the call flow, then the recorded pass |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | What this edition answers |

Call the HTTP API with **curl.exe** or **Postman**. The recorded pass is **Windows PowerShell 5.1 or PowerShell 7**. In PowerShell the name `curl` is an alias for `Invoke-WebRequest`, so the REST examples use `curl.exe`. A call that sends a secret does not put that secret on the `curl.exe` command line. Write a UTF-8 file with no byte-order mark and run `curl.exe --config` on that file. The file uses the environment names below. It does not contain a copied secret from this page.

Postman is not one of the released images. Install it yourself. Its environment holds the same names as the table below, and `api`, `keycloak`, `token_a`, `token_b`, and `token_m` from [SCENARIO-TESTING.md](SCENARIO-TESTING.md). It can run the HTTP scenarios. It does not run the PowerShell pass and it does not run the in-container health commands.

`curl.exe` is the curl binary on the machine. It is not a released image. The browser clients `iot-admin-app` and `nodered` are not released images. The numbered pass does not log in through those clients. Keycloak and Postgres stay upstream images. The image this repo builds is `gd-authbox-dev:latest`.

## Ports already open

Set one switch in [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Pasting the other switch later changes every later call. Setting the switch does not start containers and does not replace the running set.

| Switch | Keycloak | API | Token issuer |
|---|---|---|---|
| **Lab** | `http://localhost:8080` | `http://localhost:8000` | `http://localhost:8080/realms/nexus-test` |
| **Gateway** | `http://localhost:9000` | `http://localhost:9000` | `http://localhost:9000/realms/nexus-test` |

On the lab switch the API is on port 8000 and Keycloak is on port 8080. Host port 9000 may also be open. On the gateway switch both are on port 9000, and ports 8000 and 8080 are not published. Use a token on the same switch that issued it.

The device listener, when it is published, is port 1029. The plain lab API listener is port 8000. The gateway listener is port 9000.

Run the full scenario pass on the lab switch. Checks that send a bearer also pass on the gateway switch. Checks that send no bearer are answered by the API on the lab switch. On the gateway switch the gateway requires a JWT on `/authbox/` before the API sees the call. A plain-text `401` and a JSON `401` are two different results.

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
| `AUTHBOX_EDGE_USER` | Edge user with role `operator`. The password is `AUTHBOX_EDGE_PASSWORD`. Username alone is `401` |
| `AUTHBOX_EDGE_PROTECTED_USER` | Edge user with role `reader` |
| `AUTHBOX_EDGE_PASSWORD` | Password for `AUTHBOX_EDGE_USER` and for `AUTHBOX_EDGE_PROTECTED_USER` |
| `KEYCLOAK_ADMIN` | Admin user already set inside the Keycloak container |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password already set inside the Keycloak container |
| `POSTGRES_USER` | Database user already set inside the Postgres container |
| `POSTGRES_PASSWORD` | Database password already set inside the Postgres container |
| `POSTGRES_DB` | Database name already set inside the Postgres container |
| `NEXUS_SIMULATOR_TOTP_SECRET` | One-time secret already set inside the API container |

A new PowerShell window has none of the scenario variables and no result list. Paste the scenario file from the setup block downward in one session.

## Editions in this image

| Piece | Edition |
|---|---|
| API image | `gd-authbox-dev:latest` |
| Package `gd-authbox` | 2.1.0 |
| `nexus-auth` | 4.0.0 |
| `nexus-common` | 3.4.0 |
| Keycloak | `quay.io/keycloak/keycloak:24.0` |
| Postgres | `postgres:16-alpine` |
| `GET /authbox/` field `version` | `7.0.0` |

Container names are `auth-sandbox-<service>-1`.
