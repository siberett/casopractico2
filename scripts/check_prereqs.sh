#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

errors=0
strict_ssh_cidr="${STRICT_SSH_CIDR_CHECK:-false}"

ok() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  errors=$((errors + 1))
}

need_command() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "Comando disponible: $1"
  else
    fail "Falta el comando '$1'. Instálalo antes de continuar."
  fi
}

expand_path() {
  case "$1" in
    "~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

tfvar_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      gsub(/[[:space:]]/, "", $2)
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' terraform/terraform.tfvars 2>/dev/null || true
}

if [[ ! -d terraform || ! -d ansible || ! -d images || ! -d scripts ]]; then
  fail "Ejecuta este script desde la raíz del repositorio."
else
  ok "Ejecutándose desde la raíz del repositorio."
fi

for cmd in git az terraform ansible-playbook ansible-galaxy kubectl python3; do
  need_command "$cmd"
done

if command -v curl >/dev/null 2>&1; then
  ok "Comando disponible: curl"
else
  warn "Falta curl. No se podrá comprobar automáticamente la IP pública actual."
fi

if az account show >/dev/null 2>&1; then
  ok "Azure CLI autenticado."
else
  fail "Azure CLI no está autenticado. Ejecuta: az login"
fi

if [[ -f terraform/terraform.tfvars ]]; then
  ok "Existe terraform/terraform.tfvars."
else
  fail "No existe terraform/terraform.tfvars. Crea uno desde terraform/terraform.tfvars.example."
fi

allowed_ssh_cidr="$(tfvar_value allowed_ssh_cidr)"
if [[ -n "$allowed_ssh_cidr" ]]; then
  ok "allowed_ssh_cidr configurado: $allowed_ssh_cidr"
else
  warn "No se pudo leer allowed_ssh_cidr desde terraform/terraform.tfvars."
fi

if command -v curl >/dev/null 2>&1; then
  current_public_ip="$(curl -4 -s --max-time 10 ifconfig.me || true)"
  if [[ -z "$current_public_ip" ]]; then
    current_public_ip="$(curl -4 -s --max-time 10 https://api.ipify.org || true)"
  fi
  if [[ -n "$current_public_ip" ]]; then
    ok "IP pública IPv4 actual detectada: $current_public_ip"
    expected_ssh_cidr="${current_public_ip}/32"
    if [[ -n "$allowed_ssh_cidr" && "$allowed_ssh_cidr" != "$expected_ssh_cidr" ]]; then
      if [[ "$strict_ssh_cidr" == "true" ]]; then
        fail "La IP pública actual no coincide con allowed_ssh_cidr."
        printf '[ERROR] IP pública actual: %s\n' "$current_public_ip" >&2
        printf '[ERROR] Valor esperado: allowed_ssh_cidr = "%s"\n' "$expected_ssh_cidr" >&2
        printf '[ERROR] Valor actual: allowed_ssh_cidr = "%s"\n' "$allowed_ssh_cidr" >&2
        printf '[ERROR] Corrige terraform/terraform.tfvars y ejecuta: terraform -chdir=terraform apply\n' >&2
      else
        warn "La IP pública actual no coincide con allowed_ssh_cidr."
        warn "Actualiza terraform/terraform.tfvars con: allowed_ssh_cidr = \"$expected_ssh_cidr\""
        warn "Después ejecuta: terraform -chdir=terraform apply"
      fi
    fi
  else
    warn "No se pudo obtener la IP pública IPv4 actual con curl -4 -s ifconfig.me."
  fi
fi

ssh_private_key_path="$(tfvar_value ssh_private_key_path)"
ssh_public_key_path="$(tfvar_value ssh_public_key_path)"
ssh_private_key_path="${ssh_private_key_path:-~/.ssh/id_ed25519}"
ssh_public_key_path="${ssh_public_key_path:-~/.ssh/id_ed25519.pub}"
ssh_private_key_path="$(expand_path "$ssh_private_key_path")"
ssh_public_key_path="$(expand_path "$ssh_public_key_path")"

if [[ -f "$ssh_private_key_path" ]]; then
  ok "Existe clave privada SSH: $ssh_private_key_path"
else
  fail "No existe la clave privada SSH esperada: $ssh_private_key_path"
fi

if [[ -f "$ssh_public_key_path" ]]; then
  ok "Existe clave pública SSH: $ssh_public_key_path"
else
  fail "No existe la clave pública SSH esperada: $ssh_public_key_path"
fi

if terraform -chdir=terraform validate >/dev/null 2>&1; then
  ok "terraform validate correcto."
else
  warn "terraform validate no se pudo completar. Ejecuta: terraform -chdir=terraform init -upgrade && terraform -chdir=terraform validate"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "Repositorio Git detectado."
  git status --ignored --short
else
  warn "Esta carpeta no parece ser un repositorio Git inicializado."
fi

if [[ "$errors" -gt 0 ]]; then
  printf '\nRequisitos fallidos: %s\n' "$errors" >&2
  exit 1
fi

printf '\nTodos los requisitos críticos están cubiertos.\n'
