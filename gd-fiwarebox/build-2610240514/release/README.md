# FIWARE-Box

FIWARE-Box is the digital-twin data plane: Orion-LD, IoT Agent JSON, Mosquitto, MongoDB, and an nginx context server. Linked packages also use Auth-Box (Keycloak, Envoy, step-ca). This pack does not start Auth-Box.

Choose by need: **video first**, then a **security package**. The two GHCR leaves stay role images (broker and camera). They are not full stacks. Packages select which leaves and companions are already running.

## Choose video

| Choice | Effect |
|---|---|
| **No** | Do not run the MediaMTX leaf |
| **Yes** | Add the MediaMTX leaf, with publisher credentials and product config already applied |

Video for the published camera path is MediaMTX. Kurento is an optional overlay / scenario check, not a third leaf, and not required when MediaMTX is present.

## Choose security package

| Package | Where you call | Auth-Box | Certs | Leaves |
|---|---|---|---|---|
| **Lab** | Orion `http://localhost:1026`, IoT Agent `http://localhost:1027`, plain MQTT `localhost:1883` | Not used | Not required for plain MQTT | Upstream Mosquitto digest (not the device-broker leaf) |
| **mTLS data-plane** | Orion `1026`, IoT Agent `1027`, MQTTS `localhost:8883` when free | Not used at request time | Mounted at `/mosquitto/certs` | Broker leaf |
| **Linked edge** | `http://localhost:9000/orion`, `http://localhost:9000/iotagent`, `https://localhost:1029`, MQTTS `localhost:8883` | Already running | Mounted | Broker leaf |
| **Linked + cameras** | Linked addresses, plus MediaMTX `http://localhost:9997`, RTSP `:8554`, HLS `:8888` | Already running | Mounted | Broker leaf **and** MediaMTX leaf |

Lab ports `1026`, `1027`, and `1883` are unpublished on Linked packages. Changing package replaces the running set. A short-lived check container is not that change.

### Compose mode aliases (footnote)

| Package | Typical lab mode name |
|---|---|
| Lab | `dev` |
| mTLS data-plane | `mtls` |
| Linked edge | `linked-mtls` |
| Linked + cameras | `linked-mtls-media` |

Checkout-only names such as `workshop`, `break-glass`, `media`, `media-kurento`, `dev-nodered`, and `linked-nodered` are not separate published packages.

## Options (not packages, not leaves)

| Option | What it is | Detail |
|---|---|---|
| **Node-RED** | Workshop provision UI on `:1880` | [USER-GUIDE.md](USER-GUIDE.md) §9 / §15.3. Needs `FIWARE_API_KEY` and `NODERED_OIDC_CLIENT_SECRET` |
| **ffmpeg / RTSP** | Operator-machine publisher to MediaMTX `:8554` path `live` | [USER-GUIDE.md](USER-GUIDE.md) §15.4. Not shipped in this pack |
| **Kurento** | WebSocket media server on `:8898`; `GET /kurento` → `426` | U-07 throwaway, or workshop option. Not a third leaf |

QuantumLeap / Crate are **out** of this pack. A subscriber keeps its own history.

## Published leaves

This leaf builds two images. Local tags and one published GHCR stamp:

| Role | Local tag | GHCR (this edition’s stamp) |
|---|---|---|
| Device broker (mTLS Mosquitto) | `fiware-box/mosquitto-mtls:local` | `ghcr.io/grep-digital/gd-fiwarebox-mosquitto-mtls:build-2610240514` |
| Camera gateway (MediaMTX) | `fiware-box/mediamtx:1.9.3-wget` | `ghcr.io/grep-digital/gd-fiwarebox-mediamtx:build-2610240514` |

There is no single image tag for the whole stack. Orion-LD, IoT Agent JSON, MongoDB, nginx, the plain Mosquitto digest, and Kurento stay upstream pulls. Node-RED is not one of the two leaves.

### Private GHCR

These packages are access-based. Anonymous pull returns **401**. Use `docker login ghcr.io` with a token that can read `grep-digital` before `docker pull`.

### Solo `docker run` is unsupported

A leaf alone is not a usable product.

| Leaf | Solo `docker run` | Blocker |
|---|---|---|
| Broker | Container stays up; broker does not finish starting | Waits for TLS material under `/mosquitto/certs` |
| MediaMTX | Container stays up; process may open default listeners | Empty config — not the FIWARE camera service until product config and wiring are present |

