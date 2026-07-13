#!/usr/bin/env bash
set -Eeuo pipefail

# Configura kubectl para conectarse al AKS creado por Terraform.
# Los nombres salen de outputs, asi no se copian a mano.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Nombre del Resource Group y del cluster AKS.
RESOURCE_GROUP="$(terraform -chdir=terraform output -raw aks_resource_group)"
AKS_NAME="$(terraform -chdir=terraform output -raw aks_name)"

# Descarga o actualiza las credenciales locales de kubectl.
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing
