# Build our own Product Images instead of using upstream app images

Frappe production containers must have every App baked in at build time (`bench get-app` in a running container is unsupported), and frappe_docker only publishes `frappe/erpnext`. The per-app images upstream (`ghcr.io/frappe/crm`, `insights`, `builder`, `lms`) are still pushed on every release, but since frappe_docker switched `apps.json` from the `APPS_JSON_BASE64` build-arg to a BuildKit secret (2026-04-05), those repos' workflows silently produce images containing only Frappe. We therefore build every Product Image ourselves in this repo's GitHub Actions with frappe_docker's layered Containerfile, pinned to app release tags, with a smoke test asserting each App is present — even for Products whose upstream image currently works (Helpdesk, HR), so one pattern covers all Blueprints.

## Considered Options

- Upstream per-app images: zero CI, but four of six are currently broken and we can't fix their pipelines.
- Dokploy builds at deploy time (`build:` in compose): recompiles frontend assets on the production server every deploy.
- Runtime `bench get-app` on first boot (the dev `init.sh` pattern): explicitly unsupported for production by frappe_docker.

## Amendment (2026-10-02): untagged Apps and tag uniqueness

- Some Apps publish no release tags, and `apps.json` can only name a branch or tag (`bench get-app --branch`), not a commit. Such Apps track a branch instead, preferring the stable `version-N` branch where one exists: `payments` follows `version-16` (Frappe Learning, ERPNext + Payments, ERPNext Suite); `telephony` has only `develop` (Frappe Helpdesk). These images are not bit-for-bit reproducible from their tag; we accept that for small, slow-moving companion Apps.
- ERPNext ships as its own Products (ERPNext, ERPNext + Payments, ERPNext Suite) under this same pattern, even though `frappe/erpnext` is the one upstream image that works.
- `IMAGE_TAG` is the Primary App's release. If only a non-primary App changes, append `-N` (e.g. `v16.37.0-1`) so a published tag is never rebuilt with different contents.
