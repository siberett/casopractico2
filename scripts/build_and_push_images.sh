#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_file() {
  if [[ ! -e "$1" ]]; then
    printf '[ERROR] Falta %s\n' "$1" >&2
    exit 1
  fi
}

require_file terraform/terraform.tfvars
require_file images/podman-web/Containerfile
require_file images/aks-counter/Containerfile

ACR="$(terraform -chdir=terraform output -raw acr_login_server)"
ACR_NAME="${ACR%%.*}"
TAG="casopractico2"

printf '[INFO] Build remoto en ACR: %s\n' "$ACR"
az acr build \
  --registry "$ACR_NAME" \
  --image "podman-web:$TAG" \
  --platform linux/amd64 \
  --file images/podman-web/Containerfile \
  images/podman-web

az acr build \
  --registry "$ACR_NAME" \
  --image "aks-counter:$TAG" \
  --platform linux/amd64 \
  --file images/aks-counter/Containerfile \
  images/aks-counter

cat <<EOF

Resumen:
- Repositorio podman-web, tag $TAG
- Repositorio aks-counter, tag $TAG
- Build remoto ACR completado correctamente para ambas imágenes.
EOF
