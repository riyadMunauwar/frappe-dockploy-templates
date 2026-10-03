# frappe-dockploy-templates

[Dokploy](https://dokploy.com) templates for Frappe products, served from this repo instead of Dokploy's official template repository.

| Blueprint | Apps in the image | Version |
|---|---|---|
| `erpnext` | erpnext | v16.37.0 |
| `erpnext-payments` | payments, erpnext | v16.37.0 |
| `erpnext-suite` | payments, erpnext, hrms | v16.37.0 |
| `frappe-builder` | builder | v1.35.0 |
| `frappe-crm` | whatsapp, crm | v1.86.0 |
| `frappe-helpdesk` | telephony, helpdesk | v1.30.1 |
| `frappe-hr` | erpnext, hrms | v16.20.1 |
| `frappe-insights` | insights | v3.14.2 |
| `frappe-learning` | payments, lms | v2.64.0 |

All run on Frappe `version-16`. Images are built by this repo (see [ADR 0001](docs/adr/0001-own-product-images.md)) and published to `ghcr.io/riyadmunauwar/<blueprint>`.

## Layout

```
images/<id>/apps.json        apps baked into the Product Image (frappe_docker apps.json format)
images/<id>/image.env        IMAGE_TAG + INSTALL_APPS (install order) for the Product
templates/                   shared docker-compose.yml + template.toml sources
blueprints/<id>/             rendered Dokploy template: docker-compose.yml, template.toml, meta.json, logo
meta.json                    index of all blueprints, read by Dokploy's custom Base URL
scripts/render.sh            renders blueprints/ and meta.json from images/ + templates/
scripts/check.sh             static checks (also run in CI)
```

`blueprints/*/docker-compose.yml`, `blueprints/*/template.toml` and the root `meta.json` are generated: edit `templates/`, `images/` or `blueprints/<id>/meta.json`, then run `bash scripts/render.sh`.

## One-time setup

1. Push to `main`. The **Build Product Images** workflow builds and pushes every image (or run it manually from the Actions tab).
2. GHCR packages start private. For each `erpnext*` and `frappe-*` package under your GitHub profile → Packages → Package settings → **Change visibility → Public**, so Dokploy can pull without credentials.

## Deploying in Dokploy

**From the template list:** in Dokploy, open a project → *Create Service* → *Template*, set the **Base URL** to

```
https://raw.githubusercontent.com/riyadMunauwar/frappe-dockploy-templates/main
```

then pick a Frappe product. Dokploy generates the domain, `ADMIN_PASSWORD` and `DB_ROOT_PASSWORD`.

**Or as a plain Compose service:** paste `blueprints/<id>/docker-compose.yml`, set `SITE_NAME` (your domain), `ADMIN_PASSWORD` and `DB_ROOT_PASSWORD` in the Environment tab, and add a domain pointing at service `frontend`, port `8080`.

The first deploy creates the site and installs the apps; it takes several minutes. Log in as `Administrator` with `ADMIN_PASSWORD`.

### What runs

- **Setup Jobs**, on every deploy, in order: `configurator` (writes bench config), `create-site` (only if the site doesn't exist yet; enables the scheduler), `migrate` (maintenance mode on → `bench migrate` → off). See [ADR 0002](docs/adr/0002-idempotent-setup-jobs.md).
- **Services:** `frontend` (nginx, port 8080), `backend` (gunicorn), `websocket`, `queue-short`, `queue-long`, `scheduler`, `db` (MariaDB 11.8), `redis-cache`, `redis-queue`.
- **Named volumes** (back them up with Dokploy volume backups): `sites`, `db-data`, `redis-queue-data`, `logs`.

### Optional environment variables

| Variable | Default |
|---|---|
| `IMAGE_TAG` | the Blueprint's pinned version |
| `IMAGE_NAME` | `ghcr.io/riyadmunauwar/<id>` |
| `GUNICORN_WORKERS` / `GUNICORN_THREADS` / `GUNICORN_TIMEOUT` | `2` / `4` / `120` |
| `CLIENT_MAX_BODY_SIZE` / `PROXY_READ_TIMEOUT` | `50m` / `120` |
| `PULL_POLICY` | `always` |
| `DB_VERSION` / `REDIS_VERSION` | `11.8` / `8.6-alpine` |

`INSTALL_APPS` only matters on the first deploy, because the site is created once.

## Upgrading a product

1. Edit `images/<id>/apps.json` (new app tags) and `IMAGE_TAG` in `images/<id>/image.env`. `IMAGE_TAG` is the Primary App's release; if only another app changed, append `-N` (e.g. `v16.37.0-1`) so a published tag is never rebuilt with different contents. `scripts/check.sh` warns when an app shared by several Products is pinned differently: bump them together unless you are holding one back on purpose.
2. Update `version` in `blueprints/<id>/meta.json`.
3. Run `bash scripts/render.sh && bash scripts/check.sh`, commit and push. CI builds the new image.
4. In Dokploy, set `IMAGE_TAG` to the new version and redeploy; the `migrate` job runs automatically.
