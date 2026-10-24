# gd-releases

[`index.json`](index.json) lists the builds in this repository. Each build is a folder with `provenance.json` and `release/`:

- `README.md`
- `RELEASE-NOTES.md`
- `USER-GUIDE.md`
- `TECHNICAL-REFERENCE.md`
- `SCENARIO-TESTING.md`

## gd-authbox / build-2610221736

| Field | Value |
|-------|-------|
| `internal_release` | `2.1.0` |
| `kind` | `wheel-image` |
| `image` | `ghcr.io/grep-digital/gd-authbox:build-2610221736` |
| `also_tag_latest` | `false` |
| `dockerfiles` | `Dockerfile` |
| `wheel_deps` | `packages/nexus-packages/nexus-auth-v2`, `packages/nexus-packages/nexus-common-v3` |
| `leaf` | `platforms/gd-authbox-v21` |
| `leaf_sha` | `0c177649a22decebb105526342324ab83c475911` |

## gd-fiwarebox / build-2610240514

| Field | Value |
|-------|-------|
| `internal_release` | `2.1.7` |
| `kind` | `many-dockerfiles` |
| `image` | `null` |
| `also_tag_latest` | `false` |
| `dockerfiles` | `iotagent/Dockerfile`, `mediamtx/Dockerfile`, `mosquitto/Dockerfile`, `nodered/Dockerfile` |
| `wheel_deps` | none |
| `leaf` | `platforms/gd-fiwarebox-v21` |
| `leaf_sha` | `ab81d7f6f122f980c74607268cc112e30fb87f4e` |

`index.json` stores the same `"image": null` and these two image names:

- `ghcr.io/grep-digital/gd-fiwarebox-mosquitto-mtls:build-2610240514`
- `ghcr.io/grep-digital/gd-fiwarebox-mediamtx:build-2610240514`

Digests for those two images are in [`gd-fiwarebox/build-2610240514/provenance.json`](gd-fiwarebox/build-2610240514/provenance.json).
