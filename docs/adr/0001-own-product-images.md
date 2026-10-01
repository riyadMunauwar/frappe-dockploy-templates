# Build our own Product Images instead of using upstream app images

Frappe production containers must have every App baked in at build time (`bench get-app` in a running container is unsupported), and frappe_docker only publishes `frappe/erpnext`. The per-app images upstream (`ghcr.io/frappe/crm`, `insights`, `builder`, `lms`) are still pushed on every release, but since frappe_docker switched `apps.json` from the `APPS_JSON_BASE64` build-arg to a BuildKit secret (2026-04-05), those repos' workflows silently produce images containing only Frappe. We therefore build every Product Image ourselves in this repo's GitHub Actions with frappe_docker's layered Containerfile, pinned to app release tags, with a smoke test asserting each App is present — even for Products whose upstream image currently works (Helpdesk, HR), so one pattern covers all Blueprints.

## Considered Options

- Upstream per-app images: zero CI, but four of six are currently broken and we can't fix their pipelines.
- Dokploy builds at deploy time (`build:` in compose): recompiles frontend assets on the production server every deploy.
- Runtime `bench get-app` on first boot (the dev `init.sh` pattern): explicitly unsupported for production by frappe_docker.
