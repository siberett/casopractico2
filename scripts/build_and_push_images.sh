#!/usr/bin/env bash
set -Eeuo pipefail

# Construye las imagenes de la practica directamente en Azure Container Registry.
# Se usa az acr build para no depender de Podman local en macOS.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Valida que existan los ficheros necesarios antes de llamar a Azure.
require_file() {
  if [[ ! -e "$1" ]]; then
    printf '[ERROR] Falta %s\n' "$1" >&2
    exit 1
  fi
}

require_file terraform/terraform.tfvars
require_file images/podman-web/Containerfile
require_file images/aks-counter/Containerfile

# El login server del ACR sale de Terraform para evitar copiar nombres a mano.
ACR="$(terraform -chdir=terraform output -raw acr_login_server)"
ACR_NAME="${ACR%%.*}"
TAG="casopractico2"

printf '[INFO] Build remoto en ACR: %s\n' "$ACR"
# Imagen de la aplicacion web que se ejecuta en la VM con Podman.
az acr build \
  --registry "$ACR_NAME" \
  --image "podman-web:$TAG" \
  --platform linux/amd64 \
  --file images/podman-web/Containerfile \
  images/podman-web

# Imagen de la aplicacion persistente que se ejecuta en AKS.
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
