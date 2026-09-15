# AWS Autenticação com Boto3 - Guia de Configuração

## 1. Visão Geral
Seus serviços Python usam **boto3** para autenticar na AWS. As credenciais vêm de variáveis de ambiente injetadas via Secrets Kubernetes.

## 2. Variáveis de Ambiente Necessárias

### No Kubernetes Secret (base64 encoded):
```yaml
AWS_ACCESS_KEY_ID: "sua-chave-id"
AWS_SECRET_ACCESS_KEY: "sua-chave-secreta"
AWS_SESSION_TOKEN: "token-opcional-para-temporary-credentials"
```

### No Kubernetes ConfigMap (plaintext):
```yaml
AWS_REGION: "us-east-1"
AWS_SQS_URL: "https://sqs.us-east-1.amazonaws.com/YOUR_ACCOUNT_ID/queue-name"
AWS_DYNAMODB_TABLE: "nome-da-tabela"
```

## 3. Como Gerar Base64 para Secrets

```bash
# Encode uma string para base64
echo -n "sua-chave-aqui" | base64

# Exemplo:
echo -n "AKIAIOSFODNN7EXAMPLE" | base64
# Saída: QUtJQUlPU0ZPRK5ON0VYQU1QTEU=
```

## 4. Implementação em Serviços Python

### A. Analytics-Service (Exemplo Completo)

```python
import os
import boto3
import logging
from botocore.exceptions import NoCredentialsError, ClientError
from flask import Flask

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Carrega variáveis de ambiente
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
SQS_QUEUE_URL = os.getenv("AWS_SQS_URL")
DYNAMODB_TABLE = os.getenv("AWS_DYNAMODB_TABLE")

# Validação crítica
if not all([AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, SQS_QUEUE_URL, DYNAMODB_TABLE]):
    log.critical("❌ Faltam variáveis AWS obrigatórias")
    exit(1)

# Inicializa a sessão Boto3
try:
    session = boto3.Session(
        region_name=AWS_REGION,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        aws_session_token=AWS_SESSION_TOKEN  # Opcional
    )
    
    # Clientes AWS
    sqs = session.client("sqs")
    dynamodb = session.client("dynamodb")
    
    log.info(f"✅ Autenticação AWS bem-sucedida na região {AWS_REGION}")
except NoCredentialsError as e:
    log.critical(f"❌ Credenciais AWS não encontradas: {e}")
    exit(1)
except Exception as e:
    log.critical(f"❌ Erro ao conectar AWS: {e}")
    exit(1)

app = Flask(__name__)

# Exemplo: Ler mensagens SQS
@app.route("/process-queue", methods=["POST"])
def process_queue():
    try:
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=5
        )
        
        messages = response.get("Messages", [])
        log.info(f"📨 {len(messages)} mensagens recebidas da SQS")
        
        # Processa cada mensagem
        for msg in messages:
            body = msg["Body"]
            receipt_handle = msg["ReceiptHandle"]
            
            # Salva no DynamoDB
            dynamodb.put_item(
                TableName=DYNAMODB_TABLE,
                Item={
                    "message_id": {"S": msg["MessageId"]},
                    "content": {"S": body},
                    "timestamp": {"N": str(int(time.time()))}
                }
            )
            
            # Remove da fila
            sqs.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=receipt_handle
            )
        
        return {"status": "ok", "processed": len(messages)}, 200
    
    except ClientError as e:
        log.error(f"❌ Erro AWS: {e}")
        return {"error": str(e)}, 500

@app.route("/health", methods=["GET"])
def health():
    return {"status": "healthy"}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

### B. Flag-Service (Python)

```python
import os
import boto3
from flask import Flask

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
DYNAMODB_TABLE = os.getenv("AWS_DYNAMODB_TABLE", "flag-table")

session = boto3.Session(
    region_name=AWS_REGION,
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY
)
dynamodb = session.client("dynamodb")

app = Flask(__name__)

@app.route("/flags", methods=["GET"])
def get_flags():
    try:
        response = dynamodb.scan(TableName=DYNAMODB_TABLE)
        flags = response.get("Items", [])
        return {"flags": flags}, 200
    except Exception as e:
        return {"error": str(e)}, 500

@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok"}, 200
```

### C. Targeting-Service (Python)

```python
import os
import boto3
from flask import Flask, request

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
DYNAMODB_TABLE = os.getenv("AWS_DYNAMODB_TABLE", "targeting-table")

session = boto3.Session(
    region_name=AWS_REGION,
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY
)
dynamodb = session.client("dynamodb")

app = Flask(__name__)

@app.route("/target", methods=["POST"])
def create_target():
    data = request.json
    try:
        dynamodb.put_item(
            TableName=DYNAMODB_TABLE,
            Item={
                "target_id": {"S": data.get("id")},
                "audience": {"S": data.get("audience")},
                "config": {"S": str(data.get("config"))}
            }
        )
        return {"message": "Target criado"}, 201
    except Exception as e:
        return {"error": str(e)}, 500

