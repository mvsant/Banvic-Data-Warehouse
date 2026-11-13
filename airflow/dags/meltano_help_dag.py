from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

with DAG(
    dag_id="meltano_help",
    description="Run a valid Meltano help command to confirm the project container is healthy.",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["meltano", "sanity-check"],
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
