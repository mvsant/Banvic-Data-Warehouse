from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

with DAG(
    dag_id="meltano_dragon",
    description="Run a valid Meltano project sanity check in the project container.",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["meltano", "sanity-check"],
) as dag:
    summon_dragon = KubernetesPodOperator(
        task_id="summon_dragon",
        name="meltano-dragon",
        namespace="meltano",
        image="meltano-pipeline:v1",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/sh", "-ec"],
        arguments=["cd /project && exec meltano --environment=prod --help"],
    )
