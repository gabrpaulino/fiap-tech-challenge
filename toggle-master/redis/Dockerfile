FROM redis:7.2-alpine

# Porta padrão do Redis
EXPOSE 6379

# Volume padrão para persistir dados locais
VOLUME ["/data"]

# Comando padrão para iniciar o Redis com persistência básica
CMD ["redis-server", "--appendonly", "yes"]
