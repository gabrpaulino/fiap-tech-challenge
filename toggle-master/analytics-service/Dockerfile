# ============================================================================
# ESTÁGIO 1: BUILD (Multi-stage build para otimizar tamanho da imagem)
# ============================================================================
# Objetivo: Compilar dependências Python em ambiente otimizado
FROM python:3.10-slim AS builder
WORKDIR /app
# Copiar requirements para cache layer
COPY requirements.txt .
# Instalar dependências (--no-cache-dir reduz tamanho em ~30MB)
RUN pip install --no-cache-dir -r requirements.txt

# ============================================================================
# ESTÁGIO 2: RUNTIME (Imagem final minimalista)
# ============================================================================
# Objetivo: Executar aplicação com segurança, tamanho reduzido e sem root
FROM python:3.10-alpine AS runtime
WORKDIR /app
# Copiar site-packages do estágio builder (não inclui ferramentas de build)
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
# Copiar o executável do Gunicorn para o runtime
COPY --from=builder /usr/local/bin/gunicorn /usr/local/bin/gunicorn
# Copiar código-fonte da aplicação
COPY . .

# Criar usuário não-root para executar a aplicação
# -D: Desabilita password login (system user, mais seguro)
# -u 1000: Define UID 1000 (primeiro usuário regular após sistema)
# SEGURANÇA: Container rodará como 'appuser' (UID 1000), não como root
RUN adduser -D -u 1000 appuser
USER appuser

# Documentar porta exposta da aplicação
# NOTA: EXPOSE não abre a porta automaticamente - use docker run -p 8005:8005
EXPOSE 8005

# Health check para readiness probe (simula teste de K8s/Docker Compose)
# --interval=30s: Testa a cada 30 segundos
# --timeout=3s: Aguarda máximo 3s por resposta
# --start-period=5s: Aguarda 5s antes de começar testes (app warm-up)
# --retries=3: Container fica unhealthy após 3 falhas consecutivas
# CMD: Usa wget para testar endpoint /health (mesmo que curl)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8005/health || exit 1

# Executar aplicação via Gunicorn (servidor WSGI de produção)
# --bind 0.0.0.0:8005: Escuta em todas as interfaces, porta 8005
# app:app: módulo 'app.py' + variável 'app' (Flask object)
CMD ["gunicorn", "--bind", "0.0.0.0:8005", "app:app"]
