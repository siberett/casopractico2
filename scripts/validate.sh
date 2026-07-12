#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WITH_PERSISTENCE_TEST=false
if [[ "${1:-}" == "--with-persistence-test" ]]; then
  WITH_PERSISTENCE_TEST=true
elif [[ "${1:-}" != "" ]]; then
  printf 'Uso: %s [--with-persistence-test]\n' "$0" >&2
  exit 1
fi

ok() {
  printf '[OK] %s\n' "$1"
}

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

http_code() {
  curl -k -o /dev/null -s -w '%{http_code}' "$@"
}

extract_counter() {
  sed -n 's/.*<div class="counter">\([0-9][0-9]*\)<\/div>.*/\1/p'
}

ACR="$(terraform -chdir=terraform output -raw acr_login_server)"
ACR_NAME="${ACR%%.*}"
TAG="casopractico2"
AKS_NAMESPACE="${AKS_NAMESPACE:-cp2}"

for repo in podman-web aks-counter; do
  if az acr repository show-tags --name "$ACR_NAME" --repository "$repo" -o tsv | grep -Fxq "$TAG"; then
    ok "ACR contiene $repo:$TAG"
  else
    fail "ACR no contiene $repo:$TAG"
  fi
done

VM_IP="$(terraform -chdir=terraform output -raw vm_public_ip)"
code_without_auth="$(http_code "https://$VM_IP/")"
[[ "$code_without_auth" == "401" ]] || fail "Podman web sin credenciales devolvió $code_without_auth, esperado 401"
ok "Podman web devuelve 401 sin credenciales"

code_with_auth="$(http_code -u alumno:unir2026 "https://$VM_IP/")"
[[ "$code_with_auth" == "200" ]] || fail "Podman web con credenciales devolvió $code_with_auth, esperado 200"
ok "Podman web devuelve 200 con alumno:unir2026"

VM_USER="$(terraform -chdir=terraform output -raw vm_admin_username)"
SSH_KEY="$(awk -F= '/ansible_ssh_private_key_file=/ {print $NF; exit}' ansible/hosts.ini 2>/dev/null || true)"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY")
fi

systemd_enabled="$(ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" 'systemctl is-enabled container-cp2-web.service')"
[[ "$systemd_enabled" == "enabled" ]] || fail "systemd no está enabled: $systemd_enabled"
ok "Servicio systemd enabled"

systemd_active="$(ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" 'systemctl is-active container-cp2-web.service')"
[[ "$systemd_active" == "active" ]] || fail "systemd no está active: $systemd_active"
ok "Servicio systemd active"

kubectl get nodes >/dev/null
kubectl get nodes --no-headers | awk '{print $2}' | grep -q 'Ready' || fail "No hay nodos AKS Ready"
ok "AKS tiene nodo Ready"

kubectl get storageclass managed-csi >/dev/null
ok "StorageClass managed-csi disponible"

pvc_phase="$(kubectl -n "$AKS_NAMESPACE" get pvc aks-counter-pvc -o jsonpath='{.status.phase}')"
[[ "$pvc_phase" == "Bound" ]] || fail "PVC aks-counter-pvc está $pvc_phase, esperado Bound"
ok "PVC aks-counter-pvc Bound"

available_replicas="$(kubectl -n "$AKS_NAMESPACE" get deploy aks-counter -o jsonpath='{.status.availableReplicas}')"
[[ "${available_replicas:-0}" -ge 1 ]] || fail "Deployment aks-counter sin réplicas disponibles"
ok "Deployment aks-counter disponible"

kubectl -n "$AKS_NAMESPACE" get pods -l app=aks-counter --no-headers | awk '{print $3}' | grep -q 'Running' || fail "No hay pod aks-counter Running"
ok "Pod aks-counter Running"

LB_IP="$(kubectl -n "$AKS_NAMESPACE" get svc aks-counter-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
[[ -n "$LB_IP" ]] || fail "Service aks-counter-svc sin EXTERNAL-IP"
ok "Service aks-counter-svc con EXTERNAL-IP $LB_IP"

aks_code="$(curl -o /dev/null -s -w '%{http_code}' "http://$LB_IP/")"
[[ "$aks_code" == "200" ]] || fail "aks-counter devolvió $aks_code, esperado 200"
ok "aks-counter responde por HTTP"

if [[ "$WITH_PERSISTENCE_TEST" == "true" ]]; then
  before_html="$(curl -s "http://$LB_IP/")"
  before_counter="$(printf '%s\n' "$before_html" | extract_counter)"
  [[ -n "$before_counter" ]] || fail "No se pudo extraer contador antes de borrar pod"

  pod_name="$(kubectl -n "$AKS_NAMESPACE" get pods -l app=aks-counter -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "$pod_name" ]] || fail "No se pudo obtener pod aks-counter"
  kubectl -n "$AKS_NAMESPACE" delete pod "$pod_name"
  kubectl -n "$AKS_NAMESPACE" wait --for=condition=Ready pod -l app=aks-counter --timeout=180s

  after_html="$(curl -s "http://$LB_IP/")"
  after_counter="$(printf '%s\n' "$after_html" | extract_counter)"
  [[ -n "$after_counter" ]] || fail "No se pudo extraer contador después de recrear pod"
  [[ "$after_counter" -ge "$before_counter" ]] || fail "Contador bajó de $before_counter a $after_counter"
  ok "Persistencia validada: contador antes=$before_counter después=$after_counter"
else
  cat <<EOF
[INFO] Prueba de persistencia no ejecutada porque borra un pod.
[INFO] Para ejecutarla: ./scripts/validate.sh --with-persistence-test
EOF
fi

printf '\nValidación completada.\n'
