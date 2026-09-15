FROM postgres:16-alpine

# Variáveis padrão para o container local
ENV POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=postgres

# Expondo a porta padrão do PostgreSQL
EXPOSE 5432

# Volume padrão para persistir dados locais
VOLUME ["/var/lib/postgresql/data"]

# Scripts de inicialização serão executados automaticamente pelo entrypoint
# do PostgreSQL ao criar o banco pela primeira vez.
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
