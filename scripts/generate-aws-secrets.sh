#!/bin/bash
# Script para gerar Secrets Kubernetes com credenciais AWS codificadas em base64

set -e

echo "=== AWS Secrets Generator para Kubernetes ==="
echo ""

# Função para fazer encode base64
encode_base64() {
    echo -n "$1" | base64
}

# Solicita credenciais
echo "Digite suas credenciais AWS:"
read -p "AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
read -sp "AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
echo ""
read -p "AWS_SESSION_TOKEN (opcional, pressione Enter para pular): " AWS_SESSION_TOKEN
read -p "AWS_REGION (padrão: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# Encoding em base64
AWS_ACCESS_KEY_B64=$(encode_base64 "$AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY_B64=$(encode_base64 "$AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN_B64=$(encode_base64 "$AWS_SESSION_TOKEN")

echo ""
echo "=== Valores Codificados em Base64 ==="
echo ""
echo "AWS_ACCESS_KEY_ID:"
echo "$AWS_ACCESS_KEY_B64"
echo ""
echo "AWS_SECRET_ACCESS_KEY:"
echo "$AWS_SECRET_KEY_B64"
echo ""
if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo "AWS_SESSION_TOKEN:"
    echo "$AWS_SESSION_TOKEN_B64"
    echo ""
fi

# Gera YAML template
cat > /tmp/aws-secrets-template.yaml << EOF
---
# Para cada serviço (analytics, flag, targeting, evaluation, auth)
# Substitua os valores base64 abaixo nos respectivos Secret Kubernetes
---
apiVersion: v1
kind: Secret
metadata:
  name: SERVICE-secret          # ALTERE: analytics-secret, flag-secret, etc
  namespace: SERVICE-ns         # ALTERE: analytics-ns, flag-ns, etc
type: Opaque
data:
  AWS_ACCESS_KEY_ID: "$AWS_ACCESS_KEY_B64"
  AWS_SECRET_ACCESS_KEY: "$AWS_SECRET_KEY_B64"
EOF

if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo "  AWS_SESSION_TOKEN: \"$AWS_SESSION_TOKEN_B64\"" >> /tmp/aws-secrets-template.yaml
fi

echo ""
echo "=== Template YAML Gerado ==="
echo ""
cat /tmp/aws-secrets-template.yaml
echo ""
echo "✅ Template salvo em: /tmp/aws-secrets-template.yaml"
echo ""
echo "=== ConfigMap (sem credenciais - valores em plaintext) ==="
echo ""
cat > /tmp/aws-configmap-template.yaml << EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: SERVICE-config          # ALTERE: analytics-config, flag-config, etc
  namespace: SERVICE-ns         # ALTERE: analytics-ns, flag-ns, etc
data:
  AWS_REGION: "$AWS_REGION"
  AWS_SQS_URL: "https://sqs.$AWS_REGION.amazonaws.com/YOUR_ACCOUNT_ID/queue-name"
  AWS_DYNAMODB_TABLE: "table-name"
EOF

cat /tmp/aws-configmap-template.yaml
echo ""
echo "✅ ConfigMap template salvo em: /tmp/aws-configmap-template.yaml"
echo ""
echo "=== Próximos Passos ==="
echo "1. Copie os valores base64 para seus manifestos YAML"
echo "2. Altere SERVICE-secret e SERVICE-ns para seus valores reais"
echo "3. Aplique com: kubectl apply -f k8s/"
echo "4. Verifique com: kubectl get secrets -n analytics-ns"
