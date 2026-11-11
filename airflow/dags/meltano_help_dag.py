from datetime import datetime

from airflow import DAG
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

with DAG(
    dag_id="meltano_help",
    description="Run Meltano help, then trigger the Meltano dragon example DAG(teste de update).",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["meltano", "trigger-test"],
) as dag:
    show_meltano_help = KubernetesPodOperator(
        task_id="show_meltano_help",
        name="meltano-help",
        namespace="meltano",
        image="meltano-pipeline:v1",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/sh", "-ec"],
        arguments=["cd /project && exec meltano --environment=prod --help"],
    )

    trigger_dragon = TriggerDagRunOperator(
        task_id="trigger_meltano_dragon",
        trigger_dag_id="meltano_dragon",
        wait_for_completion=False,
    )

    show_meltano_help >> trigger_dragon
