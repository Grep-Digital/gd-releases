# Auth-in-a-Box — scenario pass

Each section below is one flow: the diagram, then the same call in curl.exe and in Postman, then the Windows PowerShell 5.1 or PowerShell 7 line that records `PASS`, `FAIL`, or `SKIP`. The PowerShell line is a single line and prints the observed value.

This pack publishes **three builds**. Progress through them in order. One session per build (or one session that reassigns `$Build` after the installed set has changed). Setting `$Build` does not start containers and does not replace the running set. A new window has no variables and no result list. Paste from Setup downward in one session.

| Phase | Build | `$Access` | What this phase covers |
|---|---|---|---|
| 1 | **Base** | `direct` | Full numbered pass S-01…S-85 (plus S-29b). Lab ports `:8080` / `:8000` |
| 2 | **Base Secure** | `gateway` | Remint tokens on `:9000`. Bearer scenarios PASS. No-bearer / direct-only scenarios `SKIP`. Lab ports closed |
| 3 | **Base PKI** | `gateway` | Same as Base Secure, plus step-ca health and optional device-port tips. Device-trust HTTP scenarios S-75…S-83 still apply |

Contents, defaults, and health: [USER-GUIDE.md](USER-GUIDE.md). Contracts: [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md). Starters: [helpers/README.md](helpers/README.md). Index: [README.md](README.md).

## Contents

