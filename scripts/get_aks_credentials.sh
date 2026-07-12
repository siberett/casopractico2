#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RESOURCE_GROUP="$(terraform -chdir=terraform output -raw aks_resource_group)"
AKS_NAME="$(terraform -chdir=terraform output -raw aks_name)"

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --overwrite-existing
