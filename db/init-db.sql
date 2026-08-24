-- 1. Create application database if it does not exist
SELECT 'CREATE DATABASE appdb'
WHERE NOT EXISTS (
            SELECT
            FROM pg_database
            WHERE datname = 'appdb'
)
\gexec


-- 2. Create application user if it does not exist
SELECT format(
            'CREATE USER appuser WITH PASSWORD %L',
            :'db_password'
)
WHERE NOT EXISTS (
            SELECT
            FROM pg_roles
            WHERE rolname = 'appuser'
)
\gexec


-- 3. Connect to application database
\connect appdb


-- 4. Allow application user to connect to the database
GRANT CONNECT ON DATABASE appdb TO appuser;


-- 5. Allow application user to access public schema
GRANT USAGE ON SCHEMA public TO appuser;


-- 6. Create application table
CREATE TABLE IF NOT EXISTS products (
            id serial PRIMARY KEY,
            name varchar(100)
        );


        -- 7. Reset table privileges to enforce least privilege
REVOKE ALL PRIVILEGES ON TABLE products FROM appuser;

-- Flask application permissions:
-- GET /products  -> SELECT
-- POST /products -> INSERT
GRANT SELECT, INSERT ON TABLE products TO appuser;


-- 8. Reset sequence privileges
REVOKE ALL PRIVILEGES ON SEQUENCE products_id_seq FROM appuser;

-- INSERT into SERIAL column requires sequence access
GRANT USAGE, SELECT ON SEQUENCE products_id_seq TO appuser;
