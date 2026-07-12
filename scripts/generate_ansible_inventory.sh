#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
umask 077
tmp_group_vars=""
trap '[[ -n "$tmp_group_vars" && -f "$tmp_group_vars" ]] && rm -f "$tmp_group_vars"' EXIT

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

expand_path() {
  case "$1" in
    "~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

require_output() {
  local name="$1"
  terraform -chdir=terraform output -raw "$name"
}

require_non_empty() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    printf '[ERROR] No se pudo obtener %s desde Terraform outputs.\n' "$name" >&2
    exit 1
  fi
}

VM_IP="$(require_output vm_public_ip)"
VM_USER="$(require_output vm_admin_username)"
ACR_LOGIN_SERVER="$(require_output acr_login_server)"
ACR_USER="$(require_output acr_admin_username)"
ACR_PASS="$(require_output acr_admin_password)"
SSH_KEY="$(expand_path "$(tfvar_value ssh_private_key_path)")"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

require_non_empty "vm_public_ip" "$VM_IP"
require_non_empty "vm_admin_username" "$VM_USER"
require_non_empty "acr_login_server" "$ACR_LOGIN_SERVER"
require_non_empty "acr_admin_username" "$ACR_USER"
require_non_empty "acr_admin_password" "$ACR_PASS"

if [[ "$SSH_KEY" == *"/~/"* ]]; then
  printf '[ERROR] La ruta SSH contiene /~/: %s\n' "$SSH_KEY" >&2
  printf '[ERROR] Usa una ruta tipo ~/.ssh/id_ed25519 o %s/.ssh/id_ed25519.\n' "$HOME" >&2
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  printf '[ERROR] No existe la clave privada SSH esperada: %s\n' "$SSH_KEY" >&2
  exit 1
fi

mkdir -p ansible/group_vars

sed \
  -e "s|__VM_PUBLIC_IP__|$VM_IP|g" \
  -e "s|__VM_ADMIN_USERNAME__|$VM_USER|g" \
  -e "s|__SSH_PRIVATE_KEY_PATH__|$SSH_KEY|g" \
  ansible/templates/hosts.j2 > ansible/hosts.ini

chmod 0644 ansible/hosts.ini

tmp_group_vars="$(mktemp ansible/group_vars/all.yml.XXXXXX)"
cat > "$tmp_group_vars" <<EOF
acr_login_server: "$ACR_LOGIN_SERVER"
acr_admin_username: "$ACR_USER"
acr_admin_password: "$ACR_PASS"
podman_image: "podman-web"
podman_image_tag: "casopractico2"
podman_container_name: "cp2-web"
podman_service_name: "container-cp2-web.service"
web_basic_auth_user: "alumno"
web_basic_auth_password: "unir2026"

aks_image_name: "aks-counter"
aks_image_tag: "casopractico2"
aks_app_name: "aks-counter"
aks_namespace: "cp2"
aks_pvc_name: "aks-counter-pvc"
aks_service_name: "aks-counter-svc"
EOF

mv "$tmp_group_vars" ansible/group_vars/all.yml
tmp_group_vars=""
chmod 0600 ansible/group_vars/all.yml

printf '[OK] Generados ansible/hosts.ini y ansible/group_vars/all.yml\n'
