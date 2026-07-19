# Deploying to Coolify (Phoenix / Elixir)

Step-by-step notes for deploying this app (`check_signature`, domain
`orzecze-nie.pl`) to a self-hosted **Coolify** instance. Mirrors the `meters`
(martwemetry.pl) setup — swap the app name, module, and domain to reuse it again.

Deployment model: **Dockerfile build pack** → Elixir release → Coolify's Traefik
proxy terminates TLS (Let's Encrypt) and forwards to the container on port `4000`.

---

## 0. One-time repo prep (already done here)

Generated with `mix phx.gen.release --docker` and committed:

- `Dockerfile` — multi-stage build, pinned to Elixir 1.18.1 / OTP 27.3. Ends with
  `EXPOSE 4000` and `CMD /app/bin/migrate && /app/bin/server` (migrations run on
  every boot, then the server starts).
- `.dockerignore`
- `rel/overlays/bin/server`, `rel/overlays/bin/migrate` — start + migration scripts.
- `lib/check_signature/release.ex` — `CheckSignature.Release.migrate/0`.

Prod config already in the repo:

- `config/prod.exs` — `force_ssl: [rewrite_on: [:x_forwarded_proto]]`,
  `cache_static_manifest`.
- `config/runtime.exs` — reads `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`,
  `PORT`, `POOL_SIZE`, `ECTO_IPV6` from env; binds HTTP on all interfaces.

> No mailer to configure — this app sends no email (it stores nothing; see
> `docs/adr/0003-store-no-user-content.md`).

---

## 1. Generate a secret key base

```bash
mix phx.gen.secret
```

Copy the output — it becomes `SECRET_KEY_BASE` (step 5). Never commit it.

## 2. Push the repo somewhere Coolify can reach

Coolify deploys from Git (GitHub/GitLab or a plain Git URL). Push the branch you
want to deploy (e.g. `main`), including the `Dockerfile`.

## 3. Create the Postgres database in Coolify

1. Coolify → **Project** → **+ New** → **Database** → **PostgreSQL** (v16), on the
   same server/network you'll deploy the app to. Deploy it.
2. Use the **internal** connection host (service name) so the app reaches the DB
   over Coolify's private network — do **not** expose the DB publicly.
3. Ecto wants the `ecto://` scheme: `ecto://<user>:<pass>@<internal-host>:5432/<db>`.

> ⚠️ **The database must exist before the app deploys.** The release runs
> migrations (`bin/migrate`) but **cannot create the database** (`mix ecto.create`
> isn't in a release). Create it by hand if needed:
>
> ```sql
> CREATE DATABASE check_signature;
> CREATE USER check_signature_app WITH PASSWORD 'a-strong-password';
> GRANT ALL PRIVILEGES ON DATABASE check_signature TO check_signature_app;
> \c check_signature
> GRANT ALL ON SCHEMA public TO check_signature_app;   -- Postgres 15+
> ```

## 4. Create the application resource

1. Coolify → **Project** → **+ New** → **Application** → Git repository + branch.
2. **Build Pack: `Dockerfile`** (auto-detected).
3. **Ports Exposes:** `4000`.
4. Put the app on the **same network/server** as the Postgres from step 3.

## 5. Environment variables

App → **Environment Variables**:

| Variable          | Value / example                                        | Required |
| ----------------- | ------------------------------------------------------ | -------- |
| `SECRET_KEY_BASE` | output of `mix phx.gen.secret`                         | ✅ yes   |
| `DATABASE_URL`    | `ecto://user:pass@check-signature-db:5432/check_signature` | ✅ yes |
| `PHX_HOST`        | `orzecze-nie.pl`                                       | ✅ yes   |
| `PORT`            | `4000` (only if you change the exposed port)           | no       |
| `POOL_SIZE`       | `10`                                                   | no       |
| `ECTO_IPV6`       | `true` — only if the DB is reached over IPv6           | no       |

Notes:
- **Do not** set `PHX_SERVER` — `bin/server` (the container `CMD`) sets it.
- **SSL to the DB:** if the DB requires TLS (managed providers), uncomment
  `ssl: true` under `config :check_signature, CheckSignature.Repo` in
  `config/runtime.exs`. Coolify's internal Postgres does not need it.
- **Outbound network:** the app scrapes sn.pl, orzeczenia.nsa.gov.pl and calls
  saos.org.pl — the server must allow outbound HTTPS (usually fine by default).

## 6. Migrations (automatic — baked into the image)

`CMD /app/bin/migrate && /app/bin/server` runs migrations on every container boot,
then starts the server. A failed migration aborts startup, so a broken schema
never serves traffic; Ecto's migration lock makes running it on every restart safe.

> First deploy: the DB is empty; `bin/migrate` creates the `cached_verdicts` table.
> To migrate an already-running prod without a redeploy: Coolify → app →
> **Terminal** → `/app/bin/migrate`.

## 7. Domain + HTTPS

1. DNS: an **A record** for `orzecze-nie.pl` (and `www` if wanted) → your Coolify
   server's public IP.
2. App → **Domains**: set `https://orzecze-nie.pl`. Coolify (Traefik) provisions a
   Let's Encrypt cert automatically once DNS resolves.
3. TLS terminates at the proxy; `force_ssl: [rewrite_on: [:x_forwarded_proto]]`
   (in `config/prod.exs`) makes Phoenix trust the `x-forwarded-proto` header.

Set the DNS at the registrar (change the apex `A` record off any parking, remove
redirects, lower TTL to 300s before switching). Verify
`dig +short orzecze-nie.pl` returns the Coolify IP **before** Coolify can issue the
cert. Let's Encrypt certs auto-renew (~30 days before the 90-day expiry) as long as
**port 80 stays open** and DNS keeps pointing at the server.

### SSL troubleshooting (mental model)

- **Redirect loop (`ERR_TOO_MANY_REDIRECTS`)** = app/header problem — confirm the
  Coolify domain is `https://` and the proxy sends `X-Forwarded-Proto` (default).
- **"Not secure" / default Traefik cert** = ACME/DNS/ports. Most common cause: the
  domain was added **before** the A record existed, so the first ACME attempt
  failed and Traefik won't retry on its own. Fix: add the A record → wait for
  `dig` → **Redeploy** (or Servers → Proxy → Restart). Verify issuer with
  `echo | openssl s_client -connect orzecze-nie.pl:443 -servername orzecze-nie.pl 2>/dev/null | openssl x509 -noout -issuer` → should be Let's Encrypt.
- **Works in incognito only** = cached **HSTS**. `force_ssl` sends HSTS; if the
  site was ever served with a bad cert the browser refuses until it's valid. Clear
  at `chrome://net-internals/#hsts`, or temporarily set
  `force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: false]` during first setup.

## 8. Analytics — Plausible (first-party proxy)

Wired in this repo to dodge ad blockers (served from our own domain):

- `lib/check_signature_web/controllers/analytics_controller.ex` — `script/2`
  fetches + caches (1h in `:persistent_term`) the extended Plausible script;
  `event/2` proxies POSTs to Plausible's `/api/event`, forwarding `user-agent` +
  client IP. Uses the shared instance `plausible.przetargowyprzeglad.pl`.
- `router.ex` — a **pipeline-less** scope so `POST /api/event` skips CSRF:
  `get "/js/stats.js"` and `post "/api/event"`.
- The landing page `<head>` carries
  `<script defer data-domain="orzecze-nie.pl" data-api="/api/event" src="/js/stats.js">`.

**Deploy-time step (once):** in the shared **Plausible dashboard**, **add the site
`orzecze-nie.pl`** — otherwise Plausible rejects events for an unknown site. No
Coolify change needed; the proxy calls Plausible server-side over HTTPS.

**Verify:** `curl -s https://orzecze-nie.pl/js/stats.js | head -c 60` returns JS,
then load the site and confirm a visit appears in Plausible.

## 9. Deploy & verify

1. Click **Deploy**. Watch the build logs (first build downloads deps + builds
   assets; later builds are cached).
2. When healthy, visit `https://orzecze-nie.pl` — the landing page loads.
3. Paste the sample document (`priv/examples/sample_document.md`) → confirm the
   verdicts stream back and `robots.txt` responds.

## 10. Redeploying / rollback

- Push to `main` → Coolify redeploys (enable auto-deploy on push, or click
  **Redeploy**). Migrations run automatically on boot.
- **Rollback:** Coolify keeps previous images — **Deployments → Rollback**. Undo a
  bad migration: App → **Terminal** →
  `/app/bin/check_signature eval "CheckSignature.Release.rollback(CheckSignature.Repo, <version>)"`.

## Troubleshooting

- **`DATABASE_URL is missing` / `SECRET_KEY_BASE is missing`** → env var unset (step 5).
- **Health check fails with 301** → that's `force_ssl` redirecting http→https. Set
  the Coolify health check to accept `200-399`, or disable the container health check.
- **DB connection refused** → app and DB not on the same Coolify network, or you
  used the DB's public host instead of the internal service name.
- **Assets missing / unstyled** → the image builds them via `mix assets.deploy` in
  the Dockerfile; check the build logs for that step. (The landing page also ships
  its own inline CSS, so it renders even before the digested assets load.)
