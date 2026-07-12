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

En macOS, inicializa y arranca la máquina de Podman antes de usar `podman build`, `podman run` o `podman push`:

```bash
podman machine init
podman machine start
podman info
```

Obtén el login server del ACR desde Terraform:

```bash
ACR=$(terraform -chdir=terraform output -raw acr_login_server)
```

Autentícate en el ACR:

```bash
podman login "$ACR" \
  -u "$(terraform -chdir=terraform output -raw acr_admin_username)" \
  -p "$(terraform -chdir=terraform output -raw acr_admin_password)"
```

Construye la imagen para `linux/amd64`:

```bash
podman build --platform=linux/amd64 -t $ACR/podman-web:casopractico2 images/podman-web
```

Sube la imagen al ACR:

```bash
podman push $ACR/podman-web:casopractico2
```

Valida el repositorio y el tag en ACR:

```bash
az acr repository list --name "${ACR%%.*}" -o table
az acr repository show-tags --name "${ACR%%.*}" --repository podman-web -o table
```

## Prueba local

Ejecuta la imagen publicada:

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
