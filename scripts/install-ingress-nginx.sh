#!/usr/bin/env bash

# Instala ou atualiza o controller oficial ingress-nginx no EKS.
# Uso: ./scripts/install-ingress-nginx.sh

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="${script_dir}/.."
readonly namespace="ingress-nginx"
readonly release="ingress-nginx"
readonly chart="ingress-nginx/ingress-nginx"
readonly values_file="${project_root}/k8s/ingress-nginx-values.yaml"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Erro: o comando '$1' não está instalado ou não está no PATH." >&2
    exit 1
  }
}

require_command helm
require_command kubectl

[[ -f "$values_file" ]] || {
  echo "Erro: arquivo de valores não encontrado: $values_file" >&2
  exit 1
}

kubectl cluster-info >/dev/null

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo update ingress-nginx

helm upgrade --install "$release" "$chart" \
  --namespace "$namespace" \
  --create-namespace \
  --values "$values_file" \
  --wait \
  --timeout 10m

echo
echo "Aguardando o LoadBalancer receber um hostname externo..."
for attempt in {1..30}; do
  endpoint="$(kubectl get service -n "$namespace" "${release}-controller" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{.status.loadBalancer.ingress[0].ip}' \
    2>/dev/null || true)"

  if [[ -n "$endpoint" ]]; then
    echo "Ingress disponível em: $endpoint"
    exit 0
  fi

  printf 'Tentativa %d/30: ainda pendente...\n' "$attempt"
  sleep 20
done

echo "O controller foi instalado, mas o LoadBalancer não recebeu endpoint em 10 minutos." >&2
echo "Verifique: kubectl describe service -n ${namespace} ${release}-controller" >&2
exit 1