| Section | Scenarios |
|---|---|
| [Setup](#setup) | access path, helpers, tokens |
| [Health and index](#health-and-index) | S-01 to S-03 |
| [Authorize and callback](#authorize-and-callback) | S-04 to S-12 |
| [Tokens and claims](#tokens-and-claims) | S-13 to S-15 |
| [Evaluate](#evaluate) | S-16 to S-23 |
| [Machine tokens](#machine-tokens) | S-24 to S-29, and S-29b |
| [MFA](#mfa) | S-30 to S-40 |
| [Air-gap](#air-gap) | S-41 to S-47 |
| [FIWARE](#fiware) | S-48 to S-52 |
| [IUDX](#iudx) | S-53 to S-57 |
| [Aadhaar](#aadhaar) | S-58 to S-60 |
| [Wallet](#wallet) | S-61 to S-64 |
| [MCP](#mcp) | S-65 to S-72 |
| [Login flow](#login-flow) | S-73 to S-74 |
| [Device trust and revoke](#device-trust-and-revoke) | S-75 to S-85 |
| [Progressive builds](#progressive-builds) | Base → Base Secure → Base PKI |
| [Results](#results) | the table |

The numbered pass is S-01 through S-85, plus S-29b. Progressive build checks are B-01 through B-06.

## Setup

Choose the build that is already installed. Or dot-source [helpers/set-build.ps1](helpers/set-build.ps1). This assignment does not start containers.

**Phase 1 — Base** (lab ports open; full pass):

```powershell
$Build = "base"; $Access = "direct"; $KC = "http://localhost:8080"; $API = "http://localhost:8000"
```

**Phase 2 — Base Secure** (gateway only; direct-only scenarios SKIP):

```powershell
$Build = "base-secure"; $Access = "gateway"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

**Phase 3 — Base PKI** (gateway + step-ca; same SKIP set as Base Secure, then B-04…B-06):

```powershell
$Build = "base-pki"; $Access = "gateway"; $KC = "http://localhost:9000"; $API = "http://localhost:9000"
```

```powershell
$Results = New-Object System.Collections.Generic.List[object]; function Add-Check([string]$Id, [string]$Result) { $Results.Add([pscustomobject]@{ Id = $Id; Result = $Result }) | Out-Null }; function Get-Claims([string]$Jwt) { $p = $Jwt.Split('.')[1]; $p += '=' * ((4 - $p.Length % 4) % 4); return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.Replace('-','+').Replace('_','/'))) | ConvertFrom-Json }; function Invoke-Api([string]$Method, [string]$Uri, [hashtable]$Headers, [string]$Body, [string]$ContentType) { $p = @{ Method = $Method; Uri = $Uri; UseBasicParsing = $true }; if ($Headers -and $Headers.Count -gt 0) { $p.Headers = $Headers }; if ($null -ne $Body -and $Body -ne "") { $p.Body = $Body }; if ($ContentType) { $p.ContentType = $ContentType }; try { return Invoke-WebRequest @p } catch { $resp = $_.Exception.Response; if (-not $resp) { throw }; $code = [int]$resp.StatusCode; $content = ""; if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $content = $_.ErrorDetails.Message } else { $stream = $resp.GetResponseStream(); if ($stream) { $reader = New-Object IO.StreamReader($stream); $content = $reader.ReadToEnd() } }; return [pscustomobject]@{ StatusCode = $code; Content = $content } } }
```

The session already has these environment names set. This page does not contain their values: `NEXUS_AUTH_CLIENT_ID`, `NEXUS_AUTH_CLIENT_SECRET`, `NEXUS_SIMULATOR_M2M_CLIENT_ID`, `NEXUS_AUTH_M2M_CLIENT_SECRET`, `AUTHBOX_USER_A`, `AUTHBOX_USER_A_PASSWORD`, `AUTHBOX_USER_B`, `AUTHBOX_USER_B_PASSWORD`, `AUTHBOX_EDGE_USER`, `AUTHBOX_EDGE_PROTECTED_USER`, `AUTHBOX_EDGE_PASSWORD`.

Mint the three tokens used below. The lines print `tid` and do not print the token. A call that sends a secret uses `curl.exe --config` on a UTF-8 file with no byte-order mark. Do not put the secret on the `curl.exe` command line. Do not pipe a PowerShell string into `docker exec` or `curl.exe`.

```powershell
$TokenA = (Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=password&client_id=$env:NEXUS_AUTH_CLIENT_ID&client_secret=$env:NEXUS_AUTH_CLIENT_SECRET&username=$env:AUTHBOX_USER_A&password=$env:AUTHBOX_USER_A_PASSWORD").access_token; $c = Get-Claims $TokenA; "user_a tid=$($c.tid)"
```

> ```
> testuser tid=tenant_a
> ```

```powershell
$TokenB = (Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=password&client_id=$env:NEXUS_AUTH_CLIENT_ID&client_secret=$env:NEXUS_AUTH_CLIENT_SECRET&username=$env:AUTHBOX_USER_B&password=$env:AUTHBOX_USER_B_PASSWORD").access_token; $c = Get-Claims $TokenB; "user_b tid=$($c.tid)"
```

> ```
> tenant_b_user tid=tenant_b
> ```

```powershell
$TokenM = (Invoke-RestMethod -Method Post -Uri "$KC/realms/nexus-test/protocol/openid-connect/token" -ContentType "application/x-www-form-urlencoded" -Body "grant_type=client_credentials&client_id=$env:NEXUS_SIMULATOR_M2M_CLIENT_ID&client_secret=$env:NEXUS_AUTH_M2M_CLIENT_SECRET").access_token; $c = Get-Claims $TokenM; "m2m tid=$($c.tid)"
```

> ```
> m2m tid=tenant_a
> ```

Postman environment for this session:

| Variable | Base (`direct`) | Base Secure / Base PKI (`gateway`) |
|---|---|---|
| `api` | `http://localhost:8000` | `http://localhost:9000` |
| `keycloak` | `http://localhost:8080` | `http://localhost:9000` |
| `token_a` | access token for `AUTHBOX_USER_A` | same, minted from this `keycloak` |
| `token_b` | access token for `AUTHBOX_USER_B` | same |
| `token_m` | access token for `NEXUS_SIMULATOR_M2M_CLIENT_ID` | same |

In PowerShell, `curl` is an alias for `Invoke-WebRequest`. The REST lines use `curl.exe` so the curl binary runs, and `$API` and `$KC` expand in double quotes.

Scenarios that run only on direct access use this guard. Paste it only as part of the scenario line shown below.

```powershell
if ($Access -ne "direct") { Add-Check "S-xx" "SKIP" } else { }
```

## Health and index


The caller asks the API for liveness, the index, and the OpenAPI document. The index and the OpenAPI document are read on direct access, where port 8000 reaches the API with no JWT filter in front.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: GET /authbox/health
  API-->>C: 200 status ok
  C->>API: GET /authbox/
  API-->>C: 200 version 7.0.0
  C->>API: GET /openapi.json
  API-->>C: 200 OpenAPI document
```

| Id | curl.exe | Postman |
|---|---|---|
| S-01 | `curl.exe -sS "$API/authbox/health"` | `GET {{api}}/authbox/health` |
| S-02 | `curl.exe -sS "$API/authbox/"` | `GET {{api}}/authbox/` |
| S-03 | `curl.exe -sS "$API/openapi.json"` | `GET {{api}}/openapi.json` |

In Postman, set `api` to `http://localhost:8000` for direct access, or `http://localhost:9000` for gateway access.


**S-01.** `GET /authbox/health` returns `200` and `status` `ok`. Both access paths.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api GET "$API/authbox/health"; $r.StatusCode; Add-Check "S-01" $(if ($r.StatusCode -eq 200 -and (($r.Content | ConvertFrom-Json).status -eq "ok")) { "PASS" } else { "FAIL" })
```

> ```
> 200
> ```

**S-02.** `GET /authbox/` returns `version` `7.0.0`. Direct access (API port 8000).

Already running: the API. Reads nothing. Borrows nothing.

```powershell
if ($Access -ne "direct") { Add-Check "S-02" "SKIP" } else { $r = Invoke-Api GET "$API/authbox/"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.version)"; Add-Check "S-02" $(if ($r.StatusCode -eq 200 -and $b.version -eq "7.0.0" -and $b.service -and $b.health) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 7.0.0
> ```

**S-03.** `GET /openapi.json` returns an OpenAPI document. Direct access (API port 8000).

Already running: the API. Reads nothing. Borrows nothing.

```powershell
if ($Access -ne "direct") { Add-Check "S-03" "SKIP" } else { $r = Invoke-Api GET "$API/openapi.json"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.openapi)"; Add-Check "S-03" $(if ($r.StatusCode -eq 200 -and $b.openapi -and $b.paths) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 3.1.0
> ```

The first field is `200`. The second is the document's `openapi` value. `paths` is present.

## Authorize and callback


The caller asks the API for a Keycloak login URL. The API returns that URL and a PKCE code verifier. The callback accepts a `code` and tells the caller to exchange it. A callback with no `code`, or with `error`, is rejected. A token form with no `grant_type` is rejected.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  participant KC as Keycloak
  C->>API: GET /auth/authorize
  API-->>C: 200 url plus code_verifier
  Note over C,KC: url host is port 8080 or 9000 matching the access path
  C->>API: GET /auth/callback?code=
  API-->>C: 200 next_step /auth/token
  C->>API: GET /auth/callback
  API-->>C: 400
  C->>API: GET /auth/callback?error=access_denied
  API-->>C: 400
  C->>API: POST /auth/token with no grant_type
  API-->>C: 422
```

| Id | curl.exe | Postman |
|---|---|---|
| S-04 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/authorize"` | `GET {{api}}/authbox/default/default/api/v1/auth/authorize` |
| S-05 | same response field `_sandbox_code_verifier` | same |
| S-06 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/authorize?state=test-csrf-state"` | query `state=test-csrf-state` |
| S-07 | same authorize response, field `_sandbox_note` | same |
| S-08 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/authorize?redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback&state=custom_state_42"` | query `redirect_uri` and `state=custom_state_42` |
| S-09 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/callback?code=test-auth-code"` | `GET` with query `code=test-auth-code` |
| S-10 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/callback"` | `GET` with no query |
| S-11 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/callback?error=access_denied"` | query `error=access_denied` |
| S-12 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/auth/token" -H "Content-Type: application/x-www-form-urlencoded" -d "redirect_uri=http://localhost:8000/auth/callback"` | `POST`, body x-www-form-urlencoded, field `redirect_uri` only |


**S-04.** Authorize returns a URL that mentions `authorize` or `openid`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$auth = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize"; $ok = [bool]$auth.url -and ($auth.url.ToLower().Contains("authorize") -or $auth.url.ToLower().Contains("openid")); $ok; Add-Check "S-04" $(if ($ok) { "PASS" } else { "FAIL" })
```

> ```
> True
> ```

**S-05.** `_sandbox_code_verifier` is at least 43 characters.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$auth._sandbox_code_verifier.Length; Add-Check "S-05" $(if ($auth._sandbox_code_verifier.Length -ge 43) { "PASS" } else { "FAIL" })
```

> ```
> 43
> ```

Any length of 43 or more is a pass.

**S-06.** `state` is echoed.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$st = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize?state=test-csrf-state"; $st.state; Add-Check "S-06" $(if ($st.state -eq "test-csrf-state") { "PASS" } else { "FAIL" })
```

> ```
> test-csrf-state
> ```

**S-07.** `_sandbox_note` is present while HTTP sandbox is allowed.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
[bool]$auth._sandbox_note; Add-Check "S-07" $(if ($auth._sandbox_note) { "PASS" } else { "FAIL" })
```

> ```
> True
> ```

**S-08.** A custom `state` is echoed.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$st = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize?redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback&state=custom_state_42"; $st.state; Add-Check "S-08" $(if ($st.state -eq "custom_state_42" -and $st.url) { "PASS" } else { "FAIL" })
```

> ```
> custom_state_42
> ```

**S-09.** Callback with `code` returns `200` and `next_step` containing `/auth/token`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/callback?code=test-auth-code"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.next_step)"; Add-Check "S-09" $(if ($r.StatusCode -eq 200 -and $b.next_step -like "*/auth/token*") { "PASS" } else { "FAIL" })
```

> ```
> 200 .../auth/token
> ```

**S-10.** Callback with no `code` returns `400`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/callback"; $r.StatusCode; Add-Check "S-10" $(if ($r.StatusCode -eq 400) { "PASS" } else { "FAIL" })
```

> ```
> 400
> ```

**S-11.** Callback with `error=access_denied` returns `400` and the detail contains `access_denied`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/callback?error=access_denied"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.detail)"; Add-Check "S-11" $(if ($r.StatusCode -eq 400 -and "$($b.detail)" -like "*access_denied*") { "PASS" } else { "FAIL" })
```

> ```
> 400 OIDC error: access_denied
> ```

**S-12.** A token form with no `grant_type` returns `422`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token" @{} "redirect_uri=http%3A%2F%2Flocalhost%3A8000%2Fauth%2Fcallback" "application/x-www-form-urlencoded"; $r.StatusCode; Add-Check "S-12" $(if ($r.StatusCode -eq 422) { "PASS" } else { "FAIL" })
```

> ```
> 422
> ```

## Tokens and claims


The caller asks Keycloak for an access token. The password-grant token carries claim `tid` and claim `roles`. The machine token carries claim `tid`. The stored user attribute name `tenant_id` is not the claim name.

```mermaid
sequenceDiagram
  participant C as Caller
  participant KC as Keycloak
  C->>KC: POST /token password grant testuser
  KC-->>C: access token tid tenant_a roles admin and operator
  C->>KC: POST /token password grant tenant_b_user
  KC-->>C: access token tid tenant_b role viewer
  C->>KC: POST /token client_credentials nexus-m2m
  KC-->>C: access token tid tenant_a
```

| Id | curl.exe | Postman |
|---|---|---|
| S-13 | `curl.exe --config` a UTF-8 file with no byte-order mark. Secret fields are the environment names in Setup. Do not put those values on the curl.exe command line. | `POST {{keycloak}}/realms/nexus-test/protocol/openid-connect/token`, body x-www-form-urlencoded, those fields. Save `access_token` as `token_a`. |
| S-14 | same `curl.exe --config` file. The user is `AUTHBOX_USER_B` and the password is `AUTHBOX_USER_B_PASSWORD`. | save as `token_b` |
| S-15 | same `curl.exe --config` file. The client id is `NEXUS_SIMULATOR_M2M_CLIENT_ID` and the secret is `NEXUS_AUTH_M2M_CLIENT_SECRET`. | save as `token_m` |

`keycloak` is `http://localhost:8080` on direct access and `http://localhost:9000` on gateway access. Decode the payload and read `tid`. The claim list has no `tenant_id`.


**S-13.** `testuser` token has `tid` `tenant_a`, no `tenant_id` claim, and roles `admin` and `operator`.

Already running: Keycloak. Reads nothing. Borrows nothing. The setup block mints the same three tokens for later scenarios.

```powershell
$c = Get-Claims $TokenA; $names = $c.PSObject.Properties.Name; "tid=$($c.tid) tenant_id_claim=$($names -contains 'tenant_id')"; Add-Check "S-13" $(if ($c.tid -eq "tenant_a" -and -not ($names -contains "tenant_id") -and ($c.roles -contains "admin") -and ($c.roles -contains "operator")) { "PASS" } else { "FAIL" })
```

> ```
> tid=tenant_a tenant_id_claim=False
> ```

**S-14.** `tenant_b_user` token has `tid` `tenant_b` and role `viewer`.

Already running: Keycloak. Reads nothing. Borrows nothing. The setup block mints the same three tokens for later scenarios.

```powershell
$c = Get-Claims $TokenB; "tid=$($c.tid)"; Add-Check "S-14" $(if ($c.tid -eq "tenant_b" -and ($c.roles -contains "viewer") -and -not ($c.PSObject.Properties.Name -contains "tenant_id")) { "PASS" } else { "FAIL" })
```

> ```
> tid=tenant_b
> ```

**S-15.** `nexus-m2m` token has `tid` `tenant_a` and no `tenant_id` claim.

Already running: Keycloak. Reads nothing. Borrows nothing. The setup block mints the same three tokens for later scenarios.

```powershell
$c = Get-Claims $TokenM; "tid=$($c.tid)"; Add-Check "S-15" $(if ($c.tid -eq "tenant_a" -and -not ($c.PSObject.Properties.Name -contains "tenant_id")) { "PASS" } else { "FAIL" })
```

> ```
> tid=tenant_a
> ```

## Evaluate


The caller sends the access token to the API. The API checks the signature and claim `tid`, then returns the subject and the roles from the token. Fields `tenant_id` and `instance_id` on the response are the words in the URL, which are `default` and `default` on the seeded path.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: GET /verifier/evaluate Authorization Bearer
  API-->>C: 200 success tenant_id default
  C->>API: GET /verifier/evaluate with no token or a bad token
  API-->>C: 401
  C->>API: GET /verifier/evaluate required_role not on the token
  API-->>C: 403
  C->>API: POST /authbox/admin/v1/tenants
  C->>API: GET /authbox/org-a/dev/.../verifier/evaluate
  API-->>C: 200 tenant_id org-a instance_id dev
```

| Id | curl.exe | Postman |
|---|---|---|
| S-16 | `curl.exe -sS "$API/authbox/default/default/api/v1/verifier/evaluate" -H "Authorization: Bearer $TokenA"` | `GET {{api}}/authbox/default/default/api/v1/verifier/evaluate`, Auth Bearer `{{token_a}}` |
| S-17 | `curl.exe -sS -D - -o NUL "$API/authbox/default/default/api/v1/verifier/evaluate"` | same URL, no auth |
| S-18 | add `-H "Authorization: Bearer invalid.garbage.token"` | Auth Bearer `invalid.garbage.token` |
| S-19 | `-H "Authorization: Token abc123"` | Auth type API Key or a header `Authorization: Token abc123` |
| S-20 | `-H "Authorization: Basic dXNlcjpwYXNz"` | Auth Basic |
| S-21 | URL ends with `?required_role=nonexistent_role_xyz` and Bearer `token_a` | query `required_role` |
| S-22 | `?required_role=viewer` and Bearer `token_a` | same |
| S-23 | `POST {{api}}/authbox/admin/v1/tenants` body raw JSON `{"tenant_id":"org-a"}`, then `POST .../tenants/org-a/instances` body `{"instance_id":"dev"}`, then `GET .../authbox/org-a/dev/api/v1/verifier/evaluate`. Repeat for `org-b` / `staging`. | Bearer `{{token_a}}` on each call |


**S-16.** Evaluate with `testuser` returns `200`, `status` `success`, URL `tenant_id` `default`, and a non-empty `subject_id`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer $TokenA" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status) $($b.tenant_id) $($b.instance_id)"; Add-Check "S-16" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.subject_id -and $b.tenant_id -eq "default" -and $b.instance_id -eq "default" -and $b.roles) { "PASS" } else { "FAIL" })
```

> ```
> 200 success default default
> ```

**S-17.** Evaluate with no header returns `401`. Direct access (API port 8000). On gateway access Envoy also returns `401`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate"; $r.StatusCode; Add-Check "S-17" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-18.** A garbage bearer returns `401`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer invalid.garbage.token" }; $r.StatusCode; Add-Check "S-18" $(if ($r.StatusCode -eq 401 -or $r.StatusCode -eq 403) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-19.** Scheme `Token` returns `401`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Token abc123" }; $r.StatusCode; Add-Check "S-19" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-20.** Scheme `Basic` returns `401`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Basic dXNlcjpwYXNz" }; $r.StatusCode; Add-Check "S-20" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-21.** `required_role=nonexistent_role_xyz` on `testuser` returns `403`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate?required_role=nonexistent_role_xyz" @{ Authorization = "Bearer $TokenA" }; $r.StatusCode; Add-Check "S-21" $(if ($r.StatusCode -eq 403) { "PASS" } else { "FAIL" })
```

> ```
> 403
> ```

**S-22.** `required_role=viewer` on `testuser` returns `403`. `viewer` is on `tenant_b_user`.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate?required_role=viewer" @{ Authorization = "Bearer $TokenA" }; $r.StatusCode; Add-Check "S-22" $(if ($r.StatusCode -eq 403) { "PASS" } else { "FAIL" })
```

> ```
> 403
> ```

**S-23.** Evaluate on a created URL tenant returns that tenant and instance. Both access paths, with a bearer.

Already running: the API and Keycloak. Reads the setup token `$TokenA`. Borrows nothing else.

```powershell
$h = @{ Authorization = "Bearer $TokenA" }; foreach ($pair in @(@("org-a","dev"),@("org-b","staging"))) { Invoke-Api POST "$API/authbox/admin/v1/tenants" $h ("{`"tenant_id`":`"$($pair[0])`"}") "application/json" | Out-Null; Invoke-Api POST "$API/authbox/admin/v1/tenants/$($pair[0])/instances" $h ("{`"instance_id`":`"$($pair[1])`"}") "application/json" | Out-Null }; $ra = Invoke-Api GET "$API/authbox/org-a/dev/api/v1/verifier/evaluate" $h; $ba = $ra.Content | ConvertFrom-Json; $rb = Invoke-Api GET "$API/authbox/org-b/staging/api/v1/verifier/evaluate" $h; $bb = $rb.Content | ConvertFrom-Json; "$($ra.StatusCode) $($ba.tenant_id) $($ba.instance_id) $($rb.StatusCode) $($bb.tenant_id) $($bb.instance_id)"; Add-Check "S-23" $(if ($ra.StatusCode -eq 200 -and $ba.tenant_id -eq "org-a" -and $ba.instance_id -eq "dev" -and $rb.StatusCode -eq 200 -and $bb.tenant_id -eq "org-b" -and $bb.instance_id -eq "staging") { "PASS" } else { "FAIL" })
```

> ```
> 200 org-a dev 200 org-b staging
> ```

## Machine tokens


The caller asks the API for a machine token. The API takes the client id and secret to Keycloak and returns the access token. A wrong secret is rejected. A blank client id is rejected. The access token then evaluates.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  participant KC as Keycloak
  C->>API: POST /auth/token grant_type client_credentials
  API->>KC: client credentials
  KC-->>API: access token
  API-->>C: 200 token_type Bearer
  C->>API: GET /verifier/evaluate Bearer
  API-->>C: 200 success
```

| Id | curl.exe | Postman |
|---|---|---|
| S-24 | `curl.exe --config` a UTF-8 file with no byte-order mark. Secret fields are the environment names in Setup. Do not put those values on the curl.exe command line. | `POST` that URL, body x-www-form-urlencoded |
| S-25 | same `curl.exe --config` file. The client id is `NEXUS_SIMULATOR_M2M_CLIENT_ID` and the secret is `NEXUS_AUTH_M2M_CLIENT_SECRET`. | same |
| S-26 | body `grant_type=client_credentials` only. The API uses the client id and secret already set in the API process. | same |
| S-27 | `curl.exe --config` a UTF-8 file with no byte-order mark. The client id is `NEXUS_SIMULATOR_M2M_CLIENT_ID`. The secret in that file is not `NEXUS_AUTH_M2M_CLIENT_SECRET`. | expect 401 |
| S-28 | `client_id=  &client_secret=  ` with the spaces, or the encoded form in the PowerShell line | expect 400 |
| S-29 | evaluate with the token from S-25 | Bearer that token |
| S-29b | evaluate with `token_a` and again with `token_b` | both return 200 |


**S-24.** Client credentials for `nexus-sandbox` through the API returns `token_type` `Bearer`.

Already running: the API. Reads nothing. Borrows nothing. S-25 stores `$TokenApiM` for S-29.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token" @{} "grant_type=client_credentials&client_id=$env:NEXUS_AUTH_CLIENT_ID&client_secret=$env:NEXUS_AUTH_CLIENT_SECRET" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.token_type)"; Add-Check "S-24" $(if ($r.StatusCode -eq 200 -and $b.access_token -and $b.token_type -eq "Bearer") { "PASS" } else { "FAIL" })
```

> ```
> 200 Bearer
> ```

**S-25.** Client credentials for `nexus-m2m` through the API returns an access token.

Already running: the API. Reads nothing. Borrows nothing. S-25 stores `$TokenApiM` for S-29.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token" @{} "grant_type=client_credentials&client_id=$env:NEXUS_SIMULATOR_M2M_CLIENT_ID&client_secret=$env:NEXUS_AUTH_M2M_CLIENT_SECRET" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; $r.StatusCode; $TokenApiM = $b.access_token; Add-Check "S-25" $(if ($r.StatusCode -eq 200 -and $TokenApiM) { "PASS" } else { "FAIL" })
```

> ```
> 200
> ```

**S-26.** Client credentials with no client id uses the API's configured client and returns `200`.

Already running: the API. Reads nothing. Borrows nothing. S-25 stores `$TokenApiM` for S-29.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token" @{} "grant_type=client_credentials" "application/x-www-form-urlencoded"; $r.StatusCode; Add-Check "S-26" $(if ($r.StatusCode -eq 200) { "PASS" } else { "FAIL" })
```

> ```
> 200
> ```

**S-27.** A wrong client secret returns `401`.

Already running: the API. Reads nothing. Borrows nothing. S-25 stores `$TokenApiM` for S-29.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token" @{} "grant_type=client_credentials&client_id=nexus-m2m&client_secret=wrong-secret" "application/x-www-form-urlencoded"; $r.StatusCode; Add-Check "S-27" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-28.** Blank client id and secret return `400`.

Already running: the API. Reads nothing. Borrows nothing. S-25 stores `$TokenApiM` for S-29.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token" @{} "grant_type=client_credentials&client_id=%20%20&client_secret=%20%20" "application/x-www-form-urlencoded"; $r.StatusCode; Add-Check "S-28" $(if ($r.StatusCode -eq 400) { "PASS" } else { "FAIL" })
```

> ```
> 400
> ```

**S-29.** The machine token from S-25 evaluates at `200`.

Already running: the API. Reads `$TokenApiM` from S-25. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer $TokenApiM" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status)"; Add-Check "S-29" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success") { "PASS" } else { "FAIL" })
```

> ```
> 200 success
> ```

**S-29b.** `$TokenA` and `$TokenB` both evaluate. That is the same check as S-16 on each token.

Already running: the API and Keycloak. Reads `$TokenA` and `$TokenB` from setup. Borrows nothing else.

```powershell
$ra = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer $TokenA" }; $rb = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer $TokenB" }; "$($ra.StatusCode) $($rb.StatusCode)"; Add-Check "S-29b" $(if ($ra.StatusCode -eq 200 -and $rb.StatusCode -eq 200) { "PASS" } else { "FAIL" })
```

> ```
> 200 200
> ```

## MFA


The caller enrolls a one-time secret with a bearer, then asks the direct-access helper for a current code and verifies it. A wrong code, a non-numeric code, and a short code come back `valid` false. An unusable secret is rejected.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /mfa/enroll Bearer
  API-->>C: 200 secret
  C->>API: POST /control/v1/mocks/generate-otp mode generate
  API-->>C: secret
  C->>API: POST generate-otp mode code
  API-->>C: 6 digit code
  C->>API: POST /mfa/verify secret and verify_code
  API-->>C: 200 valid true
  C->>API: POST generate-otp mode verify with 000000
  API-->>C: 200 valid false
```

The `/control/v1/mocks/generate-otp` helper is on direct access. `POST /mfa/enroll` takes the bearer on either access path.

| Id | curl.exe | Postman |
|---|---|---|
| S-30 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/mfa/enroll" -H "Authorization: Bearer $TokenA"` | `POST {{api}}/authbox/default/default/api/v1/mfa/enroll`, Bearer `{{token_a}}` |
| S-31 | challenge `POST .../mfa/challenge` form `secret=<secret>`, then `POST .../mfa/verify` form `secret` and `verify_code` | same two calls |
| S-32 | `curl.exe -sS -X POST "$API/authbox/default/default/control/v1/mocks/generate-otp" -H "Content-Type: application/x-www-form-urlencoded" -d "mode=generate"` | body `mode=generate` |
| S-33 | `-d "mode=code&secret=SECRET"` | body `mode=code`, `secret` |
| S-34 | `-d "mode=verify&secret=SECRET&verify_code=CODE"` | expect `valid` true |
| S-35 | `verify_code=000000` | expect `valid` false |
| S-36 | `-d "mode=code"` with no secret | 6 digit code from the configured secret |
| S-37 | `-d "mode=code&secret=not-a-base32-secret"` | expect 400 |
| S-38 | `verify_code=abcdef` | expect `valid` false |
| S-39 | `verify_code=12345` | expect `valid` false |
| S-40 | two `mode=generate` calls, then `mode=code` for each secret | the two codes differ |


**S-30.** `POST .../mfa/enroll` with the `testuser` bearer returns a `secret`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/mfa/enroll" @{ Authorization = "Bearer $TokenA" }; $b = $r.Content | ConvertFrom-Json; $r.StatusCode; Add-Check "S-30" $(if ($r.StatusCode -eq 200 -and $b.secret) { "PASS" } else { "FAIL" })
```

> ```
> 200
> ```

**S-31.** Challenge then verify with that path returns `valid` `true`. Use a fresh secret from the control helper on the Direct access, or the enroll secret.

Already running: the API on the lab switch, and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-31" "SKIP" } else { $g = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=generate" "application/x-www-form-urlencoded"; $sec = ($g.Content | ConvertFrom-Json).secret; $ch = Invoke-Api POST "$API/authbox/default/default/api/v1/mfa/challenge" @{ Authorization = "Bearer $TokenA" } "secret=$sec" "application/x-www-form-urlencoded"; $code = ($ch.Content | ConvertFrom-Json).code; $vr = Invoke-Api POST "$API/authbox/default/default/api/v1/mfa/verify" @{ Authorization = "Bearer $TokenA" } "secret=$sec&verify_code=$code" "application/x-www-form-urlencoded"; $vb = $vr.Content | ConvertFrom-Json; "$($vr.StatusCode) $($vb.valid)"; Add-Check "S-31" $(if ($ch.StatusCode -eq 200 -and $vr.StatusCode -eq 200 -and $vb.valid -eq $true) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 True
> ```

**S-32.** Control `mode=generate` returns a secret of at least 16 characters. Direct access (API port 8000).

Already running: the API on the lab switch. Reads nothing. Stores `$OtpSecret` for S-33 through S-39.

```powershell
if ($Access -ne "direct") { Add-Check "S-32" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=generate" "application/x-www-form-urlencoded"; $sec = ($r.Content | ConvertFrom-Json).secret; "$($r.StatusCode) $($sec.Length)"; $OtpSecret = $sec; Add-Check "S-32" $(if ($r.StatusCode -eq 200 -and $sec.Length -ge 16) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 32
> ```

The length is at least 16.

**S-33.** `mode=code` returns a 6-digit code. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-33" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=code&secret=$OtpSecret" "application/x-www-form-urlencoded"; $code = ($r.Content | ConvertFrom-Json).code; "$($r.StatusCode) $($code.Length)"; Add-Check "S-33" $(if ($r.StatusCode -eq 200 -and $code.Length -eq 6 -and $code -match '^\d{6}$') { "PASS" } else { "FAIL" }) }
```

> ```
> 200 6
> ```

**S-34.** `mode=verify` with that code returns `valid` `true`. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-34" "SKIP" } else { $code = ((Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=code&secret=$OtpSecret" "application/x-www-form-urlencoded").Content | ConvertFrom-Json).code; $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=verify&secret=$OtpSecret&verify_code=$code" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.valid)"; Add-Check "S-34" $(if ($r.StatusCode -eq 200 -and $b.valid -eq $true) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 True
> ```

**S-35.** `verify_code=000000` returns `valid` `false`. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-35" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=verify&secret=$OtpSecret&verify_code=000000" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.valid)"; Add-Check "S-35" $(if ($r.StatusCode -eq 200 -and $b.valid -eq $false) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 False
> ```

**S-36.** `mode=code` with no secret uses the configured TOTP secret and returns 6 digits. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-36" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=code" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.code.Length)"; Add-Check "S-36" $(if ($r.StatusCode -eq 200 -and $b.code.Length -eq 6) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 6
> ```

**S-37.** An invalid secret on `mode=code` returns `400`. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-37" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=code&secret=not-a-base32-secret" "application/x-www-form-urlencoded"; $r.StatusCode; Add-Check "S-37" $(if ($r.StatusCode -eq 400) { "PASS" } else { "FAIL" }) }
```

> ```
> 400
> ```

**S-38.** A non-numeric verify code returns `valid` `false`. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-38" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=verify&secret=$OtpSecret&verify_code=abcdef" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.valid)"; Add-Check "S-38" $(if ($r.StatusCode -eq 200 -and $b.valid -eq $false) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 False
> ```

**S-39.** A 5-digit verify code returns `valid` `false`. Direct access (API port 8000).

Already running: the API on the lab switch. Reads `$OtpSecret` from S-32. Borrows nothing else.

```powershell
if ($Access -ne "direct") { Add-Check "S-39" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=verify&secret=$OtpSecret&verify_code=12345" "application/x-www-form-urlencoded"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.valid)"; Add-Check "S-39" $(if ($r.StatusCode -eq 200 -and $b.valid -eq $false) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 False
> ```

**S-40.** Two generated secrets produce two codes that differ. Direct access (API port 8000).

Already running: the API on the lab switch. Reads nothing. Borrows nothing.

```powershell
if ($Access -ne "direct") { Add-Check "S-40" "SKIP" } else { $s1 = ((Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=generate" "application/x-www-form-urlencoded").Content | ConvertFrom-Json).secret; $s2 = ((Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=generate" "application/x-www-form-urlencoded").Content | ConvertFrom-Json).secret; $c1 = ((Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=code&secret=$s1" "application/x-www-form-urlencoded").Content | ConvertFrom-Json).code; $c2 = ((Invoke-Api POST "$API/authbox/default/default/control/v1/mocks/generate-otp" @{} "mode=code&secret=$s2" "application/x-www-form-urlencoded").Content | ConvertFrom-Json).code; "$($s1 -ne $s2) $($c1 -ne $c2)"; Add-Check "S-40" $(if ($s1 -ne $s2 -and $c1 -ne $c2) { "PASS" } else { "FAIL" }) }
```

> ```
> True True
> ```

A matching pair is one code in a million. Run the line again if both codes match.

## Air-gap


The caller names an edge user. The API reads that user from the manifest inside the API image. No Keycloak token is sent. `AUTHBOX_EDGE_USER` has role `operator`. `AUTHBOX_EDGE_PROTECTED_USER` has role `reader` when the request also sends `AUTHBOX_EDGE_PASSWORD`. These calls use the lab switch.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /auth/edge/verify header X-Username only
  API-->>C: 401
  C->>API: POST edge/verify protected edge user and X-Password from AUTHBOX_EDGE_PASSWORD
  API-->>C: 200 role reader
  C->>API: POST edge/verify wrong password or unknown user
  API-->>C: 401
  C->>API: POST edge/verify required_role admin
  API-->>C: 403
  C->>API: POST edge/verify required_role operator
  API-->>C: 200
```

| Id | curl.exe | Postman |
|---|---|---|
| S-41 | `curl.exe -sS -D - -X POST "$API/authbox/default/default/api/v1/auth/edge/verify" -H "X-Username: $env:AUTHBOX_EDGE_USER"` | `POST` that URL, header `X-Username` from `AUTHBOX_EDGE_USER` only. Expect 401 |
| S-42 | `curl.exe --config` a UTF-8 file with no byte-order mark. The headers are `AUTHBOX_EDGE_PROTECTED_USER` and `AUTHBOX_EDGE_PASSWORD`. Do not put the password on the curl.exe command line. | same headers, as Postman variables |
| S-43 | `X-Password: wrong` | expect 401 |
| S-44 | `X-Username: nobody` | expect 401 |
| S-45 | `POST` with no `X-Username` | expect 401 |
| S-46 | URL `?required_role=admin`, `X-Username` from `AUTHBOX_EDGE_USER`, and `X-Password` from `AUTHBOX_EDGE_PASSWORD` via `curl.exe --config` | expect 403 |
| S-47 | URL `?required_role=operator` with the same user and password via `curl.exe --config` | expect 200 |


These scenarios call the API with no bearer. They run on the Direct access (API port 8000).

**S-41.** `X-Username` for `AUTHBOX_EDGE_USER` with no password returns `401`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-41" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify" @{ "X-Username" = $env:AUTHBOX_EDGE_USER }; $r.StatusCode; Add-Check "S-41" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" }) }
```

> ```
> 401
> ```

**S-42.** `AUTHBOX_EDGE_PROTECTED_USER` with `AUTHBOX_EDGE_PASSWORD` returns `200` and role `reader`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-42" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify" @{ "X-Username" = $env:AUTHBOX_EDGE_PROTECTED_USER; "X-Password" = $env:AUTHBOX_EDGE_PASSWORD }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.roles -join ',')"; Add-Check "S-42" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and ($b.roles -contains "reader")) { "PASS" } else { "FAIL" }) }
```

> ```
> 200 reader
> ```

**S-43.** A wrong password returns `401` or `403`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-43" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify" @{ "X-Username" = $env:AUTHBOX_EDGE_PROTECTED_USER; "X-Password" = "wrong" }; $r.StatusCode; Add-Check "S-43" $(if ($r.StatusCode -eq 401 -or $r.StatusCode -eq 403) { "PASS" } else { "FAIL" }) }
```

> ```
> 401
> ```

**S-44.** Unknown user `nobody` returns `401`, `403`, or `404`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-44" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify" @{ "X-Username" = "nobody" }; $r.StatusCode; Add-Check "S-44" $(if ($r.StatusCode -in 401,403,404) { "PASS" } else { "FAIL" }) }
```

> ```
> 401
> ```

**S-45.** No `X-Username` returns `400`, `401`, or `422`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-45" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify"; $r.StatusCode; Add-Check "S-45" $(if ($r.StatusCode -in 400,401,422) { "PASS" } else { "FAIL" }) }
```

> ```
> 400
> ```

**S-46.** `AUTHBOX_EDGE_USER` with `AUTHBOX_EDGE_PASSWORD` and `required_role=admin` returns `403`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-46" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify?required_role=admin" @{ "X-Username" = $env:AUTHBOX_EDGE_USER; "X-Password" = $env:AUTHBOX_EDGE_PASSWORD }; $r.StatusCode; Add-Check "S-46" $(if ($r.StatusCode -eq 403) { "PASS" } else { "FAIL" }) }
```

> ```
> 403
> ```

**S-47.** `AUTHBOX_EDGE_USER` with `AUTHBOX_EDGE_PASSWORD` and `required_role=operator` returns `200`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-47" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/edge/verify?required_role=operator" @{ "X-Username" = $env:AUTHBOX_EDGE_USER; "X-Password" = $env:AUTHBOX_EDGE_PASSWORD }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status)"; Add-Check "S-47" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success") { "PASS" } else { "FAIL" }) }
```

> ```
> 200 success
> ```

## FIWARE


FIWARE headers travel with the call. They do not authenticate it. A bearer that already has claim `tid` is the caller. `required_role` is read from claim `roles` on that token. Header `X-Fiware-Roles` does not grant the role.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /auth/fiware/verify headers only
  API-->>C: 401
  C->>API: POST fiware/verify Bearer and Fiware-Service
  API-->>C: 200 status success
  C->>API: POST fiware/verify Bearer and X-Fiware-Subject
  API-->>C: 200 subject_id is the token subject
  C->>API: POST fiware/verify required_role not on the token
  API-->>C: 403
  C->>API: POST fiware/verify required_role viewer Bearer tenant_b_user
  API-->>C: 200
```

| Id | curl.exe | Postman |
|---|---|---|
| S-48 | `curl.exe -sS -D - -X POST "$API/authbox/default/default/api/v1/auth/fiware/verify" -H "Fiware-Service: smartcity" -H "X-Fiware-Subject: urn:ngsi-ld:Device:001" -H "X-Fiware-Roles: reader,writer"` | those three headers, no auth. Expect 401 |
| S-49 | add `-H "Authorization: Bearer $TokenA"` | Bearer `{{token_a}}`. Expect 200 and a non-empty `fiware_service` |
| S-50 | Bearer `token_a` and only `X-Fiware-Subject: urn:ngsi-ld:Device:002` | `subject_id` is not that URN |
| S-51 | URL `?required_role=nonexistent_role`, Bearer `token_a`, and `X-Fiware-Roles: reader,writer` | expect 403 |
| S-52 | URL `?required_role=viewer`, Bearer `token_b`, and `X-Fiware-Roles: reader,writer` | expect 200 |


**S-48.** FIWARE headers without a bearer return `401`. Direct access, so the body is the API JSON. On gateway access the same call is Envoy's plain-text `401`, which is still status `401`.

Already running: the API. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/verify" @{ "Fiware-Service" = "smartcity"; "X-Fiware-Subject" = "urn:ngsi-ld:Device:001"; "X-Fiware-Roles" = "reader,writer" }; $r.StatusCode; Add-Check "S-48" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-49.** `testuser` bearer plus `Fiware-Service` returns `200` and a non-empty `fiware_service`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/verify" @{ Authorization = "Bearer $TokenA"; "Fiware-Service" = "smartcity"; "X-Fiware-Subject" = "urn:ngsi-ld:Device:001"; "X-Fiware-Roles" = "reader,writer" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status) $($b.fiware_service)"; Add-Check "S-49" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.fiware_service) { "PASS" } else { "FAIL" })
```

> ```
> 200 success <non-empty fiware_service>
> ```

`fiware_service` on the response is the value from the token. It is a non-empty string.

**S-50.** `X-Fiware-Subject` does not become `subject_id`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/verify" @{ Authorization = "Bearer $TokenA"; "X-Fiware-Subject" = "urn:ngsi-ld:Device:002" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.subject_id)"; Add-Check "S-50" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.subject_id -ne "urn:ngsi-ld:Device:002") { "PASS" } else { "FAIL" })
```

> ```
> 200 <token subject>
> ```

**S-51.** `required_role=nonexistent_role` returns `403` even when `X-Fiware-Roles` is `reader,writer`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/verify?required_role=nonexistent_role" @{ Authorization = "Bearer $TokenA"; "Fiware-Service" = "smartcity"; "X-Fiware-Subject" = "urn:ngsi-ld:Device:001"; "X-Fiware-Roles" = "reader,writer" }; $r.StatusCode; Add-Check "S-51" $(if ($r.StatusCode -eq 403) { "PASS" } else { "FAIL" })
```

> ```
> 403
> ```

**S-52.** `required_role=viewer` with `tenant_b_user` returns `200`. `X-Fiware-Roles` is not the grant.

Already running: the API and Keycloak. Reads `$TokenB` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/verify?required_role=viewer" @{ Authorization = "Bearer $TokenB"; "Fiware-Service" = "smartcity"; "X-Fiware-Subject" = "urn:ngsi-ld:Device:001"; "X-Fiware-Roles" = "reader,writer" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status)"; Add-Check "S-52" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success") { "PASS" } else { "FAIL" })
```

> ```
> 200 success
> ```

## IUDX


IUDX headers are copied onto the response after the bearer is accepted. They are not the caller. An artefact body is not read as the consent id.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /auth/iudx/verify consent header and no bearer
  API-->>C: 401
  C->>API: POST iudx/verify Bearer and X-Iudx-Consent-Id
  API-->>C: 200 iudx_consent_id copied
  C->>API: POST iudx/verify Bearer and X-Iudx-Catalogue-Access
  API-->>C: 200 catalogue value copied
  C->>API: POST iudx/verify Bearer and X-Consent-Artefact
  API-->>C: 200 iudx_consent_id empty
```

| Id | curl.exe | Postman |
|---|---|---|
| S-53 | `curl.exe -sS -D - -X POST "$API/authbox/default/default/api/v1/auth/iudx/verify" -H "Fiware-Service: smartcity" -H "X-Iudx-Consent-Id: consent-abc-123"` | no auth. Expect 401 |
| S-54 | add `-H "Authorization: Bearer $TokenA"` | expect `iudx_consent_id` `consent-abc-123` |
| S-55 | Bearer `token_a`, header `X-Iudx-Catalogue-Access: rs.demo.example.com/cat/v1` | expect that string on `iudx_catalogue_access` |
| S-56 | Bearer `token_a`, header `X-Consent-Artefact: NOT-VALID-JSON` | expect 200 and empty `iudx_consent_id` |
| S-57 | Bearer `token_a`, header `X-Consent-Artefact` set to `{"id":"extracted-consent-id","type":"ConsentArtefact"}` | consent id stays empty |


**S-53.** IUDX headers without a bearer return `401`.

Already running: the API. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/iudx/verify" @{ "Fiware-Service" = "smartcity"; "X-Iudx-Consent-Id" = "consent-abc-123" }; $r.StatusCode; Add-Check "S-53" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-54.** After the `testuser` bearer, `X-Iudx-Consent-Id` is copied to `iudx_consent_id`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/iudx/verify" @{ Authorization = "Bearer $TokenA"; "Fiware-Service" = "smartcity"; "X-Iudx-Consent-Id" = "consent-abc-123" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.iudx_consent_id)"; Add-Check "S-54" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.iudx_consent_id -eq "consent-abc-123") { "PASS" } else { "FAIL" })
```

> ```
> 200 consent-abc-123
> ```

**S-55.** `X-Iudx-Catalogue-Access` is copied after the bearer.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/iudx/verify" @{ Authorization = "Bearer $TokenA"; "Fiware-Service" = "smartcity"; "X-Iudx-Catalogue-Access" = "rs.demo.example.com/cat/v1" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.iudx_catalogue_access)"; Add-Check "S-55" $(if ($r.StatusCode -eq 200 -and $b.iudx_catalogue_access -eq "rs.demo.example.com/cat/v1") { "PASS" } else { "FAIL" })
```

> ```
> 200 rs.demo.example.com/cat/v1
> ```

**S-56.** A malformed artefact body still returns `200`, and `iudx_consent_id` stays empty.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/iudx/verify" @{ Authorization = "Bearer $TokenA"; "Fiware-Service" = "smartcity"; "X-Consent-Artefact" = "NOT-VALID-JSON" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) [$($b.iudx_consent_id)]"; Add-Check "S-56" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and -not $b.iudx_consent_id) { "PASS" } else { "FAIL" })
```

> ```
> 200 []
> ```

**S-57.** A JSON artefact body does not set `iudx_consent_id`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$art = '{"id":"extracted-consent-id","type":"ConsentArtefact"}'; $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/iudx/verify" @{ Authorization = "Bearer $TokenA"; "Fiware-Service" = "smartcity"; "X-Consent-Artefact" = $art }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) [$($b.iudx_consent_id)]"; Add-Check "S-57" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and -not $b.iudx_consent_id) { "PASS" } else { "FAIL" })
```

> ```
> 200 []
> ```

## Aadhaar


The caller posts an Aadhaar XML header to the API on direct access. No XML is rejected. OTP alone is rejected. XML with no UIDAI key configured returns 501.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /auth/aadhaar/verify
  API-->>C: 401
  C->>API: POST aadhaar/verify header X-Aadhaar-Otp only
  API-->>C: 401
  C->>API: POST aadhaar/verify header X-Aadhaar-Xml
  API-->>C: 501
```

| Id | curl.exe | Postman |
|---|---|---|
| S-58 | `curl.exe -sS -D - -X POST "$API/authbox/default/default/api/v1/auth/aadhaar/verify"` | `POST` that URL, no headers. Expect 401 |
| S-59 | `-H "X-Aadhaar-Otp: 123456"` | header `X-Aadhaar-Otp`. Expect 401 |
| S-60 | `-H "X-Aadhaar-Xml: <PrintLetterBarcodeData uid='123456789012' />"` | header `X-Aadhaar-Xml`. Expect 501 |


Direct access (API port 8000). These calls send no bearer.

**S-58.** No `X-Aadhaar-Xml` returns `401`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-58" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/aadhaar/verify"; $r.StatusCode; Add-Check "S-58" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" }) }
```

> ```
> 401
> ```

**S-59.** `X-Aadhaar-Otp` without XML returns `401`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-59" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/aadhaar/verify" @{ "X-Aadhaar-Otp" = "123456" }; $r.StatusCode; Add-Check "S-59" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" }) }
```

> ```
> 401
> ```

**S-60.** XML with no UIDAI key configured returns `501`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-60" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/aadhaar/verify" @{ "X-Aadhaar-Xml" = "<PrintLetterBarcodeData uid='123456789012' />" }; $r.StatusCode; Add-Check "S-60" $(if ($r.StatusCode -eq 501) { "PASS" } else { "FAIL" }) }
```

> ```
> 501
> ```

## Wallet


The caller posts a verifiable presentation. No presentation header returns 501. A presentation that includes `proof` returns 200. Invalid JSON returns 400. A presentation with no `proof` returns 401. These calls use direct access.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /auth/wallet/verify
  API-->>C: 501
  C->>API: POST wallet/verify header X-Vp with proof
  API-->>C: 200 subject_id did:key
  C->>API: POST wallet/verify header X-Vp NOT-JSON
  API-->>C: 400
  C->>API: POST wallet/verify X-Vp with no proof
  API-->>C: 401
```

| Id | curl.exe | Postman |
|---|---|---|
| S-61 | `curl.exe -sS -D - -X POST "$API/authbox/default/default/api/v1/auth/wallet/verify"` | `POST` that URL. Expect 501 |
| S-62 | `-H "X-Vp: <presentation JSON with proof>"` | header `X-Vp`. The JSON is the one in the PowerShell line. Expect 200, `subject_id` starts with `did:key:`, `tenant_id` is `default` |
| S-63 | `-H "X-Vp: NOT-JSON"` | expect 400 |
| S-64 | `X-Vp` JSON with `type`, `holder`, and `verifiableCredential`, and no `proof` | expect 401 |


Direct access (API port 8000).

**S-61.** No wallet header returns `501`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-61" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/wallet/verify"; $r.StatusCode; Add-Check "S-61" $(if ($r.StatusCode -eq 501) { "PASS" } else { "FAIL" }) }
```

> ```
> 501
> ```

**S-62.** A verifiable presentation with `proof` returns `200`, `subject_id` contains `did:key:`, and `tenant_id` is `default`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-62" "SKIP" } else { $vp = '{"type":["VerifiablePresentation"],"holder":"did:key:z6Mkf5rGMoatrSj1f4CyvuHBeXJELe9RPdzo2PKGNCKVtZxP","verifiableCredential":[{"type":["VerifiableCredential"],"credentialSubject":{"id":"did:key:z6Mkf5rGMoatrSj1f4CyvuHBeXJELe9RPdzo2PKGNCKVtZxP"}}],"proof":{"type":"Ed25519Signature2020","proofValue":"mockproof"}}'; $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/wallet/verify" @{ "X-Vp" = $vp }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.subject_id) $($b.tenant_id)"; Add-Check "S-62" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.subject_id -like "did:key:*" -and $b.tenant_id -eq "default") { "PASS" } else { "FAIL" }) }
```

> ```
> 200 did:key:... default
> ```

**S-63.** Invalid JSON returns `400`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-63" "SKIP" } else { $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/wallet/verify" @{ "X-Vp" = "NOT-JSON" }; $r.StatusCode; Add-Check "S-63" $(if ($r.StatusCode -eq 400) { "PASS" } else { "FAIL" }) }
```

> ```
> 400
> ```

**S-64.** A presentation without `proof` returns `401`.

Already running: the API on the lab switch. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
if ($Access -ne "direct") { Add-Check "S-64" "SKIP" } else { $vp = '{"type":["VerifiablePresentation"],"holder":"did:key:testHolder","verifiableCredential":[{"credentialSubject":{"id":"did:key:test"}}]}'; $r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/wallet/verify" @{ "X-Vp" = $vp }; $r.StatusCode; Add-Check "S-64" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" }) }
```

> ```
> 401
> ```

## MCP


The caller asks the MCP routes to validate a token or to return config. Validate needs a bearer. Config needs a bearer whose roles include `admin`, `operator`, or `config_read`. `testuser` has `admin`. `tenant_b_user` has `viewer`.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: POST /mcp/validate with no bearer
  API-->>C: 401
  C->>API: POST /mcp/validate Bearer testuser
  API-->>C: 200 status success
  C->>API: GET /mcp/config Bearer tenant_b_user
  API-->>C: 403
  C->>API: GET /mcp/config Bearer testuser
  API-->>C: 200 status success
```

