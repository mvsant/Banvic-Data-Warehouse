from datetime import datetime, timedelta
import json

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from airflow.providers.cncf.kubernetes.secret import Secret
from kubernetes.client import models as k8s

COLABORADORES_SECRET = "banvic-postgres-credentials"

with DAG(
    dag_id="meltano_select",
    description="Standalone Meltano load of only the colaboradores stream.",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["meltano", "select", "postgres"],
) as dag:
    load_colaboradores = KubernetesPodOperator(
        task_id="load_colaboradores",
        name="meltano-colaboradores",
        namespace="meltano",
        image="meltano-pipeline:v1",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/sh", "-ec"],
        arguments=[
            "test -s /project/extract/colaboradores.csv || "
            "(echo 'Required source file is missing or empty: colaboradores.csv' >&2; exit 1); "
            "exec meltano --environment=prod run tap-csv target-postgres"
        ],
        volumes=[
            k8s.V1Volume(
                name="meltano-data-volume",
                persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
                    claim_name="meltano-data-pvc",
                ),
            ),
        ],
        volume_mounts=[
            k8s.V1VolumeMount(
                name="meltano-data-volume",
                mount_path="/project/extract",
                read_only=True,
            ),
        ],
        secrets=[
            Secret(
                deploy_type="env",
                deploy_target="TARGET_POSTGRES_USER",
                secret=COLABORADORES_SECRET,
                key="POSTGRES_USER",
            ),
            Secret(
                deploy_type="env",
                deploy_target="TARGET_POSTGRES_PASSWORD",
                secret=COLABORADORES_SECRET,
                key="POSTGRES_PASSWORD",
            ),
            Secret(
                deploy_type="env",
                deploy_target="TARGET_POSTGRES_DBNAME",
                secret=COLABORADORES_SECRET,
                key="POSTGRES_DB",
            ),
        ],
        env_vars={
            "TAP_CSV__SELECT": json.dumps(["colaboradores.*"]),
            "TARGET_POSTGRES_HOST": "{{ conn.banvic_postgres.host }}",
            "TARGET_POSTGRES_PORT": "{{ conn.banvic_postgres.port }}",
        },
        retries=3,
        retry_delay=timedelta(minutes=2),
        retry_exponential_backoff=True,
    )
