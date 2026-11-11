REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;
GRANT CONNECT ON DATABASE postgres TO :"postgres_user";

SELECT format(
    'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L',
    :'banvic_user',
    :'banvic_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'banvic_user')
\gexec

ALTER ROLE :"banvic_user"
    WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'banvic_password';

SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'banvic_db',
    :'banvic_user'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'banvic_db')
\gexec

ALTER DATABASE :"banvic_db" OWNER TO :"banvic_user";
REVOKE CONNECT ON DATABASE :"banvic_db" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"banvic_db" TO :"banvic_user";

SELECT format(
    'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L',
    :'airflow_user',
    :'airflow_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'airflow_user')
\gexec

ALTER ROLE :"airflow_user"
    WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'airflow_password';

SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'airflow_db',
    :'airflow_user'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'airflow_db')
\gexec

ALTER DATABASE :"airflow_db" OWNER TO :"airflow_user";
REVOKE CONNECT ON DATABASE :"airflow_db" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"airflow_db" TO :"airflow_user";