| Id | curl.exe | Postman |
|---|---|---|
| S-65 | `curl.exe -sS -D - -X POST "$API/authbox/default/default/api/v1/mcp/validate"` | `POST` that URL, no auth. Expect 401 |
| S-66 | `-H "Authorization: Token abc123"` | header `Authorization: Token abc123`. Expect 401 |
| S-67 | `-H "Authorization: Bearer $TokenA"` | Bearer `{{token_a}}`. Expect 200 |
| S-68 | `-H "Authorization: Bearer not-a-jwt-token"` | expect 401 |
| S-69 | `curl.exe -sS -D - "$API/authbox/default/default/api/v1/mcp/config"` | `GET` that URL, no auth. Expect 401 |
| S-70 | `-H "Authorization: Token abc123"` | expect 401 |
| S-71 | `-H "Authorization: Bearer $TokenB"` | Bearer `{{token_b}}`. Expect 403 |
| S-72 | `-H "Authorization: Bearer $TokenA"` | Bearer `{{token_a}}`. Expect 200 |


**S-65.** Validate with no header returns `401`. direct access for the API body. Gateway status is also `401`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/mcp/validate"; $r.StatusCode; Add-Check "S-65" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-66.** Validate with scheme `Token` returns `401`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/mcp/validate" @{ Authorization = "Token abc123" }; $r.StatusCode; Add-Check "S-66" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-67.** Validate with `testuser` returns `200` and `status` `success`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/mcp/validate" @{ Authorization = "Bearer $TokenA" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status)"; Add-Check "S-67" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.subject_id) { "PASS" } else { "FAIL" })
```

> ```
> 200 success
> ```

**S-68.** Validate with a bad bearer returns `401`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/mcp/validate" @{ Authorization = "Bearer not-a-jwt-token" }; $r.StatusCode; Add-Check "S-68" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-69.** Config with no header returns `401`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/mcp/config"; $r.StatusCode; Add-Check "S-69" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-70.** Config with scheme `Token` returns `401`.

Already running: the API. Reads nothing. Borrows nothing.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/mcp/config" @{ Authorization = "Token abc123" }; $r.StatusCode; Add-Check "S-70" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-71.** Config with `tenant_b_user` returns `403`.

Already running: the API and Keycloak. Reads `$TokenB` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/mcp/config" @{ Authorization = "Bearer $TokenB" }; $r.StatusCode; Add-Check "S-71" $(if ($r.StatusCode -eq 403) { "PASS" } else { "FAIL" })
```