Publishing host ports alone does not fix either case.

## Companions per package

| Companion | Lab | mTLS data-plane | Linked edge | Linked + cameras |
|---|---|---|---|---|
| Orion-LD, IoT Agent, MongoDB, context (nginx) | yes | yes | yes | yes |
| Plain MQTT password (`FIWARE_MQTT_USER` / `FIWARE_MQTT_PASSWORD`) | yes | — | — | — |
| Broker leaf + mounted certs | — | yes | yes | yes |
| Auth-Box (gateway `:9000`, device `:1029`, MQTTS `:8883`) | — | — | yes | yes |
| MediaMTX leaf + publisher password / config | — | — | — | yes |
| `FIWARE_API_KEY` (service group) for measurement scenarios | when proving U-06 | when proving U-06 | when proving U-06 | when proving U-06 |

This pack names environment variables. It does not contain their values.

## This pack

These five files link only to each other.

| File | What it is |
|---|---|
| [USER-GUIDE.md](USER-GUIDE.md) | Each service; packages; start/stop (§16); Node-RED and RTSP |
| [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md) | Layout, ports, identity, status codes |
| [SCENARIO-TESTING.md](SCENARIO-TESTING.md) | Recorded pass (paste in one PowerShell window) |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | This edition |

Call HTTP with **curl.exe** or **Postman**. The recorded pass is **Windows PowerShell 5.1 or PowerShell 7**. In PowerShell, `curl` is `Invoke-WebRequest`; REST examples use `curl.exe`. MQTT uses `mosquitto_sub` / `mosquitto_pub` inside the broker container.

A token on port `9000` is minted as in [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Set `AUTHBOX_CLIENT_SECRET` and `AUTHBOX_IOT_PASSWORD` in the environment. Scenarios `SKIP` when empty and do not print values. U-02 through U-06 on Linked packages call that Auth-Box install; U-04 and U-05 also need CN `sensor001` listed there.

## Editions

| Piece | Edition |
|---|---|
| Package `gd-fiwarebox` | `2.1.7` |
| Broker leaf | `fiware-box/mosquitto-mtls:local` / GHCR `build-2610240514` |
| Camera leaf | `fiware-box/mediamtx:1.9.3-wget` / GHCR `build-2610240514` |
| Orion-LD | `fiware/orion-ld:1.5.1` |
| IoT Agent JSON | `fiware/iotagent-json:3.14.0` |
| MongoDB | `mongo:4.4.30` |
| Context server | `nginx:1.31.6-alpine` |
| Kurento (optional / U-07) | `kurento/kurento-media-server:7.0.0` |

Compose project name is `fiware-box`. Container names are `fiware-box-<service>-1`.

## What another machine receives

The two leaf images (already built) and these five documents. The rest of the repository is not part of that release. Pages do not name files outside this folder.

## What is already running

These pages call containers that are already up. The scenario blocks do not start the stack. Start and stop: [USER-GUIDE.md](USER-GUIDE.md) [§16](USER-GUIDE.md#16-starting-and-stopping-each-package) (`fiware-ctl` / Auth-Box `sandbox-ctl`; local tags or GHCR retag). Paste scenarios in one PowerShell window per [SCENARIO-TESTING.md](SCENARIO-TESTING.md) [Prerequisites](SCENARIO-TESTING.md#prerequisites).

| Package | What `docker ps` shows (typical) |
|---|---|
| Lab | Orion on `1026`, IoT Agent on `1027`, plain MQTT on `1883` (Auth-Box stopped so host `8883` is free if you later start mTLS) |
| mTLS data-plane | Those host ports, plus MQTTS on `8883` on the broker leaf — Auth-Box must be stopped first |
| Linked edge | No Orion / IoT Agent / Mosquitto host ports; callers use Auth-Box `9000`, `1029`, `8883` |
| Linked + cameras | Linked edge, plus MediaMTX on `9997`, `8554`, `8888` |

Host `8883` is exclusive: Lab/mTLS FIWARE MQTTS or Auth-Box Envoy, not both. Switching order: [USER-GUIDE.md](USER-GUIDE.md) [§16.3](USER-GUIDE.md#163-auth-box-before-linked-packages). Device certificates for mTLS and Linked packages are already mounted in `fiware-box-mosquitto-1` at `/mosquitto/certs`. Passwords are not in this pack. Optional `release/helpers/` tip scripts are deferred.
