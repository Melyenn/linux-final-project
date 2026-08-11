-- db/init.sql
CREATE DATABASE appdb;
CREATE USER appuser WITH PASSWORD :db_password;
GRANT ALL PRIVILEGES ON DATABASE appdb to appuser;
\connect appdb;
GRANT ALL PRIVILEGES ON SCHEMA public TO appuser;
CREATE TABLE products (id serial PRIMARY KEY, name varchar(100));