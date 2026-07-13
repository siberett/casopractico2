#!/usr/bin/env bash
set -Eeuo pipefail

# Script principal de la practica.
# Ejecuta todo el despliegue desde la raiz del repositorio:
# comprobaciones, Terraform, build de imagenes, Ansible y validaciones.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Lee valores sencillos del fichero terraform.tfvars.
# Se usa para recuperar rutas locales, como la clave privada SSH.
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

# Expande rutas que empiezan por ~/ para evitar errores de ruta en Ansible o SSH.
expand_path() {
  case "$1" in
    "~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Espera a que la VM acepte conexiones SSH antes de lanzar Ansible.
# Esto evita que el playbook falle si Azure acaba de crear la maquina.
wait_for_ssh() {
  local vm_ip="$1"
  local vm_user="$2"
  local ssh_key="$3"
  local max_attempts=18
  local sleep_seconds=10
  local attempt
  local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

  if [[ -n "$ssh_key" && -f "$ssh_key" ]]; then
    ssh_opts+=(-i "$ssh_key")
  fi

  printf '[INFO] Esperando SSH en %s@%s\n' "$vm_user" "$vm_ip"
  for attempt in $(seq 1 "$max_attempts"); do
    if ssh "${ssh_opts[@]}" "$vm_user@$vm_ip" 'true' >/dev/null 2>&1; then
      printf '[OK] SSH disponible en intento %s/%s\n' "$attempt" "$max_attempts"
      return 0
    fi
    printf '[WARN] SSH no disponible todavía en intento %s/%s. Esperando %ss...\n' "$attempt" "$max_attempts" "$sleep_seconds"
    sleep "$sleep_seconds"
  done

  cat >&2 <<EOF
[ERROR] La VM no acepta SSH después de varios intentos.

Comprueba:
- allowed_ssh_cidr en terraform/terraform.tfvars.
- Que tu IP pública actual coincide con allowed_ssh_cidr:
  curl ifconfig.me
- Que el NSG permite TCP 22 desde tu IP.
- Conexión manual:
  ssh ${vm_user}@$(terraform -chdir=terraform output -raw vm_public_ip)

Si tu IP pública cambió:
1. Edita terraform/terraform.tfvars.
2. Configura: allowed_ssh_cidr = "IP_ACTUAL/32"
3. Ejecuta: terraform -chdir=terraform apply
4. Relanza: ./scripts/deploy.sh
EOF
  return 1
}

# 1. Comprobacion inicial del entorno local.
printf '[INFO] Comprobando prerrequisitos\n'
STRICT_SSH_CIDR_CHECK=true "$ROOT_DIR/scripts/check_prereqs.sh"

# 2. Registro de providers necesarios en Azure.
printf '[INFO] Registrando providers de Azure\n'
"$ROOT_DIR/scripts/register_providers.sh"

# 3. Creacion de infraestructura con Terraform.
printf '[INFO] Ejecutando Terraform\n'
terraform -chdir=terraform init
terraform -chdir=terraform fmt
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan

# 4. Construccion de imagenes y subida al ACR.
printf '[INFO] Construyendo y subiendo imágenes\n'
"$ROOT_DIR/scripts/build_and_push_images.sh"

# 5. Configuracion de kubectl para poder trabajar contra AKS.
printf '[INFO] Configurando kubeconfig de AKS\n'
"$ROOT_DIR/scripts/get_aks_credentials.sh"

# 6. Entorno Python local para ejecutar Ansible con modulos Kubernetes.
printf '[INFO] Preparando entorno Python local\n'
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install ansible kubernetes

# 7. Colecciones Ansible necesarias para Podman y Kubernetes.
printf '[INFO] Instalando colecciones Ansible\n'
ansible-galaxy collection install -r ansible/requirements.yml

# 8. Inventario y variables locales generadas desde outputs de Terraform.
printf '[INFO] Generando inventario y variables Ansible\n'
"$ROOT_DIR/scripts/generate_ansible_inventory.sh"

# 9. Lectura de datos de conexion a la VM y espera de SSH.
VM_IP="$(terraform -chdir=terraform output -raw vm_public_ip)"
VM_USER="$(terraform -chdir=terraform output -raw vm_admin_username)"
SSH_KEY="$(awk -F= '/ansible_ssh_private_key_file=/ {print $NF; exit}' ansible/hosts.ini 2>/dev/null || true)"
if [[ -z "$SSH_KEY" ]]; then
  SSH_KEY="$(tfvar_value ssh_private_key_path)"
fi
SSH_KEY="$(expand_path "${SSH_KEY:-}")"
wait_for_ssh "$VM_IP" "$VM_USER" "$SSH_KEY"

# 10. Configuracion de la VM: instala Podman y levanta la web.
printf '[INFO] Ejecutando Ansible para VM + Podman\n'
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/hosts.ini ansible/playbook_podman.yml

# 11. Despliegue de la aplicacion persistente en AKS.
printf '[INFO] Ejecutando Ansible para AKS\n'
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/hosts.ini ansible/playbook_k8s.yml

# 12. Validaciones finales de ACR, VM, Podman, AKS y aplicaciones.
printf '[INFO] Ejecutando validaciones finales\n'
"$ROOT_DIR/scripts/validate.sh"

# 13. Resumen final con datos utiles para probar el entorno.
SSH_COMMAND="$(terraform -chdir=terraform output -raw ssh_connection_command)"
ACR="$(terraform -chdir=terraform output -raw acr_login_server)"
AKS_NAME="$(terraform -chdir=terraform output -raw aks_name)"
LB_IP="$(kubectl -n cp2 get svc aks-counter-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

cat <<EOF

Despliegue completado.

Outputs:
- VM public IP: $VM_IP
- SSH: $SSH_COMMAND
- ACR: $ACR
- AKS: $AKS_NAME
- AKS LoadBalancer IP: ${LB_IP:-pendiente}

Validación:
./scripts/validate.sh
EOF
