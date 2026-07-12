# AKS Counter

Aplicación web HTTP propia para el bloque AKS del Caso Práctico 2.

La app incrementa un contador en cada petición a `/` y guarda el estado en:

```text
/data/counter.txt
```

Ese path está preparado para montarse después desde un PVC de Kubernetes. Si el archivo no existe, la aplicación inicializa el contador automáticamente.

## Características

- App distinta de `podman-web`.
- Imagen: `aks-counter`.
- Tag obligatorio: `casopractico2`.
- Puerto HTTP: `8080`.
- Bind: `0.0.0.0:8080`.
- Persistencia: `/data/counter.txt`.
- Sin secretos.
- Sin dependencias Python externas.

La página HTML muestra:

- `Caso Practico 2`.
- `App AKS Counter`.
- Imagen `aks-counter`.
- Tag `casopractico2`.
- Valor actual del contador.
- Ruta de persistencia `/data/counter.txt`.

## Build y push

El flujo principal construye la imagen directamente en Azure Container Registry, por lo que no depende de Podman local:

```bash
./scripts/build_and_push_images.sh
```

No usar el tag `latest` para la entrega.

## Prueba local opcional

```bash
podman run --rm -p 8080:8080 aks-counter:casopractico2
```

En otra terminal:

```bash
curl http://localhost:8080/
curl http://localhost:8080/healthz
```

El contador aumenta en cada petición a `/`.

## Validacion en ACR

```bash
ACR=$(terraform -chdir=terraform output -raw acr_login_server)
az acr repository list --name "${ACR%%.*}" -o table
az acr repository show-tags --name "${ACR%%.*}" --repository aks-counter -o table
```

Resultado esperado:

- El login al ACR funciona.
- El build termina correctamente.
- El push termina correctamente.
- `az acr repository list` muestra `aks-counter`.
- `az acr repository show-tags` muestra `casopractico2`.

Notas:

- No usar `latest`.
- Usar siempre el tag `casopractico2`.
- Usar `--platform=linux/amd64`, especialmente en Mac Apple Silicon.
- No copiar el valor real de `acr_admin_password` en documentación.
- La imagen `aks-counter` es distinta de `podman-web`.