> ```
> 403
> ```

**S-72.** Config with `testuser` returns `200` and `status` `success`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/mcp/config" @{ Authorization = "Bearer $TokenA" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status)"; Add-Check "S-72" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success") { "PASS" } else { "FAIL" })
```

> ```
> 200 success
> ```

## Login flow


Two paths reach a successful evaluate. S-73 takes the login URL from the API, then uses the password-grant token. S-74 follows that login URL, posts the user and password to the Keycloak form, exchanges the authorization code with the PKCE verifier, and evaluates the resulting access token.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  participant KC as Keycloak
  C->>API: GET /auth/authorize
  API-->>C: url and code_verifier
  C->>KC: GET url
  KC-->>C: login form
  C->>KC: POST username and password
  KC-->>C: redirect with code
  C->>API: POST /auth/token grant_type authorization_code code code_verifier redirect_uri
  API->>KC: exchange code
  KC-->>API: access token
  API-->>C: access token
  C->>API: GET /verifier/evaluate Bearer
  API-->>C: 200 status success
```

| Id | curl.exe | Postman |
|---|---|---|
| S-73 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/authorize"` then evaluate with the password-grant token from S-13 | `GET` authorize, then `GET` evaluate with Bearer `{{token_a}}` |
| S-74 | Open the `url` from authorize in a client that keeps cookies. Post the form with `AUTHBOX_USER_A` and `AUTHBOX_USER_A_PASSWORD`. Read `code` from the redirect. Exchange that code with `curl.exe --config` a UTF-8 file with no byte-order mark. The file carries `grant_type=authorization_code`, the code, the verifier from authorize, and the redirect. Do not put those values on the curl.exe command line. Evaluate that access token. | Same three calls. The callback URL on the lab switch is `http://localhost:8000/authbox/default/default/api/v1/auth/callback`. The client id is `NEXUS_AUTH_CLIENT_ID`. |


