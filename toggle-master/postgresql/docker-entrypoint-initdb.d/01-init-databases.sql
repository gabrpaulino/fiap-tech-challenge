-- Cria os bancos usados pelos serviços do projeto
CREATE DATABASE auth_db OWNER postgres;
CREATE DATABASE flags_db OWNER postgres;
CREATE DATABASE targeting_db OWNER postgres;

\connect auth_db
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

\connect flags_db
CREATE TABLE IF NOT EXISTS flags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp ON flags;

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON flags
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

\connect targeting_db
CREATE TABLE IF NOT EXISTS targeting_rules (
    id SERIAL PRIMARY KEY,
    flag_name VARCHAR(100) UNIQUE NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    rules JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp ON targeting_rules;

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON targeting_rules
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();
