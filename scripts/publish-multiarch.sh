#!/usr/bin/env bash

# Publica as imagens das aplicações no ECR como manifestos multi-arquitetura.
# Uso:
#   ./scripts/publish-multiarch.sh
# Opcional:
#   AWS_REGION=us-east-1 AWS_PROFILE=aws_academy ./scripts/publish-multiarch.sh

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}/.."

readonly AWS_PROFILE="${AWS_PROFILE:-aws_academy}"
readonly AWS_REGION="${AWS_REGION:-us-east-1}"
readonly PLATFORMS="linux/amd64,linux/arm64"
readonly BUILDER_NAME="${BUILDER_NAME:-togglemaster-multiarch}"

services=(
  auth-service
  flag-service
  targeting-service
  evaluation-service
  analytics-service
)

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Erro: o comando '$1' não está instalado ou não está no PATH." >&2
    exit 1
  }
}

require_command aws
require_command docker

docker buildx version >/dev/null 2>&1 || {
  echo "Erro: o Docker Buildx é necessário para publicar imagens multi-arquitetura." >&2
  exit 1
}

account_id="$(aws sts get-caller-identity \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query Account \
  --output text)"
readonly registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Autenticando no ECR ${registry} com o profile ${AWS_PROFILE}..."
aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  | docker login --username AWS --password-stdin "$registry"

if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx use "$BUILDER_NAME"
else
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
fi
docker buildx inspect --bootstrap >/dev/null

for service in "${services[@]}"; do
  if [[ ! -f "$service/Dockerfile" ]]; then
    echo "Erro: Dockerfile não encontrado para '$service'." >&2
    exit 1
  fi

  image="${registry}/${service}:latest"
  printf '\nPublicando %s para %s...\n' "$image" "$PLATFORMS"
  docker buildx build \
    --platform "$PLATFORMS" \
    --tag "$image" \
    --pull \
    --push \
    "$service"
done

printf '\nPublicação concluída. Validando o manifest da última imagem...\n'
docker buildx imagetools inspect "${registry}/analytics-service:latest"