**S-73.** Authorize, then the password-grant token, then evaluate. This is the login path with the token taken from the password grant.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows the authorize URL from this call.

```powershell
$login = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize"; $r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer $TokenA" }; $b = $r.Content | ConvertFrom-Json; "$([bool]$login._sandbox_code_verifier) $($r.StatusCode) $($b.status)"; Add-Check "S-73" $(if ($login.url -and $login._sandbox_code_verifier -and $r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.subject_id -and $b.roles) { "PASS" } else { "FAIL" })
```

> ```
> True 200 success
> ```

**S-74.** Authorization-code exchange on the lab switch (API port 8000). The line opens the authorize URL, posts `AUTHBOX_USER_A` and `AUTHBOX_USER_A_PASSWORD` to the Keycloak form, exchanges `code` with `_sandbox_code_verifier`, and evaluates the access token.

Already running: the API on the lab switch, and Keycloak. Reads nothing from earlier tokens. Borrows the authorize URL, the code verifier, and the redirect from this call.

```powershell
if ($Access -ne "direct") { Add-Check "S-74" "SKIP" } else { $redir = "$API/authbox/default/default/api/v1/auth/callback"; $auth = Invoke-RestMethod "$API/authbox/default/default/api/v1/auth/authorize?redirect_uri=$([uri]::EscapeDataString($redir))"; $sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession; $page = Invoke-WebRequest -Uri $auth.url -WebSession $sess -MaximumRedirection 5 -UseBasicParsing; $action = [regex]::Match($page.Content, 'action="([^"]+)"').Groups[1].Value.Replace("&amp;","&"); if ($action.StartsWith("/")) { $action = "$KC$action" }; $login = Invoke-WebRequest -Uri $action -Method POST -WebSession $sess -ContentType "application/x-www-form-urlencoded" -Body "username=$env:AUTHBOX_USER_A&password=$env:AUTHBOX_USER_A_PASSWORD" -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue; $loc = [string]$login.Headers.Location; $code = [regex]::Match($loc, "code=([^&]+)").Groups[1].Value; $used = [uri]::UnescapeDataString(([regex]::Match($auth.url, "redirect_uri=([^&]+)").Groups[1].Value)); $tok = Invoke-RestMethod -Method Post -Uri "$API/authbox/default/default/api/v1/auth/token" -ContentType "application/x-www-form-urlencoded" -Body ("grant_type=authorization_code&code=" + [uri]::EscapeDataString($code) + "&code_verifier=" + [uri]::EscapeDataString($auth._sandbox_code_verifier) + "&redirect_uri=" + [uri]::EscapeDataString($used)); $ev = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate" @{ Authorization = "Bearer $($tok.access_token)" }; $eb = $ev.Content | ConvertFrom-Json; "$($ev.StatusCode) $($eb.status)"; Add-Check "S-74" $(if ($code -and $ev.StatusCode -eq 200 -and $eb.status -eq "success") { "PASS" } else { "FAIL" }) }
```

