#!/usr/bin/env bash
# Static checks for Product definitions (images/) and Blueprints (blueprints/).
# Usage: scripts/check.sh            -> exits non-zero and lists every failure
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
is_json() { perl -MJSON::PP -e 'local $/; decode_json(<>)' "$1" 2>/dev/null; }
is_json_array() { perl -MJSON::PP -e 'local $/; ref decode_json(<>) eq "ARRAY" or die' "$1" 2>/dev/null; }

products=()
for dir in images/*/; do products+=("$(basename "$dir")"); done
[[ ${#products[@]} -gt 0 ]] || fail "no products found under images/"

for id in "${products[@]}"; do
  img="images/$id" bp="blueprints/$id"

  # --- Product definition
  [[ -f "$img/apps.json" ]] || fail "$id: missing $img/apps.json"
  is_json_array "$img/apps.json" || fail "$id: $img/apps.json is not a valid JSON array"
  [[ -f "$img/image.env" ]] || { fail "$id: missing $img/image.env"; continue; }
  IMAGE_TAG="" INSTALL_APPS=""
  # shellcheck disable=SC1090
  source "$img/image.env"
  [[ -n "$IMAGE_TAG" ]] || fail "$id: IMAGE_TAG empty in $img/image.env"
  [[ -n "$INSTALL_APPS" ]] || fail "$id: INSTALL_APPS empty in $img/image.env"
  for app in $INSTALL_APPS; do
    grep -q "\"https://github.com/[^\"]*/$app\"" "$img/apps.json" \
      || fail "$id: app '$app' is installed but not listed in $img/apps.json"
  done

  # --- Blueprint files
  for f in docker-compose.yml template.toml meta.json; do
    [[ -f "$bp/$f" ]] || fail "$id: missing $bp/$f"
  done
  [[ -f "$bp/docker-compose.yml" && -f "$bp/meta.json" ]] || continue
  compose="$bp/docker-compose.yml"

  # Dokploy template rules
  grep -qE '^\s+ports:' "$compose" && fail "$id: compose uses ports: (use expose:)"
  grep -q 'container_name' "$compose" && fail "$id: compose uses container_name"
  grep -qE '^networks:' "$compose" && fail "$id: compose declares custom networks"
  grep -q '@@' "$compose" && fail "$id: compose has unrendered @@placeholders@@"

  # Compose defaults match the Product definition
  grep -q ":-ghcr.io/[a-z0-9-]*/$id}:\${IMAGE_TAG:-$IMAGE_TAG}" "$compose" \
    || fail "$id: compose default image is not ghcr.io/<owner>/$id:$IMAGE_TAG"
  grep -q "INSTALL_APPS:-$INSTALL_APPS}" "$compose" \
    || fail "$id: compose default INSTALL_APPS is not '$INSTALL_APPS'"

  # meta.json consistency
  is_json "$bp/meta.json" || fail "$id: $bp/meta.json is not valid JSON"
  grep -q "\"id\": \"$id\"" "$bp/meta.json" || fail "$id: meta.json id is not '$id'"
  grep -q "\"version\": \"$IMAGE_TAG\"" "$bp/meta.json" || fail "$id: meta.json version is not '$IMAGE_TAG'"
  logo=$(sed -n 's/.*"logo": "\([^"]*\)".*/\1/p' "$bp/meta.json")
  [[ -n "$logo" && -f "$bp/$logo" ]] || fail "$id: meta.json logo '$logo' not found in $bp"

  # template.toml routes the domain to the frontend
  if [[ -f "$bp/template.toml" ]]; then
    grep -q 'serviceName = "frontend"' "$bp/template.toml" || fail "$id: template.toml domain not on frontend"
    grep -q 'port = 8080' "$bp/template.toml" || fail "$id: template.toml domain port is not 8080"
  fi

  # Root meta.json (Dokploy custom Base URL index) lists this blueprint
  grep -q "\"id\": \"$id\"" meta.json 2>/dev/null || fail "$id: not listed in root meta.json"
done

is_json_array meta.json || fail "root meta.json is missing or not a JSON array"

# No stray blueprints without a Product definition
for dir in blueprints/*/; do
  id=$(basename "$dir")
  [[ -d "images/$id" ]] || fail "blueprints/$id has no images/$id Product definition"
done

if ((failures)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All checks passed for ${#products[@]} products"
