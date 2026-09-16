FROM python:3.12-slim-bookworm AS builder
WORKDIR /app
# Copiar requirements para cache layer
COPY requirements.txt .
# Instalar dependências (--no-cache-dir reduz tamanho em ~30MB)
RUN pip install --no-cache-dir --upgrade pip "setuptools==75.8.0" && pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim-bookworm AS runtime
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip "setuptools==75.8.0" && pip install --no-cache-dir -r requirements.txt
# Copiar código-fonte da aplicação
COPY . .
# Criar usuário não-root para executar a aplicação
# -D: Desabilita password login (system user, mais seguro)
# -u 1000: Define UID 1000 (primeiro usuário regular após sistema)
# SEGURANÇA: Container rodará como 'appuser' (UID 1000), não como root
RUN apt-get update && apt-get install --no-install-recommends -y wget adduser \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --disabled-password -u 1000 appuser
USER appuser

# Documentar porta exposta da aplicação
# NOTA: EXPOSE não abre a porta automaticamente - use docker run -p 8002:8002
EXPOSE 8002

# Health check para readiness probe (simula teste de K8s/Docker Compose)
# --interval=30s: Testa a cada 30 segundos
# --timeout=3s: Aguarda máximo 3s por resposta
# --start-period=5s: Aguarda 5s antes de começar testes (app warm-up)
# --retries=3: Container fica unhealthy após 3 falhas consecutivas
# CMD: Usa wget para testar endpoint /health (mesmo que curl)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8002/health || exit 1

# Executar aplicação via Gunicorn (servidor WSGI de produção)
# --bind: Especifica o endereço e porta onde o servidor irá escutar
######### teste
CMD ["gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