> ```
> 200 success
> ```

## Device trust and revoke

The caller pings with a machine token, then registers a device, reads it, suspends it, and revokes it. A device-anomaly action must be `suspend` or `revoke`. A register with `ttl_sec` of 0 is rejected. Revoke with the wrong client secret leaves the token usable. Revoke with `nexus-m2m` returns `revoked`, and the same token then fails the ping.

```mermaid
sequenceDiagram
  participant C as Caller
  participant API as authbox-api
  C->>API: GET /auth/m2m/ping Bearer machine token
  API-->>C: 200 status ok
  C->>API: GET /auth/m2m/ping no bearer
  API-->>C: 401
  C->>API: POST /auth/device-trust/register
  API-->>C: 200 trust_level trusted
  C->>API: GET /auth/device-trust/sensor-doc-1
  API-->>C: 200 trusted
  C->>API: POST /auth/device-trust/suspend
  API-->>C: 200 suspended
  C->>API: POST /auth/device-trust/revoke
  API-->>C: 200 empty trust_level
  C->>API: POST /auth/fiware/device-anomaly action nope
  API-->>C: 400
  C->>API: POST /auth/fiware/device-anomaly action suspend
  API-->>C: 200
  C->>API: POST /auth/token/revoke wrong secret
  API-->>C: 401
  C->>API: POST /auth/token/revoke nexus-m2m
  API-->>C: 200 status revoked
  C->>API: GET /auth/m2m/ping same token
  API-->>C: 401 token_revoked
```

