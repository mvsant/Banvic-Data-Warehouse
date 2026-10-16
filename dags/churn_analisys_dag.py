from datetime import datetime
import logging
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.hooks.sql import DbApiHook

# --- Quick DB Execution Helper Routine ---
def execute_postgres_sql(sql_query, conn_id="postgres_default"):
    """Fetches connection directly via Airflow core and runs raw SQL."""
    hook = DbApiHook.get_hook(conn_id=conn_id)
    logging.info(f"Executing query via connection: {conn_id}")
    hook.run(sql_query)

# --- Default Configurations ---
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
}

with DAG(
    dag_id="analise_churn_risk_dag",
    default_args=default_args,
    schedule=None,
    catchup=False,
    tags=["analytics", "churn", "risco"],
) as dag:

    # 1. Task: Analise Churn
    analise_churn = PythonOperator(
        task_id="analise_churn",
        python_callable=execute_postgres_sql,
        op_kwargs={
            "conn_id": "postgres_default",
            "sql_query": """
                DROP TABLE IF EXISTS public.analise_churn;

                CREATE TABLE public.analise_churn AS
                WITH business_dates AS (
                    SELECT MAX(data_transacao)::date AS current_date_baseline
                    FROM public.transacoes
                ),
                customer_last_activity AS (
                    SELECT
                        c.num_conta,
                        MAX(t.data_transacao)::date AS last_transaction_date,
                        (bd.current_date_baseline - MAX(t.data_transacao)::date) AS days_inactive
                    FROM public.contas c
                    LEFT JOIN public.transacoes t ON c.num_conta = t.num_conta
                    CROSS JOIN business_dates bd
                    GROUP BY c.num_conta, bd.current_date_baseline
                ),
                churn_classification AS (
                    SELECT
                        num_conta,
                        last_transaction_date,
                        days_inactive,
                        CASE
                            WHEN days_inactive > 90 OR last_transaction_date IS NULL THEN 1
                            ELSE 0
                        END AS is_churned
                    FROM customer_last_activity
                )
                SELECT
                    COUNT(*) AS total_customers,
                    SUM(is_churned) AS total_churned_customers,
                    ROUND((SUM(is_churned)::numeric / COUNT(*)::numeric) * 100, 2) AS churn_rate_percentage
                FROM churn_classification;
            """
        }
    )

    # 2. Task: Analise Risco
    analise_risco = PythonOperator(
        task_id="analise_risco",
        python_callable=execute_postgres_sql,
        op_kwargs={
            "conn_id": "postgres_default",
            "sql_query": """
                DROP TABLE IF EXISTS public.analise_risco;

                CREATE TABLE public.analise_risco AS
                WITH business_dates AS (
                    SELECT MAX(data_transacao)::date AS current_date_baseline
                    FROM public.transacoes
                ),
                customer_risk AS (
                    SELECT
                        c.num_conta,
                        MAX(t.data_transacao)::date AS last_transaction_date,
                        (bd.current_date_baseline - MAX(t.data_transacao)::date) AS dias_inativos,
                        CASE
                            WHEN (bd.current_date_baseline - MAX(t.data_transacao)::date) > 90 THEN 'ALTO'
                            WHEN (bd.current_date_baseline - MAX(t.data_transacao)::date) > 60 THEN 'MEDIO'
                            ELSE 'BAIXO'
                        END AS nivel_risco
                    FROM public.contas c
                    LEFT JOIN public.transacoes t ON c.num_conta = t.num_conta
                    CROSS JOIN business_dates bd
                    GROUP BY c.num_conta, bd.current_date_baseline
                )
                SELECT * FROM customer_risk;
            """
        }
    )

    analise_churn >> analise_risco
