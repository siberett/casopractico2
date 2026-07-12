# Imagen Podman Web

Imagen web autocontenida para la aplicación que se ejecutará en la VM con Podman.

Incluye:

- Nginx escuchando en HTTPS por el puerto `443`.
- Página HTML propia para el Caso Práctico 2.
- Certificado x.509 autofirmado generado durante el build.
- Autenticación básica con credenciales demo.

Credenciales demo:

- Usuario: `alumno`
- Password: `unir2026`

## Build y push al ACR

El flujo principal del repositorio no necesita construir esta imagen con Podman local. El script usa build remoto en Azure Container Registry:

```bash
./scripts/build_and_push_images.sh
```

Valida el repositorio y el tag en ACR:

```bash
az acr repository list --name "${ACR%%.*}" -o table
az acr repository show-tags --name "${ACR%%.*}" --repository podman-web -o table
```

## Prueba local

La prueba local con Podman es opcional. Si se quiere ejecutar, hace falta tener Podman funcionando en la máquina local:

```bash
podman run --rm -p 8443:443 $ACR/podman-web:casopractico2
```

Valida la autenticación:

```bash
curl -k https://localhost:8443
curl -k -u alumno:unir2026 https://localhost:8443
```

Resultado esperado:

- Sin credenciales: `401`.
- Con credenciales: `200`.
