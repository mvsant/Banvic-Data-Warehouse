from datetime import datetime
import logging

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from airflow.providers.cncf.kubernetes.secret import Secret

# --- Error Handling Callback Routine ---
def on_task_failure_callback(context):
    ti = context['task_instance']
    logging.error(f"🚨 CRITICAL RESILIENCE ALERT: Task '{ti.task_id}' failed in DAG '{ti.dag_id}'.")

# --- Resilient Default Configuration Mapping ---
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),  # Direct datetime object replaces deprecated days_ago
    "on_failure_callback": on_task_failure_callback,
}

# --- Shared Secret Variable Configurations for Postgres ---
secret_user = Secret(deploy_type="env", deploy_target="PGUSER", secret="postgres-credentials", key="POSTGRES_USER")
secret_password = Secret(deploy_type="env", deploy_target="PGPASSWORD", secret="postgres-credentials", key="POSTGRES_PASSWORD")
secret_db = Secret(deploy_type="env", deploy_target="PGDATABASE", secret="postgres-credentials", key="POSTGRES_DB")

with DAG(
    dag_id="analise_churn_risk_dag",
    default_args=default_args,
    schedule=None,
    catchup=False,
    tags=["analytics", "churn", "risco"],
) as dag:

    # 1. Task: Analise Churn
    analise_churn = KubernetesPodOperator(
        task_id="analise_churn",
        name="analytics-churn-worker",
        namespace="meltano",
        image="postgres:15-alpine",  # Lightweight native client image
        cmds=["psql", "-h", "postgres-service.postgres.svc.cluster.local", "-p", "5432", "-c"],
        arguments=["""
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
                (
                    bd.current_date_baseline -
                    MAX(t.data_transacao)::date
                ) AS days_inactive
            FROM public.contas c
            LEFT JOIN public.transacoes t
                ON c.num_conta = t.num_conta
            CROSS JOIN business_dates bd
            GROUP BY
                c.num_conta,
                bd.current_date_baseline
        ),

        churn_classification AS (
            SELECT
                num_conta,
                last_transaction_date,
                days_inactive,
                CASE
                    WHEN days_inactive > 90
                         OR last_transaction_date IS NULL
                    THEN 1
                    ELSE 0
                END AS is_churned
            FROM customer_last_activity
        )

        SELECT
            COUNT(*) AS total_customers,
            SUM(is_churned) AS total_churned_customers,
            ROUND(
                (SUM(is_churned)::numeric / COUNT(*)::numeric) * 100,
                2
            ) AS churn_rate_percentage
        FROM churn_classification;
        """],
        secrets=[secret_user, secret_password, secret_db],
        retries=1,
    )

    # 2. Task: Analise Risco
    analise_risco = KubernetesPodOperator(
        task_id="analise_risco",
        name="analytics-risk-worker",
        namespace="meltano",
        image="postgres:15-alpine",
        cmds=["psql", "-h", "postgres-service.postgres.svc.cluster.local", "-p", "5432", "-c"],
        arguments=["""
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

        SELECT *
        FROM customer_risk;
        """],
        secrets=[secret_user, secret_password, secret_db],
        retries=1,
    )

    analise_churn >> analise_risco
