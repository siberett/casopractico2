#!/usr/bin/env bash
set -Eeuo pipefail

providers=(
  Microsoft.ContainerRegistry
  Microsoft.Compute
  Microsoft.Network
  Microsoft.ContainerService
  Microsoft.Authorization
)

for provider in "${providers[@]}"; do
  printf '[INFO] Registrando provider Azure: %s\n' "$provider"
  az provider register --namespace "$provider"
done

printf '[INFO] Esperando estado Registered\n'
for provider in "${providers[@]}"; do
  for attempt in {1..30}; do
    state="$(az provider show --namespace "$provider" --query registrationState -o tsv)"
    if [[ "$state" == "Registered" ]]; then
      printf '[OK] %s: %s\n' "$provider" "$state"
      break
    fi
    printf '[INFO] %s: %s, intento %s/30\n' "$provider" "$state" "$attempt"
    sleep 10
  done

  if [[ "$state" != "Registered" ]]; then
    printf '[ERROR] %s no alcanzó estado Registered.\n' "$provider" >&2
    exit 1
  fi
done
