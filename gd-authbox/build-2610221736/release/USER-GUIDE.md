# Auth-in-a-Box — user guide

This is the **user guide** for an Auth-in-a-Box pack. Read the sections in order the first time. Later you can jump by number.

| Section | What it covers |
|---|---|
| **[1. What this pack is](#1-what-this-pack-is)** | Plain-language tour of the stack (for technical and non-technical readers) |
| **[2. What packs you get](#2-what-packs-you-get)** | Base, Base Secure, Base PKI: ports, purpose, capability matrix |
| **[3. Which pack to choose](#3-which-pack-to-choose)** | Quick pick, business use cases, three questions, job table |
| **[4. Get it installed and running](#4-get-it-installed-and-running)** | Prerequisites, unpack, start-pack, stop-pack |
| **[5. After start — operate the stack](#5-after-start-operate-the-stack)** | Confirm the pack, then Keycloak, Postgres, API, Envoy, step-ca |

Contracts (claims, routes, status codes): [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).  
Full checklist pass: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).  
Index: [README.md](README.md). Helpers: [helpers/README.md](helpers/README.md).

### How to run commands in this guide

| Where | Meaning |
|---|---|
| **Your machine — terminal** | Shell on the computer where Docker runs the pack |
| **Your machine — browser** | Chrome, Edge, Firefox, or Safari |
| **Inside a container** | `docker exec …` — you still type it on your machine |

| Your OS           | Shell                              | Notes                                               |
| ----------------- | ---------------------------------- | --------------------------------------------------- |
| **Windows**       | PowerShell 5.1 or 7                | Use `curl.exe` (not the `curl` alias)               |
| **macOS / Linux** | Terminal (`zsh`/`bash`), or `pwsh` | Use `curl`. Docker Desktop / Engine must be running |

**One session:** keep the same terminal for `$Build`, `$KC`, `$API`, and tokens.
**Secrets:** this guide never prints secret values. Load names from the pack `.env` (see [README.md](README.md)).

---

## 1. What this pack is

### In plain words

**Auth-in-a-Box** is a ready-to-run **identity and access stack**. You install it on a computer that runs Docker. After start, your apps, people, and (on one pack) devices can prove **who they are** and **what they are allowed to do**.

You do **not** build Keycloak, a gateway, an API, a database, and a certificate authority from scratch. The pack already wires them together.

Think of a **secure office building**:

| Real-world idea | Piece in this pack |
|---|---|
| Reception desk that checks ID before anyone goes further | **Envoy** (front gate) |
| ID office that issues badges and keeps the employee list | **Keycloak** |
| Filing room that stores the employee records safely | **Postgres** |
| Security office that checks “does this badge allow that door?” | **authbox-api** |
| Special desk that prints **device** ID cards (not people badges) | **step-ca** (Base PKI only) |

People and software get a **digital badge** (an access token). Devices on Base PKI can also get a **certificate** (like a plastic ID card with a chip) from your own private issuer.

### What you receive

A **handoff zip** from your operator (not a public app-store download):

1. Unpack the zip  
2. Run `start-pack`  
3. Use the stack  
4. Run `stop-pack` when finished  

Inside: Docker images, start/stop scripts, config, and these guides under `release/`.

### What this pack is not

| Not this | Meaning |
|---|---|
| Browser apps named `iot-admin-app` / `nodered` | They appear as Keycloak **clients** (names only). This zip does **not** ship those UIs as apps |
| “Pull from the public internet and go” for every reader | You use the zip **your operator** gave you |
| A replacement for every other company login system you already run elsewhere | This pack **is** the Auth-in-a-Box identity stack for this install |

### How the pieces work together

```text
  You / your app / your device
            │
            ▼
     Envoy  (front door :9000)
        │         │
        │         └──► authbox-api   (“may this token do that?”)
        └──► Keycloak               (login + issue tokens)
                 │
                 └──► Postgres      (store users, roles, sessions)

  Base PKI also:
     step-ca  → prints device certificates
     Envoy :1029 / :8883 → device doors (when device edge is on)
```

On **Base**, you can also open Keycloak and the API **directly** on the host (`:8080` and `:8000`) for admin screens and Swagger. On **Base Secure** and **Base PKI**, those direct doors stay closed — almost everything goes through Envoy.

---

### Keycloak — the identity office

**What it is.** Keycloak is an **identity provider** (IdP): software that answers “who is this?” and hands out proof of login.

**Everyday analogy.** The company badge office. You show username and password (or a machine uses its own credentials). The office checks the list and gives you a **time-limited badge** — an **access token** (a JWT). Apps trust that badge instead of storing your password.

**Important ideas (simple):**

| Word | Plain meaning |
|---|---|
| **Realm** (`nexus-test`) | One sealed identity “world” — users and roles for this pack |
| **User** | A person who can sign in |
| **Role** | A job label on the badge (`admin`, `operator`, `viewer`, …) — apps decide doors by role |
| **Tenant (`tid`)** | Which customer/org the person belongs to — stored as `tenant_id`, carried on the token as claim `tid` |
| **Client** | An application allowed to ask Keycloak for tokens (`nexus-sandbox` for people, `nexus-m2m` for machines) |
| **Access token** | Short-lived proof you send to APIs: “I am signed in, here are my roles/tenant” |

**What you can do with it here**

- Create and manage users, passwords, and roles  
- Separate **tenants** (`tenant_a`, `tenant_b`, …) using `tid`  
- Issue tokens for **people** and for **machines** (service-to-service)  
- Open the Admin Console on **Base** at `http://localhost:8080`, or use `kcadm` on Secure/PKI  

Keycloak does **not** print device certificates. That is step-ca’s job on Base PKI.

---

### Postgres — the filing room

**What it is.** PostgreSQL is a **database**: durable storage on disk.

**Everyday analogy.** The locked filing cabinets behind the badge office. When Keycloak creates a user or role, the record is written here. If you restart the Keycloak container, the files are still there.

**What you need to know**

- Database name in this pack: `authbox_lab`  
- You can reach it from the host on port `:5433`  
- Data sits on Docker volume `pgdata_lab` — **kept** when you stop the pack, unless you deliberately wipe volumes  
- **authbox-api does not use this database** — only Keycloak does for the realm  

Deleting the volume is like shredding the filing room. Do that only when you mean to reset the realm.

---

### Envoy — the front gate (reverse proxy)

**What it is.** Envoy is an **edge proxy** (also called a **reverse proxy** or front door): callers talk to Envoy; Envoy talks to the real services behind it.

**Everyday analogy.** Building security at the entrance. Visitors do not wander into every office. They stop at the gate. The gate:

1. Checks whether they are allowed in (for many API paths: “do you have a valid badge / token?”)  
2. Sends them to the right office (`/realms/` → Keycloak, `/authbox/` → authbox-api)  
3. Sends the answer back  

**Why products use a front door**

- One public address (`:9000`) instead of exposing every internal service  
- Shared security checks in one place  
- On Base Secure / Base PKI, Keycloak and the API are **not** open on the host — Envoy is the only door  

**Quick signals**

| Address | Meaning |
|---|---|
| `http://localhost:9000/...` | Traffic through the gate |
| `http://localhost:9901/ready` | “Is the gate process up?” |
| Missing token on a protected path | Often plain text `Jwt is missing` — the gate refused before the API ran |

On **Base PKI**, Envoy can also host **device** doors (`:1029` mTLS, `:8883` MQTT) when that device edge is enabled.

---

### authbox-api — the rules desk

**What it is.** **authbox-api** is the Auth-Box **HTTP API**: a service your tools call over the network (paths under `/authbox/`).

**Everyday analogy.** After the badge office issues a badge, and after the front gate lets you in, this desk answers questions like: “Is this badge valid?” “Which tenant is it?” “Does it have role `viewer`?” “Is this device trusted?”

**What you can do with it here**

| Call type | Plain meaning | Needs a token? |
|---|---|---|
| Health | “Is the API awake?” | No |
| Authorize helpers | Help start a login-style flow | No |
| Evaluate | Read who the token is and what it allows | Yes |
| Device-trust and related routes | Register / check device trust over HTTP | Usually yes |

On **Base**, you can try many routes in a browser form UI (Swagger) at `http://localhost:8000/docs`. On Secure/PKI, call the same API through Envoy on `:9000`.

---

### step-ca — the device ID printer (Base PKI only)

**What it is.** **step-ca** is a **Certificate Authority (CA)**: software that issues and manages digital certificates.

**Everyday analogy.** A private office that prints **device ID cards**. A CA is like a trusted issuer (similar to how a government stamps a passport). Your pack runs its **own** private CA — not a public internet CA. Devices get a certificate + private key files (`.crt` / `.key`).

**Why devices use certificates**

In normal web browsing, the **website** proves itself to you. With **mutual TLS (mTLS)**, the **device also proves itself** with a certificate the server trusts. That is stronger than a shared password alone for many IoT and machine cases.

**What you can do with it here**

- **Issue** a short-lived device certificate (default **24 hours**)  
- **Renew / replace** it before or after expiry  
- Use the certificate on the device edge (`:1029` / `:8883`) when that edge is on  
- Keep the device name on the certificate (CN) matching the device id you expect  

**Do not confuse ports:** host `:9000` is still **Envoy**. step-ca is reached inside its container or via pack scripts under `devx/pki/` ([§5.6](#56-step-ca)).

---

### Containers you will see

These are the running service names Docker shows:

`auth-sandbox-postgres-1` · `auth-sandbox-keycloak-1` · `auth-sandbox-authbox-api-1` · `auth-sandbox-envoy-1` · and on Base PKI `auth-sandbox-step-ca-1`

You do not need to memorize them now. [§5](#5-after-start-operate-the-stack) shows how to check that each one is healthy.

---
## 2. What packs you get

The stack in [§1](#1-what-this-pack-is) is the same product. **Three packs** change **how open the host is** and whether **step-ca / device edge** are present.

| Pack | Adds on top of the previous | In one line |
|---|---|---|
| **Base** | — (starting pack) | Admin + API open on the host; gateway also available |
| **Base Secure** | Closes direct Keycloak/API ports | Gateway-only edge — callers enter through Envoy |
| **Base PKI** | step-ca + device edge | Private CA for device certs; mTLS / MQTT on Auth-Box |

```text
Base  →  Base Secure  →  Base PKI
```

### What is the same vs what changes

| Same on every pack | Changes by pack |
|---|---|
| API image (`authbox-api`) | Which **host ports** are published |
| Realm `nexus-test` and claim `tid` / roles story | Whether **direct** `:8080` / `:8000` are open |
| Postgres DB `authbox_lab` (host `:5433`) | Whether **step-ca** is present |
| Envoy gateway role (`:9000`, admin `:9901`) | Whether **device edge** `:1029` / `:8883` is part of the pack |

### How you receive a pack

- **One zip = one pack.** Unpack that zip and run `start-pack` for that pack only.
- **One pack per session.** Stopping one and starting another **replaces** the running containers.
- **Realm data is kept** on volume `pgdata_lab` unless you deliberately wipe volumes.

### Pack 1 — Base

**For:** full host surfaces — Admin Console, Swagger, and gateway together.

| Host | Use |
|---|---|
| `:8080` | Keycloak Admin, discovery, mint tokens |
| `:8000` | authbox-api + Swagger `/docs` |
| `:9000` / `:9901` | Envoy gateway + ready |
| `:5433` | Postgres |

**Issuer (direct path):** `http://localhost:8080/realms/nexus-test` with API on `:8000`. Do not mix with `:9000` issuer without reminting.

**You can:** manage tenants/roles in the UI; mint user and machine tokens; evaluate/authorize/device-trust; compare direct vs gateway `401` shapes; run [SCENARIO-TESTING.md](SCENARIO-TESTING.md) Phase 1.

**Not for:** gateway-only proof (direct ports are open on purpose); device X.509 or `:1029`/`:8883` (use Base PKI).

### Pack 2 — Base Secure

**For:** production-shaped **gateway-only** edge — same identity stack, no published Keycloak/API host ports.

| Host | Use |
|---|---|
| `:9000` | **Only** door for discovery, tokens, `/authbox/` |
| `:9901` / `:5433` | Ready + Postgres |
| `:8080` / `:8000` | Closed (failure to connect is a **pass**) |

**Issuer:** `http://localhost:9000/realms/nexus-test`. Remint after leaving Base.

**You can:** force all callers through the Envoy gatekeeper; prove JWT enforcement at the edge; run gateway bearer scenarios (Phase 2).

**Not for:** host Admin/Swagger (use Base); device CA / device edge (use Base PKI).

### Pack 3 — Base PKI

**For:** everything Secure can do, plus **step-ca** (private CA) and the Auth-Box **device edge**.

| Host | Use |
|---|---|
| `:9000` / `:9901` / `:5433` | Same as Secure |
| step-ca | Inside its container / `devx/pki` — not host `:9000` |
| `:1029` / `:8883` | Device mTLS + MQTT when the device edge is enabled |

`start-pack` always brings up step-ca. Confirm device ports in [§5.5.8](#558-device-ports-on-base-pki); if closed, enable the Base PKI **device-edge** switch (same pack, not a fourth zip).

**You can:** issue / renew / replace device leaves; register device-trust over HTTP; run mTLS/MQTT on the device edge; Phase 3 scenarios.

**Not for:** host Admin/Swagger; treating Envoy `:9000` as the CA ([§5.6.4](#564-do-not-confuse-the-two-port-9000s)).

### Capability matrix

| Capability | Base | Secure | PKI |
|---|---|---|---|
| Keycloak + API + Envoy + Postgres | yes | yes | yes |
| Admin UI / Swagger on host | **yes** | no | no |
| Gateway-only (`:8000`/`:8080` closed) | no | **yes** | **yes** |
| Tenant (`tid`) + RBAC tokens | yes | yes | yes |
| Envoy JWT front gate | yes | **required** | **required** |
| step-ca issue / renew leaves | no | no | **yes** |
| Device `:1029` / `:8883` | no | no | **yes** when device edge enabled (confirm after start) |

| Pack | Zip pattern | `$Build` |
|---|---|---|
| Base | `gd-authbox-handoff-base-2.1.0-….zip` (not `base-secure` / `base-pki`) | `base` |
| Base Secure | `gd-authbox-handoff-base-secure-….zip` | `base-secure` |
| Base PKI | `gd-authbox-handoff-base-pki-….zip` | `base-pki` |

---
## 3. Which pack to choose

**Rule:** run **one pack at a time**. Pick the pack that matches the **job you need now** — not the one that sounds most complete.

| If your main need is… | Choose | Because |
|---|---|---|
| Admin Console, Swagger, or open host ports for Keycloak/API | **Base** | Direct `:8080` / `:8000` are published |
| Every token and API call must enter through Envoy only | **Base Secure** | Direct IdP/API ports stay closed; `:9000` is the door |
| Private CA, device certificates, or device mTLS/MQTT | **Base PKI** | Only pack with step-ca and the device edge |

When two needs conflict (for example Admin UI **and** device certs): use **Base** for the UI work, stop it, then start **Base PKI** for certificates — remint tokens after each switch.

### Use cases — what fits your business or application

Match the **shape of your product**, not the pack name.

#### Base — best when people and APIs need open admin access

| Business / application type | Why Base fits |
|---|---|
| **Internal tools & operator consoles** | Admins manage users, tenants (`tid`), and roles in Keycloak Admin; developers call Swagger on the host |
| **Multi-tenant SaaS / B2B apps (build phase)** | Model `tenant_a` / `tenant_b`, RBAC (`admin`, `operator`, `viewer`), and token claims before locking the edge |
| **Partner or customer API onboarding** | Mint people and machine tokens; prove evaluate / authorize against real claims |
| **Workforce apps (portals, dashboards)** | Password-grant users + role checks; inspect sessions and clients in the UI |
| **CI/CD or integration bring-up** | Direct `:8080` / `:8000` simplify first wiring of apps to the IdP and Auth-Box API |

#### Base Secure — best when the gateway must be the only door

| Business / application type | Why Base Secure fits |
|---|---|
| **Production-shaped API edge** | Callers hit Envoy `:9000` only; Keycloak and authbox-api are not on the host |
| **Zero-trust / locked perimeter installs** | Prove direct ports closed and JWT enforcement at the front gate (`Jwt is missing` without a bearer) |
| **Microservices & M2M behind one front door** | Services mint `client_credentials` tokens and call `/authbox/` through the same gateway |
| **B2B partner APIs in a hardened layout** | Partners never talk to Keycloak or the API on direct ports — only the gateway |
| **Fintech / regulated API access (gateway posture)** | Same identity stack as Base, with unpublished IdP/API surfaces for edge-style installs |

#### Base PKI — best when devices need their own certificates

| Business / application type | Why Base PKI fits |
|---|---|
| **IoT / sensor / camera fleets** | Issue short-lived device leaves (CN = device id); renew/replace before expiry |
| **Industrial / OT gateways** | Private CA on Auth-Box; present leaves on mTLS `:1029` or MQTT `:8883` |
| **Smart buildings / field equipment** | Device identity separate from people JWTs; operators still use Keycloak for humans |
| **High-assurance M2M (cert-bound clients)** | Combine gateway-only edge with X.509 device trust — not shared passwords alone |
| **Any app that must own a device CA** | step-ca is your certificate factory: create, rotate, and retire leaves for your use case |

#### Typical paths (how teams often move)

| Path | Sequence | When |
|---|---|---|
| **App team** | Base → Base Secure | Build tenants/RBAC in the UI, then harden to gateway-only |
| **Device / edge team** | Base (for Admin UI) → **Base PKI** | Configure realm if needed, then run on CA + device edge |
| **Full product ladder** | Base → Secure → PKI | Validate identity, then edge, then device certs in that order |

### Three questions (in order)

Answer **yes** at the first match. Stop there.

| # | Ask yourself | If yes → |
|---|---|---|
| 1 | Do I need a **private CA**, device `.crt`/`.key`, or device edge `:1029` / `:8883`? | **Base PKI** |
| 2 | Do I need **Keycloak Admin** or **Swagger** on the host? | **Base** |
| 3 | Must callers reach Keycloak and the API **only through Envoy** (`:9000`)? | **Base Secure** |

If every answer is **no**, start with **Base**. Move to Secure or PKI when that capability becomes the job.

```text
1. Device CA / certs / :1029 / :8883?  →  Base PKI
2. Admin UI or Swagger on host?       →  Base
3. Gateway-only (Envoy is the door)?  →  Base Secure
4. None of the above                  →  Base
```

### Choose by job

| Job | Pack | Why this pack |
|---|---|---|
| Create or inspect tenants (`tid`), roles, RBAC in the Admin UI | **Base** | Admin Console only on host for Base |
| Call Auth-Box routes from Swagger in the browser | **Base** | `:8000/docs` only on Base |
| Mint tokens and call the API with direct host ports open | **Base** | Direct Keycloak + API published |
| Prove “nothing reaches Keycloak/API except through the gateway” | **Base Secure** | `:8080` / `:8000` closed is required |
| Run bearer API checks on a locked edge | **Base Secure** | Issuer and `$API` are both `:9000` |
| Issue, renew, or replace **device** certificates | **Base PKI** | step-ca is only here |
| Present a device leaf on mTLS (`:1029`) or MQTT (`:8883`) | **Base PKI** | Device edge is only here |
| Full numbered pass S-01…S-85 | **Base** → Secure → PKI | Phase 1 needs direct ports; then climb the ladder |

### Wrong pack → right pack

| What went wrong | You likely started | Do this instead |
|---|---|---|
| Admin Console or Swagger will not open | Secure or PKI | **Base** (or `kcadm` inside Keycloak if you stay on Secure/PKI) |
| Host `:8080` / `:8000` still answer on a “secure” install | Wrong build still running | Stop the running pack; start **Base Secure** or **Base PKI** |
| You need a device `.crt` / `.key` | Base or Secure | **Base PKI** |
| Evaluate fails after you switched packs | Old token / wrong issuer | Remint on this pack’s `$KC` |
| Two packs fighting for the same ports | Both running | **Stop** one, **start** the other |

### After you switch packs

| Stays the same | You must redo |
|---|---|
| Seeded users and clients | Remint tokens (issuer `:8080` vs `:9000`) |
| Claim rules (`tid`, roles) | Set `$Build` / `$KC` / `$API` for the new pack |
| API behaviour once hosts match | Confirm health again ([§5.1](#51-confirm-the-build-succeeded)) |

Postgres volume `pgdata_lab` is **kept** across stop/start unless you wipe volumes.

### After you choose

1. Take the zip for that pack ([§2](#2-what-packs-you-get)).
2. Install and start it ([§4](#4-get-it-installed-and-running)).
3. Confirm and operate the stack ([§5](#5-after-start-operate-the-stack)).

---

## 4. Get it installed and running

### 4.1 Prerequisites

- **Docker Desktop** (Mac/Windows) or **Docker Engine + Compose v2** (Linux), running
- The **handoff zip** for the pack you chose in [§3](#3-which-pack-to-choose)
- **Windows:** PowerShell 5.1 or 7 · **macOS/Linux:** Terminal, and PowerShell 7 (`pwsh`) if you want the `.ps1` helpers
- Disk space for the images in the zip (hundreds of MB per pack when offline images are included)
- Ports free on localhost for that pack (Base needs `:8080`, `:8000`, `:9000`, `:9901`, `:5433`; Secure/PKI need `:9000`, `:9901`, `:5433`)

You do **not** need a git clone of this repository to run the downloadable zip.

### 4.2 Download and unpack

1. Get the zip from your operator (email, share, release drop — whatever they use).
2. Unpack it to a folder you control.

```powershell
# Windows
Expand-Archive .\gd-authbox-handoff-<pack>-2.1.0-*.zip -DestinationPath .
cd gd-authbox-handoff-<pack>-2.1.0-*   # use the real folder name
```

```bash
# macOS / Linux
unzip gd-authbox-handoff-<pack>-2.1.0-*.zip
cd gd-authbox-handoff-<pack>-2.1.0-*
chmod +x start-pack.sh stop-pack.sh sandbox-ctl.sh
```

That folder is your **pack root** (contains `start-pack.ps1` / `start-pack.sh` and `release/`).

### 4.3 Start the pack

```powershell
.\start-pack.ps1
```

```bash
./start-pack.sh
```

What `start-pack` does: loads image tars from the zip, writes `.env` from `.env.example` when missing (Base PKI also writes the step-ca password file), starts the build baked into that zip. Pass: it prints that services are ready.

Then go to [§5.1](#51-confirm-the-build-succeeded).

Quick health from the pack:

```powershell
cd release\helpers
. .\set-build.ps1 -Build base          # or base-secure / base-pki
. .\health-build.ps1
```

### 4.4 Stop the pack

From the **same** pack root:

```powershell
.\stop-pack.ps1
```

```bash
./stop-pack.sh
```

Stops containers and **keeps** the database volume. To wipe realm data, use a volume-removing stop on the checkout controller (`down-volumes` / `-Volumes`) — that deletes `pgdata_lab`.

### 4.5 What you can do once it is up (by pack)

**Base**

| You can… | Where to go next |
|---|---|
| Confirm containers and ports | [§5.1](#51-confirm-the-build-succeeded) |
| Open Keycloak Admin | [§5.2](#52-keycloak) — `http://localhost:8080` |
| Mint a token | [§5.2.6](#526-mint-a-token-all-packs) |
| Open Swagger / call API | [§5.4](#54-authbox-api) — `http://localhost:8000/docs` |
| Check Postgres / Envoy | [§5.3](#53-postgres) · [§5.5](#55-envoy) |

**Base Secure** — same API/token story on `:9000` only; direct `:8000`/`:8080` must stay closed; no Admin UI on host; no Swagger on `:8000`.

**Base PKI** — same as Secure, plus step-ca and device listeners `:1029` / `:8883`: [§5.5.8](#558-device-ports-on-base-pki) · [§5.6](#56-step-ca). Create/renew leaves from pack root:

```powershell
.\devx\pki\issue-client-cert.ps1 -CommonName device-001
.\devx\pki\refresh-client-cert.ps1 -CommonName device-001
```

Checkout start (from a product clone): `bring-up/` (`configure` / `start -Package base|base-secure|base-pki`) or `devx/sandbox-ctl` (`up` / `down` / `status`). Not required when you have the zip.

---

## 5. After start — operate the stack

Do this **after** [§4](#4-get-it-installed-and-running) succeeds. Confirm the pack first, then work through the services for your pack. Skip [§5.6](#56-step-ca) unless you started **Base PKI**.

## 5.1 Confirm the build succeeded

Do this after you know which pack you started. Do it before you open Keycloak, Swagger, or the scenario page. If this section fails, stop and fix the build.

### What “succeeded” means

The build you started has:

1. The right containers running
2. Each required container reporting healthy (or ready)
3. The host ports that build is supposed to open answering a simple check
4. On Base Secure and Base PKI, the direct ports that must stay closed really closed

That is all. You are not signing in yet. You are not minting a token yet.

### Step 1 — See the containers

| | |
|---|---|
| **Where** | Your machine — terminal (pack root). Docker must be running |
| **Why** | Prove the pack started the right containers before you open any UI |

**Steps**

1. Open PowerShell (Windows) or Terminal (macOS / Linux).
2. `cd` to the **unpacked pack folder** (the folder that contains `release/` and `start-pack.ps1`). If you only have a git checkout, use that checkout root instead.
3. Run:

```powershell
# Windows PowerShell / PowerShell 7 (also fine on macOS/Linux if you use pwsh)
docker ps --filter "name=auth-sandbox-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```bash
# macOS / Linux (bash or zsh) — same Docker command
docker ps --filter "name=auth-sandbox-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

| Build you started | Containers that must be listed |
|---|---|
| **Base** | `auth-sandbox-postgres-1`, `auth-sandbox-keycloak-1`, `auth-sandbox-authbox-api-1`, `auth-sandbox-envoy-1` |
| **Base Secure** | The same four |
| **Base PKI** | The same four, plus `auth-sandbox-step-ca-1` |

Every listed row must show `Up` (or `Up … (healthy)`). A container that is missing, `Exited`, or `Restarting` means the build did not succeed.

| | |
|---|---|
| **Where** | Same terminal |
| **Why** | Read why that container failed |

```powershell
# Windows / pwsh
docker logs --tail 80 auth-sandbox-authbox-api-1
```

```bash
# macOS / Linux
docker logs --tail 80 auth-sandbox-authbox-api-1
```

Replace the name with the container that failed.

### Step 2 — Set the addresses for this build

| | |
|---|---|
| **Where** | Same terminal session you will keep open for later checks |
| **Why** | Later commands use `$KC` / `$API` (or `KC` / `API`) so you hit the right ports for this pack |

**Windows PowerShell / pwsh**

```powershell
# Base
$Build = "base"; $KC = "http://localhost:8080"; $API = "http://localhost:8000"
```

```powershell
# Base Secure
$Build = "base-secure"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

```powershell
# Base PKI
$Build = "base-pki"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

Or from the pack folder (or checkout root):

```powershell
. .\release\helpers\set-build.ps1 -Build base
# . .\release\helpers\set-build.ps1 -Build base-secure
# . .\release\helpers\set-build.ps1 -Build base-pki
```

**macOS / Linux (bash or zsh)**

```bash
# Base
Build=base; KC=http://localhost:8080; API=http://localhost:8000
```

```bash
# Base Secure
Build=base-secure; KC=http://localhost:9000; API=http://localhost:9000
```

```bash
# Base PKI
Build=base-pki; KC=http://localhost:9000; API=http://localhost:9000
```

The helper scripts under `release/helpers/` are PowerShell. On macOS/Linux either install PowerShell 7 and run them with `pwsh`, or set `Build` / `KC` / `API` as above and run the checks by hand.

### Step 3 — Run the success checks for your build

| | |
|---|---|
| **Where** | Same terminal, **or** your browser for the HTTP URLs |
| **Why** | Confirm each service answers the way this pack should |

#### Base

| # | What you check | Where | Why | Pass looks like |
|---|---|---|---|---|
| 1 | Postgres accepts connections | Terminal → `docker exec` into Postgres | Realm storage is up | `accepting connections` |
| 2 | API health | Browser or terminal HTTP | authbox-api is up | `{"status":"ok"}` |
| 3 | Keycloak discovery | Browser or terminal HTTP | IdP issuer document is up | Status `200` |
| 4 | Envoy admin ready | Browser or terminal HTTP | Gateway process is ready | Status `200` |
| 5 | Gateway health | Browser or terminal HTTP | Envoy forwards to the API | `{"status":"ok"}` |

**Browser (any OS):** open the URLs in the table below.

**Windows PowerShell**

```powershell
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
Invoke-RestMethod "http://localhost:8000/authbox/health"
(Invoke-WebRequest -Uri "http://localhost:8080/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing).StatusCode
(Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode
Invoke-RestMethod "http://localhost:9000/authbox/health"
```

```powershell
# Or with curl.exe on Windows
curl.exe -sS "http://localhost:8000/authbox/health"
curl.exe -sS -o NUL -w "%{http_code}" "http://localhost:8080/realms/nexus-test/.well-known/openid-configuration"
curl.exe -sS -o NUL -w "%{http_code}" "http://localhost:9901/ready"
```

**macOS / Linux**

```bash
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
curl -sS "http://localhost:8000/authbox/health"
curl -sS -o /dev/null -w "%{http_code}\n" "http://localhost:8080/realms/nexus-test/.well-known/openid-configuration"
curl -sS -o /dev/null -w "%{http_code}\n" "http://localhost:9901/ready"
curl -sS "http://localhost:9000/authbox/health"
```

#### Base Secure

| # | What you check | Where | Why | Pass looks like |
|---|---|---|---|---|
| 1 | Postgres | Terminal → `docker exec` | Same as Base | `accepting connections` |
| 2 | API health through gateway | Browser / terminal → `:9000` | Direct API port is unpublished | `{"status":"ok"}` |
| 3 | Keycloak discovery through gateway | Browser / terminal → `:9000` | Direct Keycloak port is unpublished | Status `200` |
| 4 | Envoy admin | Browser / terminal → `:9901` | Gateway ready | Status `200` |
| 5 | Direct ports closed | Browser / terminal → `:8000` and `:8080` | Prove this is the secure pack | Connection fails (that failure is the pass) |

**Windows PowerShell**

```powershell
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
Invoke-RestMethod "http://localhost:9000/authbox/health"
(Invoke-WebRequest -Uri "http://localhost:9000/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing).StatusCode
(Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode
```

**macOS / Linux**

```bash
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
curl -sS "http://localhost:9000/authbox/health"
curl -sS -o /dev/null -w "%{http_code}\n" "http://localhost:9000/realms/nexus-test/.well-known/openid-configuration"
curl -sS -o /dev/null -w "%{http_code}\n" "http://localhost:9901/ready"
```

Do **not** expect `http://localhost:8000` or `http://localhost:8080` to open. If they open, this is not Base Secure.

#### Base PKI

Run every Base Secure check above, then:

| | |
|---|---|
| **Where** | Your machine — terminal. The command runs **inside** `auth-sandbox-step-ca-1` |
| **Why** | Prove the certificate authority is serving. Host `:9000` is still Envoy; `:9000` in this command is only inside the CA container |

```powershell
# Windows / pwsh / macOS / Linux — same Docker line
docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

Pass: prints `ok`.

On Base PKI, confirm host ports `1029` and `8883` on the Envoy container when the device edge is enabled ([§5.5.8](#558-device-ports-on-base-pki)).

### One-command shortcut

| | |
|---|---|
| **Where** | Pack root (or checkout root), PowerShell or `pwsh` |
| **Why** | Run the same success checks without pasting each line |

```powershell
# Windows PowerShell (from pack root), after Step 2
. .\release\helpers\health-build.ps1
```

```powershell
# macOS / Linux with PowerShell 7 installed
pwsh -File ./release/helpers/set-build.ps1 -Build base   # or base-secure / base-pki — dot-source if you stay in pwsh
. ./release/helpers/health-build.ps1
```

A pass ends with `DONE all PASS`. Any `FAIL` line means that piece is not up. Fix that piece, then run the script again. On macOS/Linux without `pwsh`, use the hand checks in Step 3 instead.

### What you should see in a browser (Base)

| Address | Meaning when it opens |
|---|---|
| `http://localhost:8080` | Keycloak is up (you will sign in in the next section) |
| `http://localhost:8000/authbox/health` | API answers `ok` |
| `http://localhost:8000/docs` | Auth-Box API Swagger is reachable |
| `http://localhost:9000/authbox/health` | Gateway forwards to the API |
| `http://localhost:9901/ready` | Envoy admin reports ready |

On Base Secure and Base PKI, use only the `:9000` and `:9901` rows. The `:8080` and `:8000` rows must not open.

### If a check fails

| Symptom | What to do first |
|---|---|
| Container missing or `Exited` | `docker logs --tail 80` on that container |
| API health fails | Confirm Keycloak discovery already returns `200` for this build’s `$KC`, then read `auth-sandbox-authbox-api-1` logs |
| Keycloak discovery fails | Confirm Postgres is accepting connections, then read `auth-sandbox-keycloak-1` logs |
| Envoy admin not ready | Read `auth-sandbox-envoy-1` logs |
| step-ca not `ok` | Confirm the build is Base PKI and the step-ca container is listed, then read its logs |
| Port 8000 or 8080 still open on Base Secure / Base PKI | You started the wrong build, or an older Base stack is still running. Stop the running build and start the one you want |

### When you may continue

All checks for your pack passed. You have not signed in yet.

**Next:** [§5.2 Keycloak](#52-keycloak) — open the identity provider for your pack.

---

## 5.2 Keycloak

Keycloak is the identity provider for every pack. It holds realm `nexus-test`, the users, the clients, and the roles. It issues the access tokens the API later checks.

Finish [§5.1 Confirm the build succeeded](#51-confirm-the-build-succeeded) first. Secret values are never written in this guide. Use the environment **names** in [README.md](README.md).

### 5.2.1 How Keycloak behaves in each pack

The Keycloak **container** is the same on all three packs. What changes is how you reach it from your machine.

| What you want to do | **Base** | **Base Secure** | **Base PKI** |
|---|---|---|---|
| Open the **Admin Console** in a browser | Yes — `http://localhost:8080` | No — host `:8080` is unpublished | No — same as Base Secure |
| Open Admin Console through the gateway (`http://localhost:9000/admin/`) | No — the gateway does **not** route `/admin/` | No | No |
| Open OIDC discovery (token issuer document) | `http://localhost:8080/realms/nexus-test/.well-known/openid-configuration` | `http://localhost:9000/realms/nexus-test/.well-known/openid-configuration` | Same as Base Secure |
| Mint a user or machine token | Against `:8080` | Against `:9000` | Against `:9000` |
| Issuer the API expects on tokens | `http://localhost:8080/realms/nexus-test` | `http://localhost:9000/realms/nexus-test` | Same as Base Secure |
| List clients / run admin commands without the UI | Use Admin Console, or `kcadm` | Use `kcadm` inside the container | Same as Base Secure |
| step-ca involved in Keycloak | No | No | No — step-ca is separate |

**Practical rule**

- Want the Keycloak **screens** (users, roles, clients)? Use **Base**.
- On **Base Secure** or **Base PKI**, Keycloak still issues tokens through the gateway path `/realms/`. You manage the realm with `kcadm` inside the container, or you temporarily start **Base** when you need the Admin Console.

A token minted on `:8080` will not evaluate correctly against an API that expects issuer `:9000`, and the reverse. Always mint against the `$KC` for the pack you have running.

### 5.2.2 What is already prepared for you

Seed has already created realm `nexus-test`. You do not create that realm from scratch.

| Kind | What you should find |
|---|---|
| Realm | `nexus-test` (also `master` for the admin account) |
| Users | `testuser` (`AUTHBOX_USER_A`), `tenant_b_user` (`AUTHBOX_USER_B`), plus IoT users such as `iot-operator` and `iot-device` |
| User attributes | On `testuser`: `tenant_id` = `tenant_a`, `clearance` = `high`. On `tenant_b_user`: `tenant_id` = `tenant_b`, `clearance` = `low` |
| Realm roles | `admin`, `operator`, `viewer`, `device`, `config_read`, `data_scientist` |
| Role mapping | `testuser` has `admin` and `operator`. `tenant_b_user` has `viewer` |
| Clients | `nexus-sandbox` (people / password grant), `nexus-m2m` (machines), `iot-admin-app`, `nodered` |
| Token claim | User attribute `tenant_id` is mapped onto access-token claim `tid` on the password-grant client |

`iot-admin-app` and `nodered` are Keycloak clients only. This pack does not ship those browser apps as images.

### 5.2.3 Open Keycloak — Base (Admin Console)

Use **Base** for the Admin Console on the host.

1. Confirm the pack is Base and [§5.1](#51-confirm-the-build-succeeded) passed.
2. In a browser open `http://localhost:8080`.
3. Open **Administration Console**.
4. Sign in with the admin user already set in the Keycloak container: environment names `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` (values are in your `.env`, not on this page).
5. At the top-left realm selector, switch from `master` to `nexus-test`.

You are now in realm `nexus-test`. Stay on it for the rest of this section unless a step says otherwise.

#### What you can do in the Admin Console

| Screen (left menu) | What you do | What you should see |
|---|---|---|
| **Realm settings** | Open the realm | Name `nexus-test`. This is the issuer realm |
| **Users** | List users | `testuser`, `tenant_b_user`, and the IoT users |
| **Users → select a user → Details** | Read username and email | The seeded people users |
| **Users → Attributes** | Open attributes | `tenant_id` and `clearance` on `testuser` |
| **Users → Role mapping** | Open Assigned roles | `testuser`: `admin`, `operator`. `tenant_b_user`: `viewer` |
| **Users → Credentials** | Set or reset a password | Only if you create a new user or intentionally change a password |
| **Users → Sessions** | After someone signs in | Active sessions for that user |
| **Realm roles** | List roles | The six realm roles listed above |
| **Clients** | List clients | `nexus-sandbox`, `nexus-m2m`, `iot-admin-app`, `nodered` |
| **Clients → nexus-sandbox** | Open Settings / Credentials / Client scopes | Password grant and browser login live here. The mapper turns `tenant_id` into claim `tid` |
| **Clients → nexus-m2m** | Open Settings / Credentials | Machine client (`client_credentials`) |
| **Client scopes / Mappers** | Inspect how claims are built | Do not delete the `tid` mapper — seeded token checks depend on it |

#### Create a realm role

1. Realm `nexus-test` → **Realm roles** → **Create role**.
2. Enter a name you will remember (for example `ops_reader`).
3. Save.

You can assign this role to a user later. Scenario checks that ask for `viewer` or `admin` still use the seeded roles. A new role is only useful if your API calls also require that role name.

#### Create a user

1. Realm `nexus-test` → **Users** → **Add user**.
2. Set **Username** (for example `ops_user`). Enable the user. Create.
3. Open **Credentials** → set a password. Turn temporary off if you want to reuse it without a forced change.
4. Open **Attributes** → add `tenant_id` with value `tenant_a` (or `tenant_b`). Without this attribute, password-grant tokens for `nexus-sandbox` will not carry a usable `tid`, and the API will reject them.
5. Open **Role mapping** → assign at least one realm role (for example `viewer`).
6. Save.

Then mint a token for that user the same way you mint for `AUTHBOX_USER_A` (see [§5.2.6](#526-mint-a-token-all-packs)). Decode the middle part of the JWT and confirm claim `tid` matches the attribute you set.

#### Sign in as a normal user (Account Console)

On Base you can also open the account page for a person user:

1. Open `http://localhost:8080/realms/nexus-test/account/`.
2. Sign in with `AUTHBOX_USER_A` / `AUTHBOX_USER_A_PASSWORD` (or the user you created).
3. Browse the account screens (personal info, sessions).

This is the **user** experience, not the admin console. Sign out when finished so sessions stay clear.

### 5.2.4 Keycloak on Base Secure

Keycloak is running. Host port `8080` is closed on purpose.

| Action | How on Base Secure |
|---|---|
| Confirm Keycloak answers | Open `http://localhost:9000/realms/nexus-test/.well-known/openid-configuration` — status `200` |
| Mint tokens | `POST http://localhost:9000/realms/nexus-test/protocol/openid-connect/token` (see [§5.2.6](#526-mint-a-token-all-packs)) |
| Open Admin Console in the browser | **Not available** on this pack. `http://localhost:8080` does not connect. `http://localhost:9000/admin/` is not routed |
| Inspect users / roles / clients | Run `kcadm` inside the container ([§5.2.7](#527-admin-commands-without-the-ui)), or stop this pack and start **Base** for the UI |
| Issuer on tokens | Must be `http://localhost:9000/realms/nexus-test` so the API on the gateway accepts them |

You can still **use** Keycloak fully as an IdP (login, tokens, roles inside the token). You cannot open the Admin Console through the published ports of this pack.

### 5.2.5 Keycloak on Base PKI

Same behaviour as **Base Secure** for Keycloak.

| Extra on Base PKI | Relation to Keycloak |
|---|---|
| `auth-sandbox-step-ca-1` | Separate certificate authority. It does not replace Keycloak and does not open the Admin Console |
| Device ports `:1029` / `:8883` | Envoy listeners. Device identity uses certificates; people and machines still get JWTs from Keycloak |

Open discovery and mint tokens on `http://localhost:9000` exactly as on Base Secure. For Admin Console screens, use **Base**.

### 5.2.6 Mint a token (all packs)

| | |
|---|---|
| **Where** | Your machine — terminal (same session as §5.1). Not inside a container |
| **Why** | Get an access token from Keycloak so the authbox-api can accept you later |

Set `$KC` / `KC` for your pack first ([§5.1 Step 2](#step-2-set-the-addresses-for-this-build)):

| Pack | `$KC` / `KC` |
|---|---|
| Base | `http://localhost:8080` |
| Base Secure / Base PKI | `http://localhost:9000` |

Environment names must already be set in this terminal ([README.md](README.md)).

**Downloadable pack:** after `start-pack`, the pack `.env` uses `NEXUS_SIMULATOR_KEYCLOAK_USER` / `NEXUS_SIMULATOR_KEYCLOAK_PASSWORD` for the first seeded person (claim `tid` = `tenant_a`). Map them once, then the lines below work:

```powershell
# From the unpacked pack folder — load .env into the session, then alias
Get-Content .\.env | ForEach-Object { if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }; $p = $_.Split('=',2); Set-Item -Path "Env:$($p[0].Trim())" -Value $p[1].Trim() }
if (-not $env:AUTHBOX_USER_A) { $env:AUTHBOX_USER_A = $env:NEXUS_SIMULATOR_KEYCLOAK_USER; $env:AUTHBOX_USER_A_PASSWORD = $env:NEXUS_SIMULATOR_KEYCLOAK_PASSWORD }
if (-not $env:AUTHBOX_USER_B) { $env:AUTHBOX_USER_B = $env:NEXUS_SIMULATOR_TENANT_B_USER; $env:AUTHBOX_USER_B_PASSWORD = $env:NEXUS_SIMULATOR_TENANT_B_PASSWORD }
```

```bash
# macOS / Linux — from the unpacked pack folder
set -a; . ./.env; set +a
export AUTHBOX_USER_A="${AUTHBOX_USER_A:-$NEXUS_SIMULATOR_KEYCLOAK_USER}"
export AUTHBOX_USER_A_PASSWORD="${AUTHBOX_USER_A_PASSWORD:-$NEXUS_SIMULATOR_KEYCLOAK_PASSWORD}"
export AUTHBOX_USER_B="${AUTHBOX_USER_B:-$NEXUS_SIMULATOR_TENANT_B_USER}"
export AUTHBOX_USER_B_PASSWORD="${AUTHBOX_USER_B_PASSWORD:-$NEXUS_SIMULATOR_TENANT_B_PASSWORD}"
```

**Windows PowerShell — password grant** (prints `tid` and roles, not the raw token string):

```powershell
$raw = Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=password&client_id=$env:NEXUS_AUTH_CLIENT_ID&client_secret=$env:NEXUS_AUTH_CLIENT_SECRET&username=$env:AUTHBOX_USER_A&password=$env:AUTHBOX_USER_A_PASSWORD"; $TokenA = $raw.access_token; $p = $TokenA.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json; "tid=$($c.tid) roles=$($c.roles -join ',')"
```

**Windows PowerShell — machine token**

```powershell
$raw = Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=client_credentials&client_id=$env:NEXUS_SIMULATOR_M2M_CLIENT_ID&client_secret=$env:NEXUS_AUTH_M2M_CLIENT_SECRET"; $TokenM = $raw.access_token; $p = $TokenM.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json; "tid=$($c.tid)"
```

**macOS / Linux — password grant** (needs `python3` for the claim print):

```bash
RESP=$(curl -sS -X POST "$KC/realms/nexus-test/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=${NEXUS_AUTH_CLIENT_ID}&client_secret=${NEXUS_AUTH_CLIENT_SECRET}&username=${AUTHBOX_USER_A}&password=${AUTHBOX_USER_A_PASSWORD}")
TokenA=$(printf '%s' "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
python3 -c "import sys,json,base64; p=sys.argv[1].split('.')[1]; p+='='*((4-len(p)%4)%4); c=json.loads(base64.urlsafe_b64decode(p.encode())); print('tid=%s roles=%s' % (c.get('tid'), ','.join(c.get('roles') or [])))" "$TokenA"
```

**macOS / Linux — machine token**

```bash
RESP=$(curl -sS -X POST "$KC/realms/nexus-test/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${NEXUS_SIMULATOR_M2M_CLIENT_ID}&client_secret=${NEXUS_AUTH_M2M_CLIENT_SECRET}")
TokenM=$(printf '%s' "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
python3 -c "import sys,json,base64; p=sys.argv[1].split('.')[1]; p+='='*((4-len(p)%4)%4); c=json.loads(base64.urlsafe_b64decode(p.encode())); print('tid=%s' % c.get('tid'))" "$TokenM"
```

Pass: person user shows `tid=tenant_a` with `admin` and `operator`. Machine shows `tid=tenant_a`.

**Postman (any OS):** `POST {{keycloak}}/realms/nexus-test/protocol/openid-connect/token`, body x-www-form-urlencoded, same field names. Save `access_token` as `token_a` or `token_m`.

On Windows, a secret-bearing `curl.exe` call should use `curl.exe --config` on a UTF-8 file with no byte-order mark (environment names in the file, not pasted secrets on the command line). Keep `$TokenA` / `TokenA` for [§5.4](#54-authbox-api). Do not paste tokens into this guide or into chat logs.

### 5.2.7 Admin commands without the UI

| | |
|---|---|
| **Where** | Your machine — terminal. The tools run **inside** `auth-sandbox-keycloak-1` |
| **Why** | List clients and users when the Admin Console is not on a host port (Base Secure / Base PKI), or when you prefer the CLI |

**Steps (any OS):** open a terminal → run the lines below. Docker talks to the container; you do not SSH into the host.

```powershell
# Windows PowerShell — single quotes keep $KEYCLOAK_* for the container shell
docker exec auth-sandbox-keycloak-1 sh -c '/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD"'
```

```bash
# macOS / Linux — same idea; keep double quotes inside so the container expands the names
docker exec auth-sandbox-keycloak-1 sh -c '/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD"'
```

```powershell
# Windows / macOS / Linux — list clients
docker exec auth-sandbox-keycloak-1 /opt/keycloak/bin/kcadm.sh get clients -r nexus-test --fields clientId
```

```powershell
# Windows / macOS / Linux — list users
docker exec auth-sandbox-keycloak-1 /opt/keycloak/bin/kcadm.sh get users -r nexus-test --fields username
```

Pass: clients include `nexus-sandbox`, `nexus-m2m`, `iot-admin-app`, `nodered`. Users include `testuser` and `tenant_b_user`. Re-run the credentials command after the Keycloak container is recreated.

### 5.2.8 What you should and should not change

| Safe while operating | Avoid (breaks the seeded pack / scenario pass) |
|---|---|
| Browse realm, users, roles, clients | Delete realm `nexus-test` |
| Create an extra user / role | Remove attribute `tenant_id` from `testuser` / `tenant_b_user` |
| Reset a user’s password | Delete the `tid` client mapper on `nexus-sandbox` |
| Inspect sessions after a login | Change the public issuer / hostname without restarting the API to match |
| Use `kcadm` to list objects | Wipe volume `pgdata_lab` unless you intend to lose the realm |

If the seeded realm is broken, the clean recovery is to stop the pack and start again without wiping volumes when possible; wiping `pgdata_lab` recreates an empty database and seed must run again.

### 5.2.9 Quick checklist — Keycloak per pack

| Check | Base | Base Secure | Base PKI |
|---|---|---|---|
| Admin Console opens on `:8080` | yes | no | no |
| Discovery returns `200` on that pack’s `$KC` | yes | yes | yes |
| Password-grant token shows `tid=tenant_a` for user A | yes | yes | yes |
| Machine token shows `tid=tenant_a` | yes | yes | yes |
| `kcadm` lists clients | yes | yes | yes |
| Gateway `/admin/` opens Admin Console | no | no | no |

### 5.2.10 When you may continue

You can open Keycloak for your pack (UI on Base, discovery + tokens + `kcadm` on every pack). You understand what is already seeded and how creating a user needs `tenant_id` for claim `tid`.

**Next:** [§5.3 Postgres](#53-postgres) — see where that realm is stored. Then [§5.4 authbox-api](#54-authbox-api).

Claims and clients: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Progressive checks: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

---

## 5.3 Postgres

Postgres is Keycloak’s database. Realms, users, clients, and sessions live here so they survive a container restart. The **authbox-api does not open a database connection**. URL tenants you create through the API live only in the API process until that process restarts.

Finish [§5.1](#51-confirm-the-build-succeeded) first. Prefer finishing [§5.2 Keycloak](#52-keycloak) so the users you query make sense.

### 5.3.1 How Postgres behaves in each pack

| What you want to do | **Base** | **Base Secure** | **Base PKI** |
|---|---|---|---|
| Container present | yes — `auth-sandbox-postgres-1` | yes | yes |
| Database name | `authbox_lab` | `authbox_lab` | `authbox_lab` |
| Volume | `pgdata_lab` | `pgdata_lab` | `pgdata_lab` |
| Host port | `:5433` → container `5432` | `:5433` | `:5433` |
| GUI from this pack | none — use terminal, or a GUI client you install yourself | same | same |
| Who writes the schema | Keycloak | Keycloak | Keycloak |
| step-ca data here | no | no | no — step-ca has its own volume |

Postgres is the same story on all three packs. Pack differences for Keycloak and the API do not change the database name or host port `5433`.

### 5.3.2 What is already prepared for you

| Kind | What you should find |
|---|---|
| Database | `authbox_lab` |
| Realms in Keycloak tables | `nexus-test` and `master` |
| Users | `testuser`, `tenant_b_user`, `iot-operator`, `iot-device` |
| Attributes | `tenant_id` / `clearance` on the people users (token claim `tid` comes from `tenant_id`) |

### 5.3.3 Check that Postgres is ready

| | |
|---|---|
| **Where** | Your machine — terminal. Command runs **inside** the Postgres container |
| **Why** | Confirm the database accepts connections before you query it |

**Steps:** open a terminal (pack root is fine) → run:

```powershell
# Windows PowerShell / pwsh / macOS / Linux — same Docker line
docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab
```

Pass:

```text
/var/run/postgresql:5432 - accepting connections
```

Always pass `-d authbox_lab`. Without it, the probe asks for a database named like the user and logs errors while looking “healthy.”

Container health status:

```powershell
docker inspect auth-sandbox-postgres-1 --format "{{.State.Health.Status}}"
```

Pass: `healthy`.

### 5.3.4 See realms and users (read-only)

| | |
|---|---|
| **Where** | Your machine — terminal → `psql` **inside** the Postgres container |
| **Why** | Prove the Keycloak users you saw in §3 are stored on disk |

**List realms**

```powershell
# Any OS
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT name FROM realm ORDER BY name;"
```

Pass: includes `nexus-test` and `master`.

**List users in** `nexus-test`

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT username FROM user_entity WHERE realm_id = (SELECT id FROM realm WHERE name = 'nexus-test') ORDER BY username;"
```

Pass: includes `testuser`, `tenant_b_user`, `iot-operator`, `iot-device`.

**Read stored attributes**

```powershell
docker exec auth-sandbox-postgres-1 psql -U nexus -d authbox_lab -c "SELECT u.username, ua.name, ua.value FROM user_attribute ua JOIN user_entity u ON u.id = ua.user_id WHERE u.username IN ('testuser','tenant_b_user') ORDER BY u.username, ua.name;"
```

Pass: `testuser` has `tenant_id` = `tenant_a` and `clearance` = `high`. `tenant_b_user` has `tenant_id` = `tenant_b` and `clearance` = `low`.

### 5.3.5 Connect a GUI client from your machine

| | |
|---|---|
| **Where** | An app you install (DBeaver, pgAdmin, TablePlus, Azure Data Studio, …) on Windows, macOS, or Linux |
| **Why** | Browse tables visually. Not required |

| Setting | Value |
|---|---|
| Host | `localhost` |
| Port | `5433` |
| Database | `authbox_lab` |
| User | environment name `POSTGRES_USER` (already set in the container; same name in your `.env`) |
| Password | environment name `POSTGRES_PASSWORD` |

Do not paste password values into this guide. Prefer the `docker exec … psql` commands if you only need a quick look.

### 5.3.6 What you should and should not change

| Safe while operating | Avoid |
|---|---|
| Read-only `SELECT` as above | `DROP` / `DELETE` on Keycloak tables |
| Confirm volume still present after an API recreate | `docker volume rm` on `pgdata_lab` unless you intend to wipe the realm |
| Use a GUI in read-only mode | Pointing an unrelated app at this pack database by accident |

Wiping `pgdata_lab` deletes the realm. Start again only when you mean to; seed must recreate users.

### 5.3.7 Quick checklist — Postgres per pack

| Check | Base | Base Secure | Base PKI |
|---|---|---|---|
| `pg_isready` accepting | yes | yes | yes |
| Host port `5433` published | yes | yes | yes |
| Realms include `nexus-test` | yes | yes | yes |
| Users include `testuser` | yes | yes | yes |
| API writes here | no | no | no |

### 5.3.8 When you may continue

You know Postgres holds Keycloak’s realm, how to prove it is up, and how to list users and `tenant_id` attributes.

**Next:** [§5.4 authbox-api](#54-authbox-api).

Contracts: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Progressive checks: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

---

## 5.4 authbox-api

The **authbox-api** is the Auth-in-a-Box HTTP API. It verifies tokens from Keycloak and exposes identity routes under `/authbox/{tenant}/{instance}/api/v1/`. The seeded URL path uses tenant `default` and instance `default`. Claim `tid` on the token is separate: `testuser` still has `tid` = `tenant_a` while evaluate returns URL field `tenant_id` = `default`.

Finish [§5.1](#51-confirm-the-build-succeeded). Mint a token in [§5.2.6](#526-mint-a-token-all-packs) so you have `$TokenA` / `TokenA` (or Postman `token_a`).

### 5.4.1 How the API behaves in each pack

| What you want to do | **Base** | **Base Secure** | **Base PKI** |
|---|---|---|---|
| Open **Swagger UI** | Yes — `http://localhost:8000/docs` | No — host `:8000` unpublished | No |
| Open OpenAPI JSON | `http://localhost:8000/openapi.json` | Not on host `:8000` | Not on host `:8000` |
| Call health / authorize / evaluate | `$API` = `http://localhost:8000` **or** gateway `http://localhost:9000` | `$API` = `http://localhost:9000` only | Same as Base Secure |
| Index `GET /authbox/` version `7.0.0` | On `:8000` | Use gateway; some index paths differ — prefer health + evaluate | Same |
| Missing bearer on protected route | JSON `401` from the API on `:8000` | Plain text `Jwt is missing` from Envoy first | Same as Base Secure |
| Edge / Aadhaar / wallet / OTP helper | Available on direct `:8000` | Often blocked or skipped at the gateway — use Base for those routes | Same |
| Device-trust routes | With bearer | With bearer through gateway | Emphasized; same bearer calls |

**Practical rule:** use **Base** for Swagger and for calls that send no bearer. Use Base Secure / Base PKI when you want the gateway in front of the same API.

### 5.4.2 What you can do with the API

| Goal | Typical path | Needs bearer? |
|---|---|---|
| Health | `GET /authbox/health` | no |
| Service index (Base) | `GET /authbox/` | no |
| Login link | `GET .../api/v1/auth/authorize` | no |
| Evaluate token | `GET .../api/v1/verifier/evaluate` | yes |
| MFA enroll / challenge / verify | `.../api/v1/mfa/...` | yes |
| Edge / IUDX verify helpers | `.../api/v1/auth/edge/verify`, `.../auth/iudx/verify` | yes for success |
| MCP validate / config | `.../api/v1/mcp/...` | yes |
| URL tenants | `POST /authbox/admin/v1/tenants` | yes |
| Device trust | `.../api/v1/auth/device-trust/...` | yes (`admin` or `operator`) |
| Full numbered pass | [SCENARIO-TESTING.md](SCENARIO-TESTING.md) | mixed |

### 5.4.3 Open Swagger — Base

| | |
|---|---|
| **Where** | Your machine — browser |
| **Why** | Try routes from a form UI without writing every curl by hand |

**Steps**

1. Confirm the pack is **Base** and §5.1 passed.
2. Open `http://localhost:8000/docs`.
3. You should see the FastAPI / Swagger page titled around Nexus-Auth / Auth-in-a-Box.
4. Expand **GET /authbox/health** → **Try it out** → **Execute**. Response body includes `"status":"ok"`.
5. Expand **GET /authbox/default/default/api/v1/auth/authorize** → Execute. Note field `url` (Keycloak login link) and `_sandbox_code_verifier`.
6. For evaluate: click **Authorize** (lock icon) if the page offers bearer auth, paste the access token from §5.2.6 (not into this guide), then **GET .../verifier/evaluate** → Execute. Expect `status` `success`, `tenant_id` `default`, `instance_id` `default`.

On Base Secure / Base PKI, skip Swagger on `:8000`. Use Postman or the terminal against `http://localhost:9000` instead.

### 5.4.4 Set `$API` for your pack

| | |
|---|---|
| **Where** | Same terminal session as §5.1 / §5.2.6 |
| **Why** | All examples below use `$API` / `API` |

| Pack | `$API` / `API` |
|---|---|
| Base (direct) | `http://localhost:8000` |
| Base (also via gateway) | `http://localhost:9000` |
| Base Secure / Base PKI | `http://localhost:9000` |

```powershell
# Windows — example Base
$API = "http://localhost:8000"
```

```bash
# macOS / Linux — example Base
API=http://localhost:8000
```

### 5.4.5 Health

| | |
|---|---|
| **Where** | Browser and/or terminal on your machine |
| **Why** | Prove the API answers before token calls |

**Browser:** open `$API/authbox/health`.

**Windows PowerShell**

```powershell
Invoke-RestMethod "$API/authbox/health"
curl.exe -sS "$API/authbox/health"
```

**macOS / Linux**

```bash
curl -sS "$API/authbox/health"
```

**Postman:** `GET {{api}}/authbox/health`.

Pass: `{"status":"ok"}` (or PowerShell shows `status` = `ok`).

### 5.4.6 Authorize (login link)

| | |
|---|---|
| **Where** | Terminal or Postman or Swagger |
| **Why** | See the Keycloak authorization URL authbox-api builds for you |

**Windows PowerShell**

```powershell
$auth = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize?state=doc-state"; "state=$($auth.state) verifier_len=$($auth._sandbox_code_verifier.Length)"
```

**macOS / Linux**

```bash
curl -sS "$API/authbox/default/default/api/v1/auth/authorize?state=doc-state"
```

**Postman:** `GET {{api}}/authbox/default/default/api/v1/auth/authorize?state=doc-state`.

Pass: `state` is `doc-state`. Verifier length is at least `43`. Field `url` points at Keycloak on this pack’s `$KC`.

### 5.4.7 Evaluate a token

| | |
|---|---|
| **Where** | Terminal or Postman or Swagger (Base) |
| **Why** | Confirm the API accepts the Keycloak token and returns subject / roles / URL tenant |

Use `$TokenA` / `TokenA` from §5.2.6.

**Windows PowerShell**

```powershell
$ev = Invoke-RestMethod -Uri "$API/authbox/default/default/api/v1/verifier/evaluate" -Headers @{ Authorization = "Bearer $TokenA" }; "status=$($ev.status) tenant_id=$($ev.tenant_id) instance_id=$($ev.instance_id)"
```

**macOS / Linux**

```bash
curl -sS "$API/authbox/default/default/api/v1/verifier/evaluate" -H "Authorization: Bearer $TokenA"
```

**Postman:** `GET {{api}}/authbox/default/default/api/v1/verifier/evaluate`, Auth type Bearer, token `{{token_a}}`.

Pass: `status` = `success`, `tenant_id` = `default`, `instance_id` = `default`. Roles include `admin` and `operator` for user A.

**No token (compare packs)**

```powershell
# Windows
Invoke-WebRequest -Uri "$API/authbox/default/default/api/v1/verifier/evaluate" -UseBasicParsing
```

```bash
# macOS / Linux
curl -sS -i "$API/authbox/default/default/api/v1/verifier/evaluate"
```

Pass: status `401`. On Base against `:8000` the body is JSON. On Base Secure / Base PKI against `:9000` the body is often plain text `Jwt is missing` (Envoy).

### 5.4.8 Further checks on Base (Swagger or terminal)

| Try | What you confirm |
|---|---|
| Evaluate with `required_role=viewer` and user A token | `403` — user A does not have `viewer` |
| Evaluate with user B token and `required_role=viewer` | `200` — user B has `viewer` |
| MFA enroll then challenge/verify | One-time secret flow |
| Edge verify with bearer | Headers alone fail; token succeeds |
| Create URL tenant `org-a` / instance `dev`, evaluate on that path | Response `tenant_id` / `instance_id` follow the URL |

Full matrix: [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Contracts: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).

### 5.4.9 Confirm the API container

| | |
|---|---|
| **Where** | Terminal → Docker |
| **Why** | See process health and library versions inside the image |

```powershell
# Any OS
docker inspect auth-sandbox-authbox-api-1 --format "{{.State.Health.Status}}"
docker exec auth-sandbox-authbox-api-1 python -c "import importlib.metadata as m; print(m.version('nexus-auth'), m.version('nexus-common'))"
```

Pass: `healthy`, and versions `4.0.0` `3.4.0` on this edition.

### 5.4.10 What you should and should not change

| Safe while operating | Avoid |
|---|---|
| Call health, authorize, evaluate | Expect Swagger on Base Secure host `:8000` |
| Use Bearer tokens from this pack’s `$KC` | Mix a `:8080` token with a `:9000` API issuer |
| Create URL tenants via admin API | Treat URL `default` as the same as claim `tid` |
| Run [SCENARIO-TESTING.md](SCENARIO-TESTING.md) after this section | Wipe Postgres to “fix” the API — the API does not store the realm there |

### 5.4.11 Quick checklist — API per pack

| Check | Base | Base Secure | Base PKI |
|---|---|---|---|
| Swagger `http://localhost:8000/docs` | yes | no | no |
| Health on pack `$API` | yes | yes (`:9000`) | yes (`:9000`) |
| Authorize returns `url` | yes | yes | yes |
| Evaluate with user A token | yes | yes | yes |
| Missing bearer → Envoy `Jwt is missing` | only if you call `:9000` | yes | yes |

### 5.4.12 When you may continue

You can reach authbox-api for your pack, open Swagger on Base, and run health → authorize → evaluate with a Keycloak token.

**Next:** [§5.5 Envoy](#55-envoy) — the gateway. Then [§5.6 step-ca](#56-step-ca) on Base PKI.

Contracts: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Progressive checks: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

---

## 5.5 Envoy

Envoy is the gateway in front of Keycloak and the API. On every pack it listens on host `:9000` (traffic) and `:9901` (admin ready). On **Base Secure** and **Base PKI** it is the only host door for Keycloak and the API. On **Base** you can still use `:8080` and `:8000` directly; `:9000` is available as well.

Finish [§5.1](#51-confirm-the-build-succeeded). A token from [§5.2.6](#526-mint-a-token-all-packs) is required for the protected-path checks.

### 5.5.1 How Envoy behaves in each pack

| What you want to do | **Base** | **Base Secure** | **Base PKI** |
|---|---|---|---|
| Container | `auth-sandbox-envoy-1` | same | same |
| Gateway host port | `:9000` | `:9000` (required door) | `:9000` (required door) |
| Admin ready | `:9901/ready` | `:9901/ready` | `:9901/ready` |
| Forwards `/realms/` | to Keycloak | to Keycloak | to Keycloak |
| Forwards `/authbox/` | to API (JWT checked) | to API (JWT checked) | to API (JWT checked) |
| Keycloak Admin `/admin/` | **not** routed | **not** routed | **not** routed |
| Direct ports `:8000` / `:8080` | open (bypass gateway) | unpublished | unpublished |
| Device mTLS `:1029` | no | no | **yes** |
| MQTT `:8883` | no | no | **yes** |

### 5.5.2 What Envoy gives you (no product console)

Envoy has no Keycloak-style admin UI for policies. You use:

| Address | What it is |
|---|---|
| `http://localhost:9901/ready` | Admin “am I ready?” check |
| `http://localhost:9000/authbox/health` | API health through the gateway |
| `http://localhost:9000/realms/nexus-test/.well-known/openid-configuration` | Keycloak discovery through the gateway |
| `http://localhost:9000/authbox/.../verifier/evaluate` | Protected API path (needs Bearer) |

You can open `http://localhost:9901` in a browser for Envoy’s admin home. Day-to-day checks use `/ready`.

### 5.5.3 Gateway ready

| | |
|---|---|
| **Where** | Your machine — browser and/or terminal |
| **Why** | Prove Envoy’s process is ready before you trust gateway URLs |

**Browser (any OS):** open `http://localhost:9901/ready`.

**Windows PowerShell**

```powershell
(Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode
curl.exe -sS -o NUL -w "%{http_code}" "http://localhost:9901/ready"
```

**macOS / Linux**

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "http://localhost:9901/ready"
```

Pass: status `200`.

### 5.5.4 Keycloak through the gateway

| | |
|---|---|
| **Where** | Browser or terminal on your machine → host `:9000` |
| **Why** | On Base Secure / Base PKI this is how discovery works. On Base it proves the `/realms/` route |

**Browser:** open `http://localhost:9000/realms/nexus-test/.well-known/openid-configuration`.

**Windows PowerShell**

```powershell
(Invoke-WebRequest -Uri "http://localhost:9000/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing).StatusCode
```

**macOS / Linux**

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "http://localhost:9000/realms/nexus-test/.well-known/openid-configuration"
```

**Postman:** `GET http://localhost:9000/realms/nexus-test/.well-known/openid-configuration`.

Pass: status `200` and a JSON document.

### 5.5.5 API health through the gateway

| | |
|---|---|
| **Where** | Browser or terminal → host `:9000` |
| **Why** | Prove `/authbox/` reaches the API. Health is allowed without a Bearer |

**Browser:** open `http://localhost:9000/authbox/health`.

**Windows PowerShell**

```powershell
Invoke-RestMethod "http://localhost:9000/authbox/health"
curl.exe -sS "http://localhost:9000/authbox/health"
```

**macOS / Linux**

```bash
curl -sS "http://localhost:9000/authbox/health"
```

**Postman:** `GET http://localhost:9000/authbox/health`.

Pass: `{"status":"ok"}`.

### 5.5.6 Protected path — with and without a token

| | |
|---|---|
| **Where** | Terminal or Postman. Use a token minted against **this pack’s** `$KC` ([§5.2.6](#526-mint-a-token-all-packs)) |
| **Why** | See Envoy’s JWT check on `/authbox/` before the API runs |

**Without a token**

```powershell
# Windows
try { Invoke-WebRequest -Uri "http://localhost:9000/authbox/default/default/api/v1/verifier/evaluate" -UseBasicParsing } catch { $_.Exception.Response.StatusCode.value__; $_.ErrorDetails.Message }
```

```bash
# macOS / Linux
curl -sS -i "http://localhost:9000/authbox/default/default/api/v1/verifier/evaluate"
```

Pass: HTTP `401` and body text containing `Jwt is missing` (Envoy plain text).

**With user A token**

```powershell
# Windows — $TokenA from §5.2.6
Invoke-RestMethod -Uri "http://localhost:9000/authbox/default/default/api/v1/verifier/evaluate" -Headers @{ Authorization = "Bearer $TokenA" }
```

```bash
# macOS / Linux
curl -sS "http://localhost:9000/authbox/default/default/api/v1/verifier/evaluate" -H "Authorization: Bearer $TokenA"
```

Pass: JSON with `status` `success` (API answer after Envoy accepts the JWT).

### 5.5.7 What the filter chain returns (cheat sheet)

| What you sent | What you get |
|---|---|
| Protected `/authbox/...` path, no token | plain-text `401` `Jwt is missing` |
| Protected path, valid token, unknown API route | JSON `404` `{"detail":"Not Found"}` |
| Unrouted path, no token | JSON `403` |
| Unrouted path, valid token | plain-text `404` naming the allowed gateway prefixes (includes `/authbox/` and `/realms/`) |
| `http://localhost:9000/admin/` | Not routed — Keycloak Admin Console is not on the gateway |

### 5.5.8 Device ports on Base PKI

| | |
|---|---|
| **Where** | Your machine — terminal (TCP probe). **Base PKI** |
| **Why** | Confirm Envoy’s device mTLS `:1029` and MQTT `:8883` listeners |

**Windows PowerShell** (from pack root, after set-build for `base-pki`):

```powershell
. .\release\helpers\tip-mtls-ports.ps1
```

**Windows / macOS / Linux — manual probe**

```powershell
# PowerShell
function Test-Tcp([int]$Port) { try { $c = New-Object Net.Sockets.TcpClient; $iar = $c.BeginConnect("127.0.0.1",$Port,$null,$null); $ok = $iar.AsyncWaitHandle.WaitOne(500,$false); if ($ok) { $c.EndConnect($iar) | Out-Null }; $c.Close(); return $ok } catch { return $false } }; "1029=$(if (Test-Tcp 1029) {'open'} else {'closed'}) 8883=$(if (Test-Tcp 8883) {'open'} else {'closed'})"
```

```bash
# macOS / Linux
(nc -z 127.0.0.1 1029 && echo "1029=open" || echo "1029=closed")
(nc -z 127.0.0.1 8883 && echo "8883=open" || echo "8883=closed")
```

Pass when the device edge is enabled: both ports report `open`. If closed, enable the Base PKI device edge and re-check. Certificate create/renew is in [§5.6](#56-step-ca). HTTP device-trust API calls are in [SCENARIO-TESTING.md](SCENARIO-TESTING.md) (S-75…).

### 5.5.9 What you should and should not change

| Safe while operating | Avoid |
|---|---|
| Call `/ready`, `/realms/` discovery, `/authbox/health` | Expect `http://localhost:9000/admin/` to open Keycloak Admin |
| Compare no-token vs Bearer on evaluate | Treat host `:9000` as step-ca (that is only inside the CA container on Base PKI) |
| On Base, compare `:8000` API vs `:9000` gateway | Edit Envoy config in place without the product start path |
| Probe `:1029` / `:8883` on Base PKI | Skip confirming the device edge when you need mTLS / MQTT |

### 5.5.10 Quick checklist — Envoy per pack

| Check | Base | Base Secure | Base PKI |
|---|---|---|---|
| `:9901/ready` → `200` | yes | yes | yes |
| `:9000` discovery → `200` | yes | yes | yes |
| `:9000/authbox/health` → `ok` | yes | yes | yes |
| No token → `Jwt is missing` | yes on `:9000` | yes | yes |
| Device `:1029` / `:8883` | no | no | yes when device edge enabled |

### 5.5.11 When you may continue

You can prove the gateway is ready, reach Keycloak and the API through `:9000`, and tell Envoy’s `401` apart from the API’s JSON.

**Next:** [§5.6 step-ca](#56-step-ca) if your pack is **Base PKI**. On Base or Base Secure, skip to [SCENARIO-TESTING.md](SCENARIO-TESTING.md) or stop here.

Status matrix: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Progressive checks: [SCENARIO-TESTING.md](SCENARIO-TESTING.md).

---

## 5.6 step-ca

step-ca is the certificate authority. It appears only on **Base PKI**. It issues device certificates for Envoy’s device mTLS listener (`:1029`). It is **not** Keycloak and it does **not** replace JWT login.

Finish [§5.1](#51-confirm-the-build-succeeded) on a **Base PKI** install. If you are on Base or Base Secure, this section does not apply — there is no `auth-sandbox-step-ca-1` container.

### 5.6.1 How step-ca behaves in each pack

| What you want to do | **Base** | **Base Secure** | **Base PKI** |
|---|---|---|---|
| Container present | no | no | yes — `auth-sandbox-step-ca-1` |
| Web UI in this pack | — | — | none — terminal only |
| Health check | — | — | `step ca health` inside the container |
| Listen address | — | — | `:9000` **inside** the container only |
| Same as host gateway `:9000`? | — | — | **No** — host `:9000` is Envoy |
| Issues people passwords / OIDC users | — | — | no — that is Keycloak |
| Create / renew / replace a device leaf cert | — | — | yes — [§5.6.6](#566-create-a-client-certificate) onward |

### 5.6.2 Confirm the container is there

| | |
|---|---|
| **Where** | Your machine — terminal |
| **Why** | Fail fast if this is not Base PKI |

```powershell
# Any OS
docker ps --filter "name=auth-sandbox-step-ca-1" --format "table {{.Names}}\t{{.Status}}"
```

Pass: one row `auth-sandbox-step-ca-1` with status `Up` (often `healthy`).

### 5.6.3 CA health

| | |
|---|---|
| **Where** | Your machine — terminal. The `step` command runs **inside** the CA container |
| **Why** | Prove the certificate authority is serving. The password file stays in the container and is not printed |

**Steps**

1. Open a terminal (Windows PowerShell, macOS Terminal, or Linux shell).
2. Ensure Docker can see `auth-sandbox-step-ca-1` (§5.6.2).
3. Run:

```powershell
# Windows / macOS / Linux — same Docker line
docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

Pass: prints `ok`.

**Helper (PowerShell / pwsh)** from repo root:

```powershell
. .\release\helpers\tip-stepca-health.ps1
```

```powershell
# macOS / Linux with PowerShell 7
pwsh -File ./release/helpers/tip-stepca-health.ps1
```

### 5.6.4 Do not confuse the two port 9000s

| Port 9000 | Where | What it is |
|---|---|---|
| Host `localhost:9000` | Your browser / curl on the machine | **Envoy** gateway ([§5.5](#55-envoy)) |
| `https://localhost:9000` inside `auth-sandbox-step-ca-1` | Only via `docker exec` | **step-ca** |

Calling `https://localhost:9000` from the host is Envoy (or a TLS error), not the CA admin API.

### 5.6.5 Container health status

| | |
|---|---|
| **Where** | Terminal → Docker |
| **Why** | Same probe Docker uses for the healthcheck |

```powershell
docker inspect auth-sandbox-step-ca-1 --format "{{.State.Health.Status}}"
```

Pass: `healthy` after §5.6.3 succeeds.

### 5.6.6 Create a client certificate

Device leaf certificates are short-lived. The default lifetime is **24 hours** (`ValidHours` = 24). Pick a **Common Name (CN)** that identifies the device (for example `device-001` or `camera001`). For mTLS, that CN must match the device id the other side expects.

Use the **same** scripts that ship in the Base PKI zip under pack-root `devx/pki/` (also present in a product checkout). They talk to the running `auth-sandbox-step-ca-1` container. They are **not** inside the API image.

| | |
|---|---|
| **Where** | Your machine — terminal at the **unpacked pack root** (folder with `start-pack.ps1` and `devx/pki/`). Alternate: plain `docker` on any OS |
| **Why** | Ask step-ca for a leaf certificate and private key on disk |

**Before you start**

1. Pack is **Base PKI** and [§5.6.3](#563-ca-health) prints `ok`.
2. Provisioner password is already inside the container (from Base PKI start). This guide never prints it.
3. CN rules: letters, digits, dot, underscore, hyphen only.

#### Preferred — pack script `issue-client-cert.ps1`

| | |
|---|---|
| **Where** | Unpacked pack root |
| **Why** | Canonical create path (shared with developers); issues inside the CA container and writes `.crt` / `.key` |

Default output folder is `deploy/pki/certs/clients` under the pack root (do not commit `.key` files). Pass `-OutDir` to choose another folder.

```powershell
# Windows PowerShell — from the unpacked pack root
.\devx\pki\issue-client-cert.ps1 -CommonName device-001
# Shorter life for an expiry drill:
.\devx\pki\issue-client-cert.ps1 -CommonName device-001 -ValidHours 1
# Different output folder:
.\devx\pki\issue-client-cert.ps1 -CommonName device-001 -OutDir C:\temp\client-certs
```

```powershell
# macOS / Linux with PowerShell 7 — from the unpacked pack root
pwsh -File ./devx/pki/issue-client-cert.ps1 -CommonName device-001
pwsh -File ./devx/pki/issue-client-cert.ps1 -CommonName device-001 -ValidHours 1
```

Pass: you should have `device-001.crt` and `device-001.key` under the default clients folder (or under `-OutDir`).

#### Alternate — Docker only (any OS, no PowerShell)

| | |
|---|---|
| **Where** | Terminal with Docker. `step` runs **inside** the CA container; then you `docker cp` out |
| **Why** | Same CA call when you cannot run `issue-client-cert.ps1` |

**Steps**

1. List provisioners and note the leaf/enroll provisioner name (use that name below; `admin` works if that is what the list shows):

```powershell
# Any OS
docker exec auth-sandbox-step-ca-1 step ca provisioner list
```

2. Issue (keep the password **file** path — do not paste the password). Replace `admin` with the leaf provisioner name from step 1 if different:

```bash
# macOS / Linux
docker exec auth-sandbox-step-ca-1 sh -c "step ca certificate 'device-001' /tmp/device-001.crt /tmp/device-001.key \
  --ca-url https://localhost:9000 \
  --root /home/step/certs/root_ca.crt \
  --provisioner admin \
  --provisioner-password-file=/home/step/secrets/password \
  --san='device-001' \
  --not-after 24h -f"
```

```powershell
# Windows PowerShell
docker exec auth-sandbox-step-ca-1 sh -c "step ca certificate 'device-001' /tmp/device-001.crt /tmp/device-001.key --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt --provisioner admin --provisioner-password-file=/home/step/secrets/password --san='device-001' --not-after 24h -f"
```

3. Copy to your machine and delete temps in the container:

```powershell
# Windows
New-Item -ItemType Directory -Force -Path .\client-certs | Out-Null
docker cp auth-sandbox-step-ca-1:/tmp/device-001.crt .\client-certs\device-001.crt
docker cp auth-sandbox-step-ca-1:/tmp/device-001.key .\client-certs\device-001.key
docker exec auth-sandbox-step-ca-1 rm -f /tmp/device-001.crt /tmp/device-001.key
```

```bash
# macOS / Linux
mkdir -p client-certs
docker cp auth-sandbox-step-ca-1:/tmp/device-001.crt client-certs/device-001.crt
docker cp auth-sandbox-step-ca-1:/tmp/device-001.key client-certs/device-001.key
docker exec auth-sandbox-step-ca-1 rm -f /tmp/device-001.crt /tmp/device-001.key
```

Pass: both files exist. Protect the `.key` (do not publish it).

### 5.6.7 Read the certificate (subject and expiry)

| | |
|---|---|
| **Where** | Your machine — terminal, against the `.crt` on disk |
| **Why** | Confirm CN and when the cert will stop working |

Adjust the path if you used `-OutDir`. Default pack path:

**Windows PowerShell** (no OpenSSL required):

```powershell
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2((Resolve-Path .\deploy\pki\certs\clients\device-001.crt))
"Subject=$($cert.Subject)"
"NotBefore=$($cert.NotBefore.ToUniversalTime().ToString('o'))"
"NotAfter=$($cert.NotAfter.ToUniversalTime().ToString('o'))"
"Expired=$(if ($cert.NotAfter.ToUniversalTime() -lt [datetime]::UtcNow) { 'yes' } else { 'no' })"
```

**macOS / Linux** (OpenSSL):

```bash
openssl x509 -in deploy/pki/certs/clients/device-001.crt -noout -subject -dates
```

Pass: subject contains `device-001`. `NotAfter` / `notAfter` is about 24 hours after issue (or 1 hour if you used `-ValidHours 1`).

### 5.6.8 Renew a certificate

In this pack, **renew** means: revoke the old leaf when the files are still present, then **issue a new leaf for the same CN**. Use pack-root `devx/pki/refresh-client-cert.ps1` (file name says “refresh”; that **is** renew).

| | |
|---|---|
| **Where** | Unpacked pack root — PowerShell / `pwsh` |
| **Why** | Replace a leaf that is near expiry or already bad, keep the same device CN |

Use the **same** `-OutDir` you used when you issued (omit it to use the default clients folder).

```powershell
# Windows — renew device-001 (default new lifetime 24h)
.\devx\pki\refresh-client-cert.ps1 -CommonName device-001
.\devx\pki\refresh-client-cert.ps1 -CommonName device-001 -ValidHours 24 -OutDir .\deploy\pki\certs\clients
```

```powershell
# macOS / Linux with PowerShell 7
pwsh -File ./devx/pki/refresh-client-cert.ps1 -CommonName device-001
```

Pass: prior leaf revoked when files existed; script prints `Refreshed` for the CN. Re-read dates with [§5.6.7](#567-read-the-certificate-subject-and-expiry) — `NotAfter` should move forward.

**Docker-only fallback:** issue again with the same CN ([§5.6.6 alternate](#alternate-docker-only-any-os-no-powershell)) and overwrite the host `.crt` / `.key`. Prefer `refresh-client-cert.ps1` when you can; it also revokes the previous leaf at the CA.

After renew, point every client at the **new** files (or restart so they reload).

### 5.6.9 Deal with an expired certificate

| | |
|---|---|
| **Where** | Your machine — inspect the `.crt`, then renew / re-issue |
| **Why** | An expired leaf is rejected for mTLS. Replacing it is the fix — do not empty the CA volume |

**How you know it expired**

1. [§5.6.7](#567-read-the-certificate-subject-and-expiry) shows `Expired=yes`, or `notAfter` is in the past.
2. An mTLS call using that cert fails with a certificate-expired style error (Envoy / client TLS), not a Keycloak login error.
3. Gateway health may still be fine; only the **device cert** path fails.

**What to do**

| Situation | Action |
|---|---|
| You still have the old `.crt` / `.key` | Run [§5.6.8](#568-renew-a-certificate) `refresh-client-cert.ps1`, or re-issue with [§5.6.6](#566-create-a-client-certificate) and overwrite |
| Files are missing | Issue a **new** cert with the **same CN** ([§5.6.6](#566-create-a-client-certificate)) and install the new pair |
| Force a short expiry for a renew drill | Issue with `-ValidHours 1`, wait until after `NotAfter`, confirm expired in [§5.6.7](#567-read-the-certificate-subject-and-expiry), then renew |
| API device-trust still lists the device | That list is separate ([§5.4](#54-authbox-api)). Fix the **TLS** leaf here; re-register API trust only if you cleared that list too |

**Do not**

- Publish step-ca on host `:9000` to “fix” TLS.
- Delete the step-ca Docker volume as the happy-path fix.
- Expect Keycloak Admin or Swagger to renew device certs — they do not.

### 5.6.10 How this fits with Envoy and the API

| Layer                                                       | Role                                                                                         |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **step-ca** (this section)                                  | Issues and replaces X.509 leaves (CN + key)                                                  |
| **Envoy** `:1029` ([§5.5.8](#558-device-ports-on-base-pki)) | Accepts mTLS; the client presents a CA-signed cert                                           |
| **API device-trust** ([§5.4](#54-authbox-api))              | In-memory allow-list keyed by device id — Bearer JWT from Keycloak, not the leaf file itself |

Creating, renewing, and replacing the cert itself is done here on Auth-in-a-Box Base PKI. MQTT and mTLS device traffic use Envoy’s `:8883` / `:1029` listeners on this pack.

### 5.6.11 What you should and should not change

| Safe while operating | Avoid |
|---|---|
| Health check, issue, read dates, refresh | Publish step-ca’s `:9000` onto the host |
| Use CN names you will remember | Commit `.key` files to git |
| Short `-ValidHours 1` for an expiry drill | Empty CA volumes to clear an expired leaf |
| Keep host `:9000` as Envoy | Treat CA health alone as proof mTLS devices work |

### 5.6.12 Quick checklist — step-ca per pack

| Check | Base | Base Secure | Base PKI |
|---|---|---|---|
| Container listed | no | no | yes |
| `step ca health` → `ok` | skip | skip | yes |
| Issue leaf for a CN | skip | skip | yes ([§5.6.6](#566-create-a-client-certificate)) |
| Read `NotAfter` | skip | skip | yes ([§5.6.7](#567-read-the-certificate-subject-and-expiry)) |
| Renew / refresh same CN | skip | skip | yes ([§5.6.8](#568-renew-a-certificate)) |
| Replace after expiry | skip | skip | yes ([§5.6.9](#569-deal-with-an-expired-certificate)) |
| Host gateway still `:9000` Envoy | yes | yes | yes |

### 5.6.13 When you may continue

On Base PKI you can prove the CA is up, **create** a leaf, **read** its expiry, **renew** it, and **replace** it after expiry.

**You have finished the stack walkthrough** in this start guide: packs → confirm → Keycloak → Postgres → API → Envoy → step-ca (including certificate lifecycle).

**Next:** [SCENARIO-TESTING.md](SCENARIO-TESTING.md). Helpers: [helpers/README.md](helpers/README.md). Contracts: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md).
