#!/usr/bin/env bash

# Gera carga de CPU no próprio Pod alvo do evaluation-hpa.
# Uso:
#   ./scripts/stress-evaluation-hpa.sh start
#   ./scripts/stress-evaluation-hpa.sh stop

set -Eeuo pipefail

readonly namespace="evaluation-ns"
readonly deployment="evaluation-deployment"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Erro: o comando '$1' não está instalado ou não está no PATH." >&2
    exit 1
  }
}

require_command kubectl

case "${1:-}" in
  start)
    # O processo 'yes' ocupa CPU continuamente. O limit de 800m garante uma
    # carga alta em cada réplica sem deixar o container usar um núcleo inteiro.
    kubectl patch deployment "$deployment" -n "$namespace" --type=strategic \
      --patch '{"spec":{"template":{"spec":{"containers":[{"name":"cpu-stress","image":"busybox:1.36.1","imagePullPolicy":"IfNotPresent","command":["/bin/sh","-ec","yes > /dev/null"],"resources":{"requests":{"cpu":"100m","memory":"32Mi"},"limits":{"cpu":"800m","memory":"64Mi"}}}]}}}}'
    kubectl rollout status "deployment/${deployment}" -n "$namespace" --timeout=180s
    echo "Carga de CPU ativada. Acompanhe com: kubectl get hpa -n ${namespace} -w"
    ;;
  stop)
    kubectl patch deployment "$deployment" -n "$namespace" --type=strategic \
      --patch '{"spec":{"template":{"spec":{"containers":[{"name":"cpu-stress","$patch":"delete"}]}}}}'
    kubectl rollout status "deployment/${deployment}" -n "$namespace" --timeout=180s
    echo "Carga de CPU removida. O HPA pode levar alguns minutos para reduzir as réplicas."
    ;;
  *)
    echo "Uso: $0 {start|stop}" >&2
    exit 1
    ;;
esac
