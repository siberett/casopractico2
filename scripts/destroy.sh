#!/usr/bin/env bash
set -Eeuo pipefail

# Destruye los recursos creados por la practica.
# Pide confirmacion para evitar borrar el entorno por error.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Lee valores simples de terraform.tfvars, como el Resource Group.
tfvar_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      gsub(/^"/, "", $2)
      gsub(/"$/, "", $2)
      print $2
      exit
    }
  ' terraform/terraform.tfvars 2>/dev/null || true
}

# Permite ejecucion no interactiva solo si se pasa --auto-approve.
AUTO_APPROVE=false
if [[ "${1:-}" == "--auto-approve" ]]; then
  AUTO_APPROVE=true
elif [[ "${1:-}" != "" ]]; then
  printf 'Uso: %s [--auto-approve]\n' "$0" >&2
  exit 1
fi

# Mensaje claro antes de borrar recursos con coste.
cat <<'EOF'
ATENCION: este script destruirá los recursos Azure gestionados por Terraform.

Se eliminarán, entre otros:
- VM
- AKS
- ACR
- red, IP pública y discos gestionados por el despliegue

No se borran claves SSH locales ni .venv.
EOF

# Confirmacion manual para evitar destrucciones accidentales.
if [[ "$AUTO_APPROVE" != "true" ]]; then
  read -r -p "Escribe 'yes' para continuar: " answer
  if [[ "$answer" != "yes" ]]; then
    printf 'Destrucción cancelada.\n'
    exit 0
  fi
fi

# Limpieza previa de Kubernetes. Es best-effort porque terraform destroy tambien
# eliminara el cluster y no debe fallar si kubectl ya no conecta.
printf '[INFO] Limpieza Kubernetes best-effort\n'
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl -n cp2 delete service aks-counter-svc --ignore-not-found=true || true
  kubectl -n cp2 delete deployment aks-counter --ignore-not-found=true || true
  kubectl -n cp2 delete pvc aks-counter-pvc --ignore-not-found=true || true
  kubectl delete namespace cp2 --ignore-not-found=true || true
else
  printf '[WARN] kubectl no conecta con un clúster. Se omite limpieza Kubernetes.\n'
fi

# Destruccion real de la infraestructura gestionada por Terraform.
printf '[INFO] Ejecutando terraform destroy\n'
if [[ "$AUTO_APPROVE" == "true" ]]; then
  terraform -chdir=terraform destroy -auto-approve
else
  terraform -chdir=terraform destroy
fi

# Limpieza de ficheros locales generados durante el despliegue.
printf '[INFO] Limpiando archivos generados locales\n'
rm -f ansible/hosts.ini ansible/group_vars/all.yml kubeconfig

# Comandos de comprobacion para verificar que no quedan recursos con coste.
RESOURCE_GROUP_NAME="$(tfvar_value resource_group_name)"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-casopractico2}"

cat <<EOF

Destrucción solicitada.

Comprueba que no quedan recursos con coste:
az group show --name $RESOURCE_GROUP_NAME --output table
az resource list --resource-group $RESOURCE_GROUP_NAME --output table
az aks list --output table
az vm list --output table
az acr list --output table
EOF
