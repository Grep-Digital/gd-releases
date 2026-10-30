# FIWARE-Box — this edition

Facts for this pack. Choose video, then a security package: [README.md](README.md). Operation: [USER-GUIDE.md](USER-GUIDE.md). Contracts: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Checks: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

## Packages this edition publishes

| Package | Video | Security surface |
|---|---|---|
| **Lab** | No | Host Orion `1026`, IoT Agent `1027`, plain MQTT `1883`. No Auth-Box |
| **mTLS data-plane** | No | Those northbound ports plus MQTTS `8883` with mounted certs. No Auth-Box at request time |
| **Linked edge** | No | Auth-Box `9000` / `1029` / `8883`. Lab ports unpublished |
| **Linked + cameras** | Yes (MediaMTX) | Linked edge plus MediaMTX `9997` / `8554` / `8888` |

The scenario page records checks against containers that are already running. It does not start the stack. Prerequisites and borrow order: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

## Options (this edition)

| Option | In pack? |
|---|---|
| Node-RED workshop UI | Option only — not a leaf ([USER-GUIDE.md](USER-GUIDE.md) §9) |
| ffmpeg / RTSP publisher | Operator machine — not shipped |
| Kurento | U-07 throwaway / workshop option — not a leaf |
| QuantumLeap / Crate | **Out** — subscriber keeps history |

## Published leaves (unchanged roles)

| Role | Local | GHCR stamp for this edition |
|---|---|---|
| Device broker | `fiware-box/mosquitto-mtls:local` | `ghcr.io/grep-digital/gd-fiwarebox-mosquitto-mtls:build-2610240514` |
| Camera gateway | `fiware-box/mediamtx:1.9.3-wget` | `ghcr.io/grep-digital/gd-fiwarebox-mediamtx:build-2610240514` |

Broker base: `eclipse-mosquitto:2` digest `sha256:6f8d8a947c506f8a2290ec65cd4bd2bc7cb4d43fb5f6271f861cb013e2ef9797` (label Mosquitto 2.1.2). Camera: MediaMTX `1.9.3` on `alpine:3.21` plus wget.

Packages are private. Anonymous GHCR pull returns **401**. Solo `docker run` of either leaf is **unsupported**: the broker waits for `/mosquitto/certs`; MediaMTX without product config is not the FIWARE camera service.

## Companions

| Piece | Image / note |
|---|---|
| Orion-LD | `fiware/orion-ld:1.5.1` |
| IoT Agent JSON | `fiware/iotagent-json:3.14.0` (northbound in-network `4041`) |
| MongoDB | `mongo:4.4.30` digest `sha256:4be76f674fc4b27859816811b8baa3c51830eb1dbf4ca81a51e26b79edd662ef` |
| Context server | `nginx:1.31.6-alpine` |
| Plain MQTT (Lab) | Same Mosquitto digest as the broker base; not the device-broker leaf |
| Auth-Box | Required for Linked packages; not started by this pack |
| Kurento | `kurento/kurento-media-server:7.0.0` — optional / U-07 only |

Package `gd-fiwarebox` is `2.1.7`. Distribution id is `gd-fiwarebox`.

Another machine receives the two leaf images already built and these five files. The rest of the repository is not part of that release.

## Dependencies the checks use

On Linked packages, U-02, U-03, U-04, U-05, and the U-06 read-back call Auth-Box. The token is minted on port `9000`. U-04 and U-05 also send the `sensor001` certificate to port `1029`, and Auth-Box must currently list that CN. A `403` body `device identity 'sensor001' not in trust registry` means that list does not contain it. The list lasts 24 hours in the Auth-Box API process.

B-08 and B-09 start the pinned plain Mosquitto image. U-07 starts Kurento and removes it when the check finishes. C-04 reads `MEDIAMTX_PUBLISH_PASSWORD`. Node-RED reads `NODERED_OIDC_CLIENT_SECRET` and `FIWARE_API_KEY`. Detail: [USER-GUIDE.md](USER-GUIDE.md) section 12.

## What answers

| Call | Result |
|---|---|
| Plain MQTT with no username | Refused. `allow_anonymous false` |
| Plain MQTT with `FIWARE_MQTT_USER` and `FIWARE_MQTT_PASSWORD` | The client connects |
| MQTTS with a device certificate whose CN matches the topic | The client connects. The IoT Agent certificate cannot publish a device `attrs` topic |
| `GET http://localhost:9997/v3/paths/list` with no credentials, on Linked + cameras | `401` |
| The same call as `MEDIAMTX_PUBLISH_USER` | `200` |
| `GET` the context document inside the context container | `200` and a JSON body |
| `GET :8898/kurento` (U-07 or optional Kurento) | `426` |
| `PATCH` on Auth-Box port `9000` | `405` |

## Secrets

This pack does not contain `.env`. Set `FIWARE_MQTT_USER`, `FIWARE_MQTT_PASSWORD`, and, for Linked + cameras, `MEDIAMTX_PUBLISH_PASSWORD` before those containers are created. The publisher name defaults to `publisher`. The name `any` is rejected. Password length is 12–128 characters from letters, digits, and `. _ @ + -`.

`AUTHBOX_CLIENT_SECRET` and `AUTHBOX_IOT_PASSWORD` are required for a token on port `9000`. `NODERED_OIDC_CLIENT_SECRET` and `FIWARE_API_KEY` are required before a Node-RED workshop start. Node-RED is not one of the two leaves. Compose does not substitute a key when `FIWARE_API_KEY` is unset.

## License notices in the leaves

The camera image contains `/licenses/mediamtx-MIT.txt` (MIT, Copyright (c) 2019 aler9) and `/licenses/NOTICE`. Alpine wget remains under its upstream GPL-3.0-or-later terms. The device-broker image contains `/licenses/NOTICE`. Upstream Eclipse Mosquitto terms are unchanged. Orion-LD, IoT Agent JSON, MongoDB, nginx, and Kurento keep their upstream terms.

## Start and stop (this edition)

The pack does not start containers. Lab controllers: **`fiware-ctl`** (FIWARE-Box) and Auth-Box **`sandbox-ctl`**. Per-package up/down, GHCR retag, Auth-Box-first order, and host `8883` ownership when switching Lab/mTLS ↔ Linked: [USER-GUIDE.md](USER-GUIDE.md) section 16. Optional `release/helpers/` tip scripts are **deferred**. Scenario blocks stay a recorder only ([SCENARIO-TESTING.md](SCENARIO-TESTING.md)). Paste those blocks exactly. Package refine is `v2.1.7-operator-pack.2`; live matrix + governance encode is `v2.1.7-operator-pack.3`.

## Started only when you ask

Linked + cameras runs Orion, the IoT Agent, Mosquitto, Mongo, the context server, and MediaMTX. Kurento answers on port `8898` for scenario U-07 and is removed when that check finishes. Node-RED is a workshop option. A subscriber listens on Orion or MQTT and keeps its own history. This pack does not start QuantumLeap or Crate.
