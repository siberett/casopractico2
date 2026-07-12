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

## Validacion

La validacion principal se realiza despues del despliegue con:

```bash
./scripts/validate.sh
```
