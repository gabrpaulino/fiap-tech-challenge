FROM python:3.12-slim-bookworm AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools && pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim-bookworm AS runtime
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin/gunicorn /usr/local/bin/gunicorn
COPY . .
RUN pip install --no-cache-dir setuptools \
    && apt-get update && apt-get install --no-install-recommends -y wget adduser \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --disabled-password --uid 1000 appuser
USER appuser
EXPOSE 8003
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8003/health || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:8003", "app:app"]
