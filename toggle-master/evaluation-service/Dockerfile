FROM golang:1.22 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o evaluation-service .

FROM golang:1.22 AS runtime

WORKDIR /app
COPY --from=builder /app/evaluation-service ./evaluation-service

EXPOSE 8004

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8004/health || exit 1

CMD ["./evaluation-service"]