| Id | curl.exe | Postman |
|---|---|---|
| S-75 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/m2m/ping" -H "Authorization: Bearer $TokenM"` | `GET {{api}}/authbox/default/default/api/v1/auth/m2m/ping`, Bearer `{{token_m}}` |
| S-76 | `curl.exe -sS -D - -o NUL "$API/authbox/default/default/api/v1/auth/m2m/ping"` | same URL, no auth. Direct access returns JSON `401`. Gateway access returns plain text `Jwt is missing` |
| S-77 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/auth/device-trust/register" -H "Authorization: Bearer $TokenA" -H "Content-Type: application/json" -d "{\"device_id\":\"sensor-doc-1\",\"trust_level\":\"trusted\",\"ttl_sec\":3600}"` | `POST` that URL, Bearer `{{token_a}}`, raw JSON body |
| S-78 | `curl.exe -sS "$API/authbox/default/default/api/v1/auth/device-trust/sensor-doc-1" -H "Authorization: Bearer $TokenA"` | `GET` that URL, Bearer `{{token_a}}` |
| S-79 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/auth/device-trust/suspend" -H "Authorization: Bearer $TokenA" -H "Content-Type: application/json" -d "{\"device_id\":\"sensor-doc-1\"}"` | `POST` suspend, same JSON `device_id` |
| S-80 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/auth/device-trust/revoke" -H "Authorization: Bearer $TokenA" -H "Content-Type: application/json" -d "{\"device_id\":\"sensor-doc-1\"}"` | `POST` device-trust revoke |
| S-81 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/auth/fiware/device-anomaly" -H "Authorization: Bearer $TokenA" -H "Content-Type: application/json" -d "{\"device_id\":\"sensor-doc-1\",\"action\":\"nope\"}"` | expect 400 |
| S-82 | `curl.exe -sS -X POST "$API/authbox/default/default/api/v1/auth/fiware/device-anomaly" -H "Authorization: Bearer $TokenA" -H "Content-Type: application/json" -d "{\"device_id\":\"sensor-doc-1\",\"reason\":\"data_quality\",\"action\":\"suspend\"}"` | expect 200, `action` `suspend` |
| S-83 | register body `"ttl_sec":0` | expect 400 |
| S-84 | `curl.exe --config` a UTF-8 file with no byte-order mark. Secret fields are the environment names in Setup. Do not put those values on the curl.exe command line. | expect 401, and S-75 still succeeds if you ping again before S-85 |
| S-85 | `curl.exe --config` a UTF-8 file with no byte-order mark. The secret field is `NEXUS_AUTH_M2M_CLIENT_SECRET`. The body also carries the machine token. Do not put that secret on the curl.exe command line. | expect `status` `revoked`. The next ping with that token is 401 `token_revoked` |

**S-75.** Machine ping with the `nexus-m2m` token returns `200` and `status` `ok`.

Already running: the API and Keycloak. Reads `$TokenM` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/m2m/ping" @{ Authorization = "Bearer $TokenM" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.status)"; Add-Check "S-75" $(if ($r.StatusCode -eq 200 -and $b.status -eq "ok" -and $b.tenant_id -eq "default") { "PASS" } else { "FAIL" })
```

> ```
> 200 ok
> ```

**S-76.** Machine ping with no bearer returns `401`. On gateway access the body is plain text `Jwt is missing`. On direct access the body is JSON.

Already running: the API. Reads nothing. Borrows nothing. No bearer is sent.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/m2m/ping"; $r.StatusCode; Add-Check "S-76" $(if ($r.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 401
> ```

**S-77.** Register device `sensor-doc-1` as `trusted` for 3600 seconds.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Stores device `sensor-doc-1` for S-78 through S-80.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/device-trust/register" @{ Authorization = "Bearer $TokenA" } '{"device_id":"sensor-doc-1","trust_level":"trusted","ttl_sec":3600}' "application/json"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.trust_level) $($b.ttl_sec)"; Add-Check "S-77" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.trust_level -eq "trusted" -and $b.ttl_sec -eq 3600) { "PASS" } else { "FAIL" })
```

> ```
> 200 trusted 3600
> ```

**S-78.** Read that device. `trust_level` is `trusted`.

Already running: the API and Keycloak. Reads `$TokenA` from setup and device `sensor-doc-1` from S-77.

```powershell
$r = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/device-trust/sensor-doc-1" @{ Authorization = "Bearer $TokenA" }; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.trust_level)"; Add-Check "S-78" $(if ($r.StatusCode -eq 200 -and $b.trust_level -eq "trusted" -and $b.device_id -eq "sensor-doc-1") { "PASS" } else { "FAIL" })
```

> ```
> 200 trusted
> ```

**S-79.** Suspend that device.

Already running: the API and Keycloak. Reads `$TokenA` from setup and device `sensor-doc-1` from S-77.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/device-trust/suspend" @{ Authorization = "Bearer $TokenA" } '{"device_id":"sensor-doc-1"}' "application/json"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.trust_level)"; Add-Check "S-79" $(if ($r.StatusCode -eq 200 -and $b.trust_level -eq "suspended") { "PASS" } else { "FAIL" })
```

> ```
> 200 suspended
> ```

**S-80.** Revoke that device trust entry. `trust_level` is empty.

Already running: the API and Keycloak. Reads `$TokenA` from setup and device `sensor-doc-1` from S-77.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/device-trust/revoke" @{ Authorization = "Bearer $TokenA" } '{"device_id":"sensor-doc-1"}' "application/json"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) [$($b.trust_level)]"; Add-Check "S-80" $(if ($r.StatusCode -eq 200 -and $b.trust_level -eq "") { "PASS" } else { "FAIL" })
```

> ```
> 200 []
> ```

**S-81.** Device anomaly with action `nope` returns `400`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/device-anomaly" @{ Authorization = "Bearer $TokenA" } '{"device_id":"sensor-doc-1","action":"nope"}' "application/json"; $r.StatusCode; Add-Check "S-81" $(if ($r.StatusCode -eq 400) { "PASS" } else { "FAIL" })
```

> ```
> 400
> ```

