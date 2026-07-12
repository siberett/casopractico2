# Caso Práctico 2: Automatización de despliegues en entornos Cloud

Repositorio para construir por fases una solución reproducible en Microsoft Azure con Terraform, ACR, Podman, Ansible y AKS.

## 1. Visión General Del Despliegue

El flujo final del proyecto será:

```bash
az login
./scripts/check_prereqs.sh
./scripts/deploy.sh
./scripts/validate.sh
./scripts/destroy.sh
```

En la fase actual, esos pasos todavía se validan manualmente antes de convertirlos en scripts.

Estado actual:

- Terraform crea infraestructura Azure: Resource Group, VNet, subnet, NSG, ACR, IP pública, NIC, VM Linux y definición AKS.
- ACR almacena imágenes privadas.
- Podman se usa localmente para construir y subir la imagen `podman-web`.
- `scripts/generate_ansible_inventory.sh` genera inventario y variables locales para Ansible a partir de outputs Terraform.
- Ansible ya tiene playbook para configurar la VM con Podman.
- AKS queda definido en Terraform con un único worker y rol `AcrPull` sobre el ACR.
- Ansible configurará Kubernetes después, cuando exista la app persistente.
- No se usa Azure Portal para crear recursos manualmente.

Pendiente:

- Aplicar y validar AKS.
- App Kubernetes, PVC y Service `LoadBalancer`.
- Scripts finales.

## 2. Prerrequisitos

La máquina de control debe tener:

- Git.
- Azure CLI.
- Terraform.
- Podman.
- Ansible.
- kubectl para validar AKS después del `terraform apply`.
- Acceso a Internet.
- Cuenta Azure con permisos suficientes.
- Python/pip en fases posteriores.

Comprobación actual:

```bash
git --version
az version
terraform version
podman version
ansible --version
ansible-galaxy --version
kubectl version --client
```

En macOS, si falta Ansible o aparece `zsh: command not found: ansible-galaxy`:

```bash
brew install ansible
ansible --version
ansible-galaxy --version
```

`ansible-galaxy` viene incluido con Ansible. Si `ansible --version` y `ansible-galaxy --version` fallan, no continúes con el playbook hasta instalar Ansible.

Pendiente para fases posteriores:

```bash
python3 --version
pip3 --version
```

En macOS, Podman necesita una máquina Linux interna:

```bash
podman machine init
podman machine start
podman machine list
podman info
```

Si aparece un error similar a `Cannot connect to Podman` o `unable to connect to Podman socket`, arranca la máquina:

```bash
podman machine start
```

## 3. Guía Operativa

La guía paso a paso está en:

- `docs/03_despliegue.md`

Incluye:

- Autenticación Azure.
- Preparación de claves SSH.
- Configuración de `terraform.tfvars`.
- Ejecución de Terraform.
- Build y push de `podman-web:casopractico2`.
- Build y push de `aks-counter:casopractico2`.
- Ejecución de Ansible para VM + Podman.
- Creación de AKS e integración con ACR mediante `AcrPull`.
- Despliegue Kubernetes de `aks-counter` mediante Ansible.
- Validación de VM, SSH e inventario Ansible.
- Validación básica de AKS con `az aks get-credentials` y `kubectl get nodes`.
- Seguridad y archivos no versionables.
- Scripts finales de despliegue, validación y destrucción.

## 4. Validaciones Y Evidencias

- Validaciones actuales: `docs/05_validaciones.md`.
- Destrucción y pausa para evitar costes: `docs/04_destruccion.md`.
- Evidencia de build/push de `podman-web`: `docs/08_evidencias.md`.
- Problemas y soluciones, incluido `Host key verification failed` de Ansible: `docs/07_problemas_y_soluciones.md`.

## 5. Seguridad

No deben subirse a Git:

```text
terraform/terraform.tfvars
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/.terraform/
ansible/hosts.ini
ansible/group_vars/all.yml
*.pem
*.key
id_rsa
id_ed25519
kubeconfig
.env
```

Estos archivos pueden existir localmente y, de hecho, algunos son necesarios para operar el entorno:

- `terraform/terraform.tfvars`: valores reales de despliegue.
- `terraform/terraform.tfstate`: relación entre Terraform y recursos ya creados.
- `terraform/.terraform/`: providers descargados por `terraform init`.
- `ansible/hosts.ini` y `ansible/group_vars/all.yml`: generados para ejecutar Ansible.

No los borres como parte del saneamiento del repositorio. La medida correcta antes del primer commit es comprobar que están ignorados y que no se añaden a Git.

Comprobaciones útiles:

```bash
git status --ignored
git diff
git check-ignore terraform/terraform.tfvars terraform/terraform.tfstate ansible/hosts.ini ansible/group_vars/all.yml
```

`terraform/.terraform.lock.hcl` sí puede versionarse normalmente si se decide fijar versiones de providers.

## 6. Checklist De Estado Actual

- [x] Azure CLI autenticado.
- [x] Terraform instalado.
- [x] ACR creado.
- [x] Outputs ACR disponibles.
- [x] Imagen `podman-web:casopractico2` subida al ACR.
- [x] VM definida con Terraform.
- [x] Playbook Ansible VM + Podman implementado.
- [x] VM aplicada y validada por SSH.
- [x] Ansible ejecutado sobre la VM.
- [x] Podman instalado en VM mediante Ansible.
- [x] Contenedor ejecutado en VM mediante Ansible.
- [x] Validación HTTPS 401/200 ejecutada.
- [x] Servicio systemd activo validado.
- [x] Sesión 2 VM + Podman cerrada.
- [x] AKS definido con Terraform.
- [x] Integración AKS-ACR definida con rol `AcrPull`.
- [x] AKS creado con Terraform.
- [x] kubeconfig configurado con `az aks get-credentials`.
- [x] AKS accesible con `kubectl cluster-info`.
- [x] Nodo AKS validado con `kubectl get nodes -o wide`.
- [x] StorageClass `managed-csi` disponible.
- [x] Rol `AcrPull` asignado al `kubelet_identity`.
- [x] Playbook Ansible Kubernetes implementado.
- [x] Imagen `aks-counter:casopractico2` creada.
- [x] Imagen `aks-counter:casopractico2` subida al ACR.
- [x] App Kubernetes desplegada y validada.
- [x] PVC creado.
- [x] PVC `Bound`.
- [x] Deployment creado.
- [x] Pod `Running`.
- [x] Service `LoadBalancer` creado.
- [x] `EXTERNAL-IP` asignada.
- [x] App accesible por HTTP.
- [x] Persistencia validada borrando pod.
- [x] Scripts finales implementados.
- [ ] Informe PDF.

## 7. Scripts Finales

Flujo automatizado desde la raíz del repositorio:

```bash
./scripts/check_prereqs.sh
./scripts/deploy.sh
./scripts/validate.sh
./scripts/destroy.sh
```

La prueba de persistencia borra un pod de forma controlada y solo se ejecuta bajo demanda:

```bash
./scripts/validate.sh --with-persistence-test
```

Si los scripts no tienen permiso de ejecución tras clonar o copiar el repositorio:

```bash
chmod +x scripts/*.sh
```

Si Ansible falla por timeout SSH hacia la VM, comprueba que tu IP pública actual coincide con `allowed_ssh_cidr`:

```bash
curl -4 ifconfig.me
```

Actualiza `terraform/terraform.tfvars` con `allowed_ssh_cidr = "IP_ACTUAL/32"` y aplica:

```bash
terraform -chdir=terraform apply
```
