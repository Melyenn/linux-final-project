-- Create application database
SELECT 'CREATE DATABASE appdb'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'appdb'
)\gexec

-- Create application user if it does not exist.
-- psql variables are not expanded inside DO $$...$$ blocks, so use \gexec.
SELECT format('CREATE USER appuser WITH PASSWORD %L', :'db_password')
WHERE NOT EXISTS (
    SELECT FROM pg_roles WHERE rolname = 'appuser'
)\gexec

\connect appdb

-- Application only needs access to its database/schema
GRANT CONNECT ON DATABASE appdb TO appuser;
GRANT USAGE ON SCHEMA public TO appuser;

-- Database objects are created by the administrator
CREATE TABLE IF NOT EXISTS products (
    id serial PRIMARY KEY,
    name varchar(100)
);

-- Least privilege required by the current Flask application:
-- GET /products  -> SELECT
-- POST /products -> INSERT
GRANT SELECT, INSERT ON TABLE products TO appuser;

-- INSERT into a SERIAL column requires access to its sequence
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO appuser;
