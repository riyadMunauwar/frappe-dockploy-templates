# Frappe Dokploy Templates

Dokploy templates for running Frappe products, published from this repo rather than Dokploy's official template repository.

## Language

**Product**:
A Frappe end-user application offered as one deployable template (e.g. CRM, Helpdesk, Frappe HR).
_Avoid_: app (an app is a bench-level package; a Product may bundle several apps)

**App**:
A Frappe bench package installed into a site (e.g. `crm`, `whatsapp`, `erpnext`).

**Blueprint**:
The Dokploy template for one Product, living at `blueprints/<product-id>/`.
_Avoid_: template folder

**Product Image**:
The container image containing Frappe plus every App a Product needs, built by this repo's CI and published to this repo owner's GHCR.
_Avoid_: official image (that means the upstream `ghcr.io/frappe/<app>` / `frappe/erpnext` images, which this project does not use for Products)

**Site**:
The single Frappe site a Blueprint deployment creates, named after the deployment's domain.

**Setup Job**:
A one-shot container in a Blueprint (configurator, create-site, migrate) that runs on every deploy, does its work only if needed, then exits.
_Avoid_: init container, toggle service

## Relationships

- A **Product** has exactly one **Blueprint** and one **Product Image**
- A **Product Image** contains one or more **Apps**; the Blueprint installs them into one **Site**

## Flagged ambiguities

- "template" was used for both the Dokploy blueprint folder and `template.toml` — resolved: **Blueprint** is the folder; `template.toml` is one optional file inside it.
