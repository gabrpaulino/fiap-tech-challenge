FROM golang:1.22 AS builder

WORKDIR /app

# 1) Copia primeiro os arquivos de dependência para aproveitar cache do build
COPY go.mod go.sum ./
RUN go mod download

# 2) Copia o restante do código-fonte e compila o binário
COPY . .
RUN go build -o auth-service .

FROM golang:1.22 AS runtime

WORKDIR /app

# 3) Copia apenas o binário do estágio anterior
COPY --from=builder /app/auth-service ./auth-service

# Porta usada pela aplicação
EXPOSE 8001

# Healthcheck simples: testa o endpoint /health do serviço
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:${PORT:-8001}/health || exit 1

# O app lê PORT, DATABASE_URL e MASTER_KEY no ambiente
CMD ["./auth-service"]
