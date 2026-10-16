from airflow import DAG
from airflow.operators.postgres_operator import PostgresOperator
from airflow.utils.dates import days_ago

with DAG(
    dag_id="analise_churn_risk_dag",
    start_date=days_ago(1),
    schedule="@daily",
    catchup=False,
    tags=["analytics", "churn", "risco"],
) as dag:

    analise_churn = PostgresOperator(
        task_id="analise_churn",
        postgres_conn_id="postgres_default",
        sql="""

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

        """,
    )

    analise_risco = PostgresOperator(
        task_id="analise_risco",
        postgres_conn_id="postgres_default",
        sql="""

        DROP TABLE IF EXISTS public.analise_risco;

        CREATE TABLE public.analise_risco AS

        WITH customer_risk AS (
            SELECT
                c.num_conta,
                MAX(t.data_transacao)::date AS last_transaction_date,
                CURRENT_DATE - MAX(t.data_transacao)::date AS dias_inativos,

                CASE
                    WHEN CURRENT_DATE - MAX(t.data_transacao)::date > 90
                        THEN 'ALTO'
                    WHEN CURRENT_DATE - MAX(t.data_transacao)::date > 60
                        THEN 'MEDIO'
                    ELSE 'BAIXO'
                END AS nivel_risco
            FROM public.contas c
            LEFT JOIN public.transacoes t
                ON c.num_conta = t.num_conta
            GROUP BY c.num_conta
        )

        SELECT *
        FROM customer_risk;

        """,
    )

    analise_churn >> analise_risco