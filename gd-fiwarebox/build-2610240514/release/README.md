# FIWARE-Box

FIWARE-Box is the digital-twin data plane: Orion-LD, IoT Agent JSON, Mosquitto, MongoDB, and an nginx context server. It runs on its own. A linked start also uses Auth-Box, which owns Keycloak, Envoy, and step-ca. This pack does not start Auth-Box.

Two ways the same containers are reached:

| Start | Auth-Box | Where you call |
|---|---|---|
| `base` | Not used | Compose network only. No host ports |
| `dev`, `media`, `media-kurento`, `dev-nodered` | Not used | Internal lab drill: Orion `http://localhost:1026`, IoT Agent `http://localhost:1027`, plain MQTT `localhost:1883` |
| `mtls`, `workshop`, `break-glass` | Not running. Certificate files are already mounted | Orion `http://localhost:1026`, IoT Agent `http://localhost:1027`, MQTTS `localhost:8883` when that port is free. Plain `1883` is not published |
| `linked`, `linked-mtls`, `linked-workshop`, `linked-nodered` | Already running | `http://localhost:9000/orion`, `http://localhost:9000/iotagent`, device API `https://localhost:1029`, MQTTS `localhost:8883` |
| `linked-mtls-media` | Already running | The linked addresses, plus MediaMTX `http://localhost:9997`, RTSP `:8554`, HLS `:8888` |

Ports `1026`, `1027`, and `1883` are the internal lab drill. A call there tests Orion, the IoT Agent, and plain MQTT on this machine. A linked start does not publish those ports. Gateway calls use `9000`, `1029`, and `8883`.

`dev` answers on port `1883` only when `FIWARE_MQTT_USER` and `FIWARE_MQTT_PASSWORD` were set before that container started. `media`, `media-kurento`, and `linked-mtls-media` answer as the publisher only when `MEDIAMTX_PUBLISH_PASSWORD` was set before that container started. Set those variables in the environment. This pack does not contain a password or an env file.

This folder is the operator pack for the product as it runs. These five files link only to each other.

| File | What it is |
|---|---|
| [USER-GUIDE.md](USER-GUIDE.md) | Each service: what it is, how to operate it, how to check it |
| [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md) | Layout, ports, identity, and status codes |
| [SCENARIO-TESTING.md](SCENARIO-TESTING.md) | Every scenario: the call flow, then curl.exe, Postman, and a PowerShell check |
| [RELEASE-NOTES.md](RELEASE-NOTES.md) | What this edition contains |

Call HTTP APIs with **curl.exe** or **Postman**. The recorded pass in the scenario file is **Windows PowerShell 5.1 or PowerShell 7**. In PowerShell, the name `curl` is an alias for `Invoke-WebRequest`. The REST lines use `curl.exe` so the curl binary runs.

MQTT is not HTTP. Broker scenarios use `mosquitto_sub` and `mosquitto_pub` inside the broker container, then the same PowerShell check.

## How you started

The table at the top is the full list. `dev` is the internal lab drill on ports `1026`, `1027`, and `1883`, with no Auth-Box. `mtls` keeps `1026` and `1027`, leaves `1883` unpublished, and listens for MQTTS on `8883` when the certificate files are already mounted. `linked-mtls` and `linked-mtls-media` leave `1026`, `1027`, and `1883` unpublished and call Auth-Box on `9000`, `1029`, and `8883`.

A token used on port 9000 is minted with `POST http://localhost:9000/realms/nexus-test/protocol/openid-connect/token`. The fields are in [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Set `AUTHBOX_CLIENT_SECRET` and `AUTHBOX_IOT_PASSWORD` in the environment before a scenario that needs a token. The scenario line records `SKIP` when either value is empty, and it does not print the value.

U-02, U-03, U-04, U-05, and the U-06 read-back call that Auth-Box install. U-04 and U-05 also need the certificate CN listed there. The full list, including the plain Mosquitto image, the Kurento image, and the environment values, is [USER-GUIDE.md](USER-GUIDE.md) section 12.

## Editions in this pack

| Piece | Edition |
|---|---|
| Package `gd-fiwarebox` | `2.1.7` |
| Device broker image | `fiware-box/mosquitto-mtls:local` |
| Camera gateway image | `fiware-box/mediamtx:1.9.3-wget` |
| Orion-LD | `fiware/orion-ld:1.5.1` |
| IoT Agent JSON | `fiware/iotagent-json:3.14.0` |
| MongoDB | `mongo:4.4.30` |
| Context server | `nginx:1.31.6-alpine` |
| Kurento, for scenario U-07 and for a `media-kurento` start | `kurento/kurento-media-server:7.0.0` |

Compose project name is `fiware-box`. Container names are `fiware-box-<service>-1`.

There is no single image tag for the whole stack. The two images this leaf builds are the device broker and the camera gateway.

## What another machine receives

Another machine keeps these five documents and the two images `fiware-box/mosquitto-mtls:local` and `fiware-box/mediamtx:1.9.3-wget`. The rest of the repository is not part of that release. These pages do not name files outside this folder.

Orion-LD, IoT Agent JSON, MongoDB, nginx, the plain Mosquitto digest, and Kurento are pulled from upstream. Node-RED is not one of the two images. The scenario page runs against containers that are already running. Lab drill, production-shaped deployment, Node-RED provisioning, and an RTSP publisher are in [USER-GUIDE.md](USER-GUIDE.md) section 15. The device form and the measurement publish are section 9.

## What is already running

These pages call containers that are already up. `docker ps` shows project `fiware-box`. Container names are `fiware-box-<service>-1`. This pack does not start them. The scenario blocks do not start the stack. Paste them in one PowerShell window, in the order in [SCENARIO-TESTING.md](SCENARIO-TESTING.md) [Prerequisites](SCENARIO-TESTING.md#prerequisites).

| How you started | What `docker ps` shows |
|---|---|
| `dev` | Orion on `1026`, IoT Agent on `1027`, plain MQTT on `1883` |
| `mtls` | Those host ports, plus MQTTS on `8883` when that port is free, on the device-broker image |
| `linked-mtls` | No Orion, IoT Agent, or Mosquitto host ports. Callers use Auth-Box `9000`, `1029`, and `8883` |
| `linked-mtls-media` | The `linked-mtls` ports, plus MediaMTX on `9997`, `8554`, and `8888` |
| `media` | Orion, the IoT Agent, plain MQTT, and MediaMTX |
| `media-kurento` | The `media` ports, plus Kurento on `8898` |

Device certificates are already mounted in `fiware-box-mosquitto-1` at `/mosquitto/certs`. The plain MQTT password and the MediaMTX publisher password are not in this pack. B-04, B-05, and C-02 write a temporary config and, for the broker checks, copy the certificate files out of the running container.