@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok"}, 200
```

## 5. Implementação em Serviços Go

### Auth-Service (Go)

```go
package main

import (
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
)

func initAWSSession() (*session.Session, error) {
	// Carrega variáveis de ambiente
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	// Boto3 compatível: aws-sdk-go lê automaticamente:
	// AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		log.Fatalf("❌ Erro ao criar sessão AWS: %v", err)
		return nil, err
	}

	log.Printf("✅ Sessão AWS criada com sucesso na região %s", region)
	return sess, nil
}

func main() {
	sess, err := initAWSSession()
	if err != nil {
		log.Fatal("Falha ao inicializar AWS")
	}

	// Usa sess para criar clientes DynamoDB, SQS, etc.
	_ = sess // Placeholder
	log.Println("AWS conectado!")
}
```

### Evaluation-Service (Go)

```go
package main

import (
	"log"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
)

func init() {
	// Valida variáveis obrigatórias
	requiredEnvs := []string{"AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION"}
	for _, env := range requiredEnvs {
		if os.Getenv(env) == "" {
			log.Fatalf("❌ Variável %s não definida", env)
		}
	}
}

func main() {
	// aws-sdk-go lê automaticamente:
	// AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	}))

	sqsClient := sqs.New(sess)
	queueURL := os.Getenv("AWS_SQS_URL")

	// Exemplo: Ler mensagens
	result, err := sqsClient.ReceiveMessage(&sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(queueURL),
		MaxNumberOfMessages: aws.Int64(10),
		WaitTimeSeconds:     aws.Int64(5),
	})
	if err != nil {
		log.Fatalf("❌ Erro ao receber mensagens: %v", err)
	}

	log.Printf("✅ %d mensagens recebidas", len(result.Messages))
}
```

## 6. Aplicando em Kubernetes

### Passo 1: Encode suas credenciais AWS

```bash
# Codifique seus valores reais
echo -n "AKIAIOSFODNN7EXAMPLE" | base64
# Saída: QUtJQUlPU0ZPRK5ON0VYQU1QTEU=

echo -n "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" | base64
# Saída: d0phbHJYVXRuRkVNSS9LN01ERU5HL2JQeFJmaUNZRVhBTVBMRUtFWQ==
```

### Passo 2: Atualizar Secret no YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: analytics-secret
  namespace: analytics-ns
type: Opaque
data:
  AWS_ACCESS_KEY_ID: "QUtJQUlPU0ZPRK5ON0VYQU1QTEU="
  AWS_SECRET_ACCESS_KEY: "d0phbHJYVXRuRkVNSS9LN01ERU5HL2JQeFJmaUNZRVhBTVBMRUtFWQ=="
  AWS_SESSION_TOKEN: "ImlzT3B0aW9uYWw="
```

### Passo 3: Verificar configuração

```bash
# Aplicar os manifestos
kubectl apply -f k8s/analytics.yaml

# Verificar Secret foi criado
kubectl get secret analytics-secret -n analytics-ns -o yaml

# Entrar no pod e testar
kubectl exec -it pod/analytics-deployment-XXX -n analytics-ns -- /bin/bash

# Dentro do pod
echo $AWS_ACCESS_KEY_ID
echo $AWS_REGION
python3 -c "import boto3; print(boto3.__version__)"
```

## 7. Teste Local (com .env)

Crie um arquivo `.env` na raiz do seu serviço:

```env
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
AWS_SQS_URL=https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
AWS_DYNAMODB_TABLE=my-table
```

## 8. Boas Práticas

✅ **Sempre usar**:
- Secrets para credenciais sensíveis (nunca em ConfigMap)
- Base64 encoding para Secrets
- Validação de variáveis obrigatórias na inicialização
- Logging de erros (sem expor valores sensíveis)
- Timeouts nas chamadas AWS
- Try-catch para ClientError

❌ **Nunca fazer**:
- Hardcoding credenciais
- Colocar credenciais em ConfigMap
- Logging de valores de AWS_SECRET_ACCESS_KEY

## 9. Troubleshooting

```bash
# Verificar se variáveis foram injetadas
kubectl exec -it pod/analytics-deployment-XXX -n analytics-ns \
  -- env | grep AWS

# Verificar logs
kubectl logs analytics-deployment-XXX -n analytics-ns

# Testar conexão boto3
kubectl exec -it pod/analytics-deployment-XXX -n analytics-ns \
  -- python3 -c "
import boto3
import os
try:
    session = boto3.Session(region_name=os.getenv('AWS_REGION'))
    dynamodb = session.client('dynamodb')
    print('✅ Conexão AWS OK')
except Exception as e:
    print(f'❌ Erro: {e}')
"
```

---

**Próximos passos**: Substitua os placeholders (`YOUR_AWS_ACCESS_KEY_BASE64`, etc.) com seus valores reais e aplique aos seus deployments.
