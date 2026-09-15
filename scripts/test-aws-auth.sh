#!/bin/bash
# Script para testar autenticação AWS em Kubernetes

set -e

NAMESPACE=${1:-analytics-ns}
POD_LABEL=${2:-app=analytics}

echo "=== Teste de Autenticação AWS ==="
echo "Namespace: $NAMESPACE"
echo "Label: $POD_LABEL"
echo ""

# Encontra o primeiro pod com o label
POD=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "❌ Nenhum pod encontrado com label '$POD_LABEL' no namespace '$NAMESPACE'"
    exit 1
fi

echo "✅ Pod encontrado: $POD"
echo ""

# Teste 1: Verificar variáveis de ambiente
echo "=== Teste 1: Variáveis de Ambiente ==="
kubectl exec -it "$POD" -n "$NAMESPACE" -- sh -c '
echo "AWS_REGION: $AWS_REGION"
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:8}***"
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:8}***"
if [ -n "$AWS_SESSION_TOKEN" ]; then
    echo "AWS_SESSION_TOKEN: ${AWS_SESSION_TOKEN:0:8}***"
else
    echo "AWS_SESSION_TOKEN: (não definido)"
fi
'
echo ""

# Teste 2: Python Boto3 (para serviços Python)
echo "=== Teste 2: Conexão Boto3 (Python) ==="
kubectl exec -it "$POD" -n "$NAMESPACE" -- python3 << 'EOF' 2>&1 || echo "ℹ️  Serviço não é Python"
import boto3
import os
from botocore.exceptions import NoCredentialsError, ClientError

try:
    region = os.getenv("AWS_REGION", "us-east-1")
    session = boto3.Session(region_name=region)
    
    # Tenta conexão com STS (GetCallerIdentity é uma boa verificação)
    sts = session.client("sts")
    identity = sts.get_caller_identity()
    
    print("✅ Boto3 conectado com sucesso!")
    print(f"   Account ID: {identity['Account']}")
    print(f"   ARN: {identity['Arn']}")
    print(f"   User ID: {identity['UserId']}")
except NoCredentialsError:
    print("❌ Credenciais AWS não encontradas ou inválidas")
except ClientError as e:
    print(f"❌ Erro ao conectar: {e}")
except Exception as e:
    print(f"⚠️  Erro: {e}")
EOF
echo ""

# Teste 3: DynamoDB (se tabela estiver configurada)
echo "=== Teste 3: Conexão DynamoDB ==="
kubectl exec -it "$POD" -n "$NAMESPACE" -- python3 << 'EOF' 2>&1 || echo "ℹ️  DynamoDB não testado"
import boto3
import os

try:
    region = os.getenv("AWS_REGION", "us-east-1")
    table_name = os.getenv("AWS_DYNAMODB_TABLE")
    
    if not table_name:
        print("⚠️  AWS_DYNAMODB_TABLE não definido, pulando teste")
        exit(0)
    
    dynamodb = boto3.client("dynamodb", region_name=region)
    response = dynamodb.describe_table(TableName=table_name)
    
    print(f"✅ DynamoDB '{table_name}' encontrado!")
    print(f"   Status: {response['Table']['TableStatus']}")
    print(f"   Item Count: {response['Table']['ItemCount']}")
except Exception as e:
    print(f"⚠️  Erro ao acessar DynamoDB: {e}")
EOF
echo ""

# Teste 4: SQS (se fila estiver configurada)
echo "=== Teste 4: Conexão SQS ==="
kubectl exec -it "$POD" -n "$NAMESPACE" -- python3 << 'EOF' 2>&1 || echo "ℹ️  SQS não testado"
import boto3
import os

try:
    region = os.getenv("AWS_REGION", "us-east-1")
    queue_url = os.getenv("AWS_SQS_URL")
    
    if not queue_url:
        print("⚠️  AWS_SQS_URL não definido, pulando teste")
        exit(0)
    
    sqs = boto3.client("sqs", region_name=region)
    response = sqs.get_queue_attributes(
        QueueUrl=queue_url,
        AttributeNames=["ApproximateNumberOfMessages"]
    )
    
    msg_count = response["Attributes"]["ApproximateNumberOfMessages"]
    print(f"✅ SQS '{queue_url.split('/')[-1]}' conectada!")
    print(f"   Mensagens na fila: {msg_count}")
except Exception as e:
    print(f"⚠️  Erro ao acessar SQS: {e}")
EOF
echo ""

echo "=== Teste Concluído ==="
echo ""
echo "💡 Dicas de Troubleshooting:"
echo "   - Se algum teste falhar, verifique:"
echo "     1. IAM permissions para o AWS_ACCESS_KEY_ID"
echo "     2. Valores base64 estão corretos no Secret"
echo "     3. Recursos existem no AWS (tabelas, filas, etc)"
echo ""
echo "   - Visualize logs completos com:"
echo "     kubectl logs $POD -n $NAMESPACE"
