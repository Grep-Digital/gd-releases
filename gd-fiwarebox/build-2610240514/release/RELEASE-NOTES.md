# FIWARE-Box — this edition

Facts for this pack. Operation is in [USER-GUIDE.md](USER-GUIDE.md). Contracts are in [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Checks are in [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

## Two ways it runs

This data plane runs with no Auth-Box. `dev` publishes the internal lab drill: Orion `1026`, IoT Agent `1027`, plain MQTT `1883`. `media` and `media-kurento` keep those ports and add the camera. `mtls`, `workshop`, and `break-glass` keep `1026` and `1027`, leave `1883` unpublished, and add MQTTS `8883` when the certificate files are already mounted.

`linked-mtls` and `linked-mtls-media` need Auth-Box already running. Those starts do not publish `1026`, `1027`, or `1883`. Callers use `9000`, `1029`, and `8883`. The scenario page records checks against that running stack. It does not start the stack. Which scenario borrows which container is in [SCENARIO-TESTING.md](SCENARIO-TESTING.md) [Prerequisites](SCENARIO-TESTING.md#prerequisites).

## Dependencies the checks use

U-02, U-03, U-04, U-05, and the U-06 read-back call the Auth-Box install. The token is minted on port `9000`. U-04 and U-05 also send the `sensor001` certificate to port `1029`, and Auth-Box must currently list that CN. A `403` body `device identity 'sensor001' not in trust registry` means that list does not contain it. Auth-Box keeps the list for 24 hours in its API process.

B-08 and B-09 start the pinned plain Mosquitto image. U-07 starts `kurento/kurento-media-server:7.0.0` and removes that container when the check finishes. C-04 reads `MEDIAMTX_PUBLISH_PASSWORD`. Node-RED reads `NODERED_OIDC_CLIENT_SECRET`, and `linked-nodered` also uses Auth-Box. The table is in [USER-GUIDE.md](USER-GUIDE.md) section 12.

## Stack

| Piece | Image |
|---|---|
| Device broker | `fiware-box/mosquitto-mtls:local`, on `eclipse-mosquitto:2` digest `sha256:6f8d8a947c506f8a2290ec65cd4bd2bc7cb4d43fb5f6271f861cb013e2ef9797`. The image label reports Mosquitto 2.1.2 |
| Plain MQTT broker | The same Mosquitto digest. It is not the device-broker image |
| Camera gateway | `fiware-box/mediamtx:1.9.3-wget`. MediaMTX `1.9.3` on `alpine:3.21`, plus wget |
| Orion-LD | `fiware/orion-ld:1.5.1` |
| IoT Agent JSON | `fiware/iotagent-json:3.14.0`. Northbound port inside the compose network is `4041` |
| MongoDB | `mongo:4.4.30` digest `sha256:4be76f674fc4b27859816811b8baa3c51830eb1dbf4ca81a51e26b79edd662ef` |
| Context server | `nginx:1.31.6-alpine` |
| Kurento | `kurento/kurento-media-server:7.0.0`, only when you started `media-kurento` |

Package `gd-fiwarebox` is `2.1.7`. Distribution id is `gd-fiwarebox`.

Another machine keeps the five files in this folder and the two images `fiware-box/mosquitto-mtls:local` and `fiware-box/mediamtx:1.9.3-wget`. The rest of the repository is not part of that release. These pages do not name files outside this folder. Orion-LD, IoT Agent JSON, MongoDB, nginx, the plain Mosquitto digest, and Kurento are upstream pulls. Node-RED is not one of the two images. A lab drill uses `dev`. A production-shaped deployment uses `linked-mtls-media` with Auth-Box already running. Provisioning a device and publishing a measurement are [USER-GUIDE.md](USER-GUIDE.md) section 9. The rest of the map is section 15.

## What answers

| Call | Result |
|---|---|
| Plain MQTT with no username | Refused. `allow_anonymous false` |
| Plain MQTT with `FIWARE_MQTT_USER` and `FIWARE_MQTT_PASSWORD` | The client connects |
| MQTTS with a device certificate whose CN matches the topic | The client connects. The IoT Agent certificate cannot publish a device `attrs` topic |
| `GET http://localhost:9997/v3/paths/list` with no credentials, after `linked-mtls-media` | `401` |
| The same call as `MEDIAMTX_PUBLISH_USER` | `200` |
| `GET` the context document inside the context container | `200` and a JSON body |
| `GET :8898/kurento` after `media-kurento` | `426` |
| `PATCH` on Auth-Box port `9000` | `405` |

## Secrets

This pack does not contain `.env`. Set `FIWARE_MQTT_USER`, `FIWARE_MQTT_PASSWORD`, and, for a camera start, `MEDIAMTX_PUBLISH_PASSWORD` in the environment before those containers are created. The publisher name defaults to `publisher`. The name `any` is rejected. Password length is 12–128 characters from letters, digits, and `. _ @ + -`.

`AUTHBOX_CLIENT_SECRET` and `AUTHBOX_IOT_PASSWORD` are required for a token on port `9000`. `NODERED_OIDC_CLIENT_SECRET` and `FIWARE_API_KEY` are required before `dev-nodered` or `linked-nodered`. Node-RED is a workshop start. It is not one of the two images in this release. The compose file does not substitute a key when `FIWARE_API_KEY` is unset.

## License notices in the images this leaf builds

The camera image contains `/licenses/mediamtx-MIT.txt` (MIT, Copyright (c) 2019 aler9) and `/licenses/NOTICE`. Alpine wget remains under its upstream GPL-3.0-or-later terms. The device-broker image contains `/licenses/NOTICE`. Upstream Eclipse Mosquitto terms are unchanged. Orion-LD, IoT Agent JSON, MongoDB, nginx, and Kurento keep their upstream terms.

## Started only when you ask

A `linked-mtls-media` start runs Orion, the IoT Agent, Mosquitto, Mongo, the context server, and MediaMTX. Kurento answers on port `8898` for the duration of scenario U-07, from `kurento/kurento-media-server:7.0.0`, and is removed when that check finishes. Node-RED is present after `dev-nodered` or `linked-nodered`. A subscriber listens on Orion or MQTT and keeps its own history. This pack does not start QuantumLeap or Crate.
