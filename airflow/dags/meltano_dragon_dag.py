from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

with DAG(
    dag_id="meltano_dragon",
    description="Run the Meltano dragon command as a follow-up trigger test.",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["meltano", "dragon", "trigger-test"],
) as dag:
    summon_dragon = KubernetesPodOperator(
        task_id="summon_dragon",
        name="meltano-dragon",
        namespace="meltano",
        image="meltano-pipeline:v1",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/sh", "-ec"],
        arguments=["cd /project && exec meltano --environment=prod dragon"],
    )
