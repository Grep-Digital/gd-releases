# Auth-in-a-Box

Auth-in-a-Box is a Keycloak 24 and Postgres 16 lab with a FastAPI identity service in front of it. Envoy is the gateway on port 9000. step-ca issues device certificates when you start the PKI overlay.

This folder is the operator pack for the product as it runs. These five files link only to each other.

| File | What it is |
|---|---|
| [USER-GUIDE.md](USER-GUIDE.md) | Each service: what it is, how to operate it, how to check it |
| [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md) | Layout, claims, routes, and status codes |
| [SCENARIO-TESTING.md](SCENARIO-TESTING.md) | Every scenario: the call flow, then curl, Postman, and a PowerShell check |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | What this edition contains |

Call the HTTP API with **curl** or **Postman**. The recorded pass in the scenario file is **Windows PowerShell 5.1 or PowerShell 7**. `curl.exe` is the curl binary. In PowerShell, the name `curl` is an alias for `Invoke-WebRequest`.

## Two ways to reach the stack

Which ports answer depends on the compose mode you launched.

| Access | Launch command | Keycloak | API |
|---|---|---|---|
| **Direct** | `.\devx\sandbox-ctl.ps1 up -Mode dev` or `.\devx\sandbox-ctl.ps1 up -Mode dev-pki`. Also `base` and `min` for a smaller stack. | `http://localhost:8080` | `http://localhost:8000` |
| **Gateway** | `.\devx\sandbox-ctl.ps1 up -Mode dev-secure`, or the same modes with `-WithFiwareLink` | `http://localhost:9000` | `http://localhost:9000` |

Direct access publishes Keycloak on port 8080 and the API on port 8000. `dev` and `dev-pki` also publish Envoy on port 9000, so both rows work. Gateway access, from `dev-secure` or `-WithFiwareLink`, leaves ports 8000 and 8080 unpublished. Callers use port 9000 for both Keycloak and the API.

Use a token on the same access path that issued it.

| Access | Token issuer |
|---|---|
| Direct | `http://localhost:8080/realms/nexus-test` |
| Gateway | `http://localhost:9000/realms/nexus-test` |

Run the full scenario pass on direct access. Checks that send a bearer also pass on gateway access. Checks that send no bearer (air-gap, Aadhaar, wallet, and the OpenAPI document) are answered by the API on direct access. On gateway access, Envoy requires a JWT on `/authbox/` before the API sees the call.

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

Compose project name is `auth-sandbox`. Container names are `auth-sandbox-<service>-1`.

## Checkout on another machine

Clone this repository. The start command is `.\devx\sandbox-ctl.ps1`. The compose files it merges are already in that clone:

| Mode | Files |
|---|---|
| `dev` | `docker-compose.postgres-lab.yaml`, `docker-compose.dev.yaml` |
| `dev-secure` | those two, plus `docker-compose.dev.secure.yaml` |
| `dev-pki` | the `dev` files, plus `docker-compose.security.yaml` |
| `-WithFiwareLink` | also `docker-compose.fiware-link.yaml` and `docker-compose.fiware-device-policy.yaml` |
| `base` | `docker-compose.postgres-lab.yaml`, `docker-compose.yaml` |
| `min` | `docker-compose.postgres-lab.yaml`, `docker-compose.min.yaml` |

The API program, the seed, and the edge users are `src/`, `src/entrypoint.sh`, `src/seed_data.py`, and `tests/assets/discovery.json`. Gateway routes are `deploy/edge/envoy/envoy.yaml`. The image build file is `Dockerfile`. On-prem is `docker-compose.onprem.yaml`, `deploy/onprem/Caddyfile`, and `.\devx\run-onprem-stack.ps1`.

`dist/` holds private wheels used when you build the image yourself. Those wheels are not in the clone. `deploy/edge/envoy/certs-lab/` and step-ca password files are not in the clone. A machine that receives the built image does not need the wheels.