**S-82.** Device anomaly with action `suspend` returns `200`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/fiware/device-anomaly" @{ Authorization = "Bearer $TokenA" } '{"device_id":"sensor-doc-1","reason":"data_quality","action":"suspend"}' "application/json"; $b = $r.Content | ConvertFrom-Json; "$($r.StatusCode) $($b.action)"; Add-Check "S-82" $(if ($r.StatusCode -eq 200 -and $b.status -eq "success" -and $b.action -eq "suspend") { "PASS" } else { "FAIL" })
```

> ```
> 200 suspend
> ```

**S-83.** Register with `ttl_sec` of 0 returns `400`.

Already running: the API and Keycloak. Reads `$TokenA` from setup. Borrows nothing else.

```powershell
$r = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/device-trust/register" @{ Authorization = "Bearer $TokenA" } '{"device_id":"sensor-doc-1","trust_level":"trusted","ttl_sec":0}' "application/json"; $r.StatusCode; Add-Check "S-83" $(if ($r.StatusCode -eq 400) { "PASS" } else { "FAIL" })
```

> ```
> 400
> ```

**S-84.** Revoke with the wrong machine secret returns `401`, and the machine token still pings.

Already running: the API and Keycloak. Reads `$TokenM` from setup. Run this before S-85. A wrong secret does not revoke the token.

```powershell
$bad = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token/revoke" @{} "token=$TokenM&client_id=nexus-m2m&client_secret=wrong" "application/x-www-form-urlencoded"; $ping = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/m2m/ping" @{ Authorization = "Bearer $TokenM" }; "$($bad.StatusCode) $($ping.StatusCode)"; Add-Check "S-84" $(if ($bad.StatusCode -eq 401 -and $ping.StatusCode -eq 200) { "PASS" } else { "FAIL" })
```

> ```
> 401 200
> ```

**S-85.** Revoke with `nexus-m2m` returns `revoked`. The same token then fails the ping with `token_revoked`.

Already running: the API and Keycloak. Reads `$TokenM` from setup. After this check that token no longer pings.

```powershell
$ok = Invoke-Api POST "$API/authbox/default/default/api/v1/auth/token/revoke" @{} "token=$TokenM&client_id=$env:NEXUS_SIMULATOR_M2M_CLIENT_ID&client_secret=$env:NEXUS_AUTH_M2M_CLIENT_SECRET" "application/x-www-form-urlencoded"; $b = $ok.Content | ConvertFrom-Json; $ping = Invoke-Api GET "$API/authbox/default/default/api/v1/auth/m2m/ping" @{ Authorization = "Bearer $TokenM" }; "$($ok.StatusCode) $($b.status) $($ping.StatusCode)"; Add-Check "S-85" $(if ($ok.StatusCode -eq 200 -and $b.status -eq "revoked" -and $ping.StatusCode -eq 401) { "PASS" } else { "FAIL" })
```

> ```
> 200 revoked 401
> ```

## Progressive builds

Run Phase 1 on **Base** first (full S-01…S-85). Then install **Base Secure**, reassign setup, remint `$TokenA` / `$TokenB` / `$TokenM`, and re-run the bearer groups that matter for gateway access (Health S-01, Evaluate S-16…S-23, Machine tokens, FIWARE/IUDX/MCP with bearer, Device trust S-75…S-85). Direct-only ids record `SKIP`. Then install **Base PKI**, reassign setup, remint tokens, repeat the Base Secure gateway pass, and add B-04…B-06.

Cross-references: ports and defaults [USER-GUIDE.md](USER-GUIDE.md) §7 and §9; listening matrix [TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md); tips [helpers/README.md](helpers/README.md).

**B-01.** Base health: Postgres ready, API `:8000` health `ok`, Keycloak discovery `:8080`, Envoy admin `:9901/ready`.

Already running: **Base**. Reads nothing.

```powershell
if ($Build -ne "base") { Add-Check "B-01" "SKIP" } else { $pg = docker exec auth-sandbox-postgres-1 pg_isready -U nexus -d authbox_lab; $health = Invoke-RestMethod "$API/authbox/health"; $kc = (Invoke-WebRequest -Uri "$KC/realms/nexus-test/.well-known/openid-configuration" -UseBasicParsing).StatusCode; $en = (Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode; "pg=$pg api=$($health.status) kc=$kc en=$en"; Add-Check "B-01" $(if (("$pg" -match "accepting") -and $health.status -eq "ok" -and $kc -eq 200 -and $en -eq 200) { "PASS" } else { "FAIL" }) }
```

**B-02.** Base Secure: lab TCP `:8000` and `:8080` closed; gateway health `ok`.

Already running: **Base Secure**. Reads nothing.

```powershell
if ($Build -ne "base-secure") { Add-Check "B-02" "SKIP" } else { function Test-Tcp([int]$Port) { try { $c = New-Object Net.Sockets.TcpClient; $iar = $c.BeginConnect("127.0.0.1",$Port,$null,$null); $ok = $iar.AsyncWaitHandle.WaitOne(500,$false); if ($ok) { $c.EndConnect($iar) | Out-Null }; $c.Close(); return $ok } catch { return $false } }; $open = (Test-Tcp 8000) -or (Test-Tcp 8080); $health = Invoke-RestMethod "http://localhost:9000/authbox/health"; "lab_open=$open api=$($health.status)"; Add-Check "B-02" $(if (-not $open -and $health.status -eq "ok") { "PASS" } else { "FAIL" }) }
```

**B-03.** Base Secure / Base PKI: missing bearer on a protected path is plain-text Envoy `401` (`Jwt is missing`).

Already running: gateway build. Reads nothing. No bearer.

```powershell
if ($Access -ne "gateway") { Add-Check "B-03" "SKIP" } else { $r = Invoke-Api GET "$API/authbox/default/default/api/v1/verifier/evaluate"; "$($r.StatusCode) $($r.Content)"; Add-Check "B-03" $(if ($r.StatusCode -eq 401 -and ("$($r.Content)" -match "Jwt is missing")) { "PASS" } else { "FAIL" }) }
```

**B-04.** Base PKI: step-ca health returns `ok` inside `auth-sandbox-step-ca-1`.

Already running: **Base PKI**. Reads nothing. Tip script: [helpers/tip-stepca-health.ps1](helpers/tip-stepca-health.ps1).

```powershell
if ($Build -ne "base-pki") { Add-Check "B-04" "SKIP" } else { $out = docker exec auth-sandbox-step-ca-1 step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt; "$out"; Add-Check "B-04" $(if ("$out" -match "ok") { "PASS" } else { "FAIL" }) }
```

**B-05.** Base PKI optional device ports: report TCP `:1029` / `:8883` open or closed (closed is not a FAIL when listeners are unpublished).

Already running: **Base PKI**. Tip script: [helpers/tip-mtls-ports.ps1](helpers/tip-mtls-ports.ps1).

```powershell
if ($Build -ne "base-pki") { Add-Check "B-05" "SKIP" } else { function Test-Tcp([int]$Port) { try { $c = New-Object Net.Sockets.TcpClient; $iar = $c.BeginConnect("127.0.0.1",$Port,$null,$null); $ok = $iar.AsyncWaitHandle.WaitOne(500,$false); if ($ok) { $c.EndConnect($iar) | Out-Null }; $c.Close(); return $ok } catch { return $false } }; $a = if (Test-Tcp 1029) { "open" } else { "closed" }; $b = if (Test-Tcp 8883) { "open" } else { "closed" }; "1029=$a 8883=$b"; Add-Check "B-05" "PASS" }
```

**B-06.** Base PKI: gateway health still `ok` after step-ca is present; then continue device-trust S-75…S-83 on this same `$API`.

Already running: **Base PKI**. Reads nothing. Cross-ref [Device trust and revoke](#device-trust-and-revoke).

```powershell
if ($Build -ne "base-pki") { Add-Check "B-06" "SKIP" } else { $health = Invoke-RestMethod "$API/authbox/health"; $en = (Invoke-WebRequest -Uri "http://localhost:9901/ready" -UseBasicParsing).StatusCode; "api=$($health.status) en=$en"; Add-Check "B-06" $(if ($health.status -eq "ok" -and $en -eq 200) { "PASS" } else { "FAIL" }) }
```

## Results

```powershell
$Results | Format-Table -AutoSize; "PASS=$((@($Results | Where-Object Result -eq 'PASS')).Count) FAIL=$((@($Results | Where-Object Result -eq 'FAIL')).Count) SKIP=$((@($Results | Where-Object Result -eq 'SKIP')).Count)"
```

On **Base** (`$Access` `direct`) the S-* SKIP count is `0`; B-02…B-06 are `SKIP`. On **Base Secure**, S-02, S-03, S-31 through S-47, S-58 through S-64, and S-74 are `SKIP`; B-01 and B-04…B-06 are `SKIP`. On **Base PKI**, the same S-* SKIP set as Base Secure; B-01 and B-02 are `SKIP`; B-03…B-06 run. A `FAIL` line is the scenario id to rerun on its own. Setting `$Build` does not start containers.

## Scenario index

| Id | What it checks |
|---|---|
| S-01 | Health `ok` |
| S-02 | Root `version` `7.0.0` |
| S-03 | OpenAPI document |
| S-04 | Authorize URL |
| S-05 | PKCE verifier length |
| S-06 | State echo |
| S-07 | Sandbox note |
| S-08 | Custom state |
| S-09 | Callback with code |
| S-10 | Callback without code |
| S-11 | Callback `access_denied` |
| S-12 | Token form with no `grant_type` |
| S-13 | `testuser` claim `tid` |
| S-14 | `tenant_b_user` claim `tid` |
| S-15 | `nexus-m2m` claim `tid` |
| S-16 | Evaluate `default` / `default` |
| S-17 | Evaluate, no header |
| S-18 | Evaluate, garbage bearer |
| S-19 | Evaluate, scheme `Token` |
| S-20 | Evaluate, scheme `Basic` |
| S-21 | Evaluate, unknown role |
| S-22 | Evaluate, `viewer` on `testuser` |
| S-23 | Evaluate, URL tenants `org-a` / `org-b` |
| S-24 | API client credentials, `nexus-sandbox` |
| S-25 | API client credentials, `nexus-m2m` |
| S-26 | API client credentials, default client |
| S-27 | Wrong machine secret |
| S-28 | Blank machine credentials |
| S-29 | Machine token evaluates |
| S-29b | Both user tokens evaluate |
| S-30 | MFA enroll |
| S-31 | MFA challenge and verify |
| S-32 | OTP generate |
| S-33 | OTP code |
| S-34 | OTP verify success |
| S-35 | OTP verify `000000` |
| S-36 | OTP code from configured secret |
| S-37 | OTP invalid secret |
| S-38 | OTP non-numeric code |
| S-39 | OTP short code |
| S-40 | Two secrets, two codes |
| S-41 | Edge username with no password |
| S-42 | Edge protected user with password |
| S-43 | Edge wrong password |
| S-44 | Edge unknown user |
| S-45 | Edge missing header |
| S-46 | Edge role `admin` denied |
| S-47 | Edge role `operator` allowed |
| S-48 | FIWARE headers alone |
| S-49 | FIWARE with bearer |
| S-50 | FIWARE subject is correlation |
| S-51 | FIWARE unknown role |
| S-52 | FIWARE `viewer` |
| S-53 | IUDX headers alone |
| S-54 | IUDX consent id |
| S-55 | IUDX catalogue access |
| S-56 | IUDX malformed artefact |
| S-57 | IUDX JSON artefact ignored |
| S-58 | Aadhaar, no XML |
| S-59 | Aadhaar, OTP only |
| S-60 | Aadhaar, XML, no key |
| S-61 | Wallet, no header |
| S-62 | Wallet presentation |
| S-63 | Wallet invalid JSON |
| S-64 | Wallet missing proof |
| S-65 | MCP validate, no header |
| S-66 | MCP validate, scheme `Token` |
| S-67 | MCP validate, bearer |
| S-68 | MCP validate, bad bearer |
| S-69 | MCP config, no header |
| S-70 | MCP config, scheme `Token` |
| S-71 | MCP config, `tenant_b_user` |
| S-72 | MCP config, `testuser` |
| S-73 | Authorize plus evaluate |
| S-74 | Authorization-code exchange |
| S-75 | Machine ping |
| S-76 | Machine ping, no bearer |
| S-77 | Device trust register |
| S-78 | Device trust read |
| S-79 | Device trust suspend |
| S-80 | Device trust revoke |
| S-81 | Device anomaly, bad action |
| S-82 | Device anomaly, suspend |
| S-83 | Device trust, `ttl_sec` 0 |
| S-84 | Token revoke, wrong secret |
| S-85 | Token revoke, then ping fails |
| B-01 | Base health |
| B-02 | Base Secure lab ports closed |
| B-03 | Gateway Jwt is missing |
| B-04 | Base PKI step-ca health |
| B-05 | Base PKI device port tip |
| B-06 | Base PKI gateway still healthy |
