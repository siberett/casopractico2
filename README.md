# Caso Practico 2: Automatizacion de despliegues en Azure

Repositorio para desplegar de forma automatizada una practica con Terraform, Azure Container Registry, una VM Linux con Podman y un cluster AKS con almacenamiento persistente.

## Estructura usada para el despliegue

```text
terraform/   Infraestructura Azure
ansible/     Configuracion de VM, Podman y Kubernetes
images/      Imagenes de las dos aplicaciones
scripts/     Scripts de despliegue, validacion y destruccion
```

La documentacion auxiliar, prompts, harness y entregables locales no forman parte del commit de despliegue.

## Requisitos previos

La maquina de control necesita:

- Azure CLI
- Terraform
- Ansible
- kubectl
- Python 3
- Git

Antes de desplegar hay que iniciar sesion en Azure:

```bash
az login
az account show
```

Tambien hay que crear el fichero local de variables:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Ese fichero debe completarse con la suscripcion, region, nombre unico de ACR, rutas de claves SSH, CIDR permitido para SSH y tamanos de VM/AKS.

No hace falta tener Podman local funcionando para construir las imagenes. El script usa build remoto con Azure Container Registry. Podman se instala automaticamente dentro de la VM mediante Ansible.

## Despliegue

El despliegue completo se ejecuta desde la raiz:

```bash
./scripts/check_prereqs.sh
./scripts/deploy.sh
```

El script `scripts/deploy.sh` ejecuta el flujo completo:

1. Comprueba requisitos.
2. Registra providers de Azure.
3. Ejecuta Terraform.
4. Construye las imagenes en ACR con tag `casopractico2`.
5. Genera inventario y variables locales de Ansible.
6. Configura la VM Linux con Podman.
7. Obtiene credenciales de AKS.
8. Despliega la aplicacion Kubernetes.
9. Ejecuta validaciones finales.

## Aplicaciones

Imagen para la VM con Podman:

```text
podman-web:casopractico2
```

Es una web Nginx con HTTPS, certificado autofirmado y Basic Auth. El servicio systemd que la gestiona es:

```text
container-cp2-web.service
```

Imagen para AKS:

```text
aks-counter:casopractico2
```

Es una aplicacion Python distinta que incrementa un contador y lo guarda en `/data/counter.txt` usando un PVC de AKS con `managed-csi`.

## Validacion

Validacion general:

```bash
./scripts/validate.sh
```

Validacion de persistencia, que borra un pod de forma controlada:

```bash
./scripts/validate.sh --with-persistence-test
```

## Destruccion

Para eliminar los recursos de Azure:

```bash
./scripts/destroy.sh
```

Tambien se puede ejecutar el wrapper equivalente:

```bash
./ansible/destroy.sh
```

## Archivos locales que no se suben

Estos archivos pueden existir localmente, pero estan ignorados porque contienen estado, credenciales o datos generados:

```text
terraform/terraform.tfvars
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/.terraform/
terraform/tfplan
ansible/hosts.ini
ansible/group_vars/all.yml
.venv/
kubeconfig
```

No deben borrarse durante el desarrollo solo por no subirse a Git. Se conservan localmente para poder repetir despliegues, validaciones o destruccion.
