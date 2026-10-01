#!/usr/bin/env bash
# Render every Blueprint's docker-compose.yml and template.toml from templates/,
# using each Product definition in images/<id>/image.env, and rebuild the root
# meta.json index that Dokploy reads from a custom template Base URL.
#
# Usage: scripts/render.sh           -> write files
#        scripts/render.sh --check   -> fail if any committed file is stale
#        IMAGE_OWNER=<ghcr-owner> scripts/render.sh  (default: riyadmunauwar)
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE_OWNER=${IMAGE_OWNER:-riyadmunauwar}
mode=${1:-write}
stale=0

emit() { # emit <target> : read content from stdin, write or compare
  local target=$1 content
  content=$(cat)
  if [[ $mode == --check ]]; then
    if [[ ! -f $target ]] || [[ "$(cat "$target")" != "$content" ]]; then
      echo "STALE: $target"; stale=1
    fi
  else
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$content" > "$target"
  fi
}

render() { # render <template> <id>
  sed -e "s|@@HEADER@@|Generated from $1 by scripts/render.sh for $2. Do not edit by hand.|" \
      -e "s|@@IMAGE_NAME@@|ghcr.io/$IMAGE_OWNER/$2|g" \
      -e "s|@@IMAGE_TAG@@|$IMAGE_TAG|g" \
      -e "s|@@INSTALL_APPS@@|$INSTALL_APPS|g" \
      "$1"
}

ids=()
for dir in images/*/; do
  id=$(basename "$dir")
  ids+=("$id")
  IMAGE_TAG="" INSTALL_APPS=""
  # shellcheck disable=SC1090
  source "images/$id/image.env"
  emit "blueprints/$id/docker-compose.yml" < <(render templates/docker-compose.yml "$id")
  emit "blueprints/$id/template.toml" < <(render templates/template.toml "$id")
done

emit meta.json < <(
  echo "["
  for i in "${!ids[@]}"; do
    sed 's/^/  /' "blueprints/${ids[$i]}/meta.json" | sed '$s/$/'"$([[ $i -lt $((${#ids[@]} - 1)) ]] && echo ,)"'/'
  done
  echo "]"
)

if [[ $mode == --check ]]; then
  ((stale)) && { echo "Run scripts/render.sh and commit the result."; exit 1; }
  echo "All rendered files are up to date"
fi
