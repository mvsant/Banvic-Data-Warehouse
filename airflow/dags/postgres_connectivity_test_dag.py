from datetime import datetime

from airflow import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
}

with DAG(
    dag_id="postgres_connectivity_test",
    description="Check the configured Airflow connection to the Banvic PostgreSQL database.",
    default_args=default_args,
    schedule=None,
    catchup=False,
    tags=["postgres", "connectivity"],
) as dag:

    test_connection = SQLExecuteQueryOperator(
        task_id="confirm_postgres_connectivity",
        conn_id="banvic_postgres",
        sql="""
        SELECT
            current_database() AS database_name,
            current_user AS username,
            version() AS postgres_version;
        """,
    )
