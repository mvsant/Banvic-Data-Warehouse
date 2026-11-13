from datetime import datetime, timedelta
import json
import logging

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from airflow.providers.cncf.kubernetes.secret import Secret
from airflow.sdk.bases.operator import cross_downstream
from kubernetes.client import models as k8s

def on_task_failure_callback(context):
    ti = context['task_instance']
    logging.error(f"🚨 CRITICAL RESILIENCE ALERT: Task '{ti.task_id}' failed completely in DAG '{ti.dag_id}'.")
    logging.error(f"Exception details: {context.get('exception')}")

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
    "on_failure_callback": on_task_failure_callback,
}

secret_user = Secret(
    deploy_type="env",
    deploy_target="TARGET_POSTGRES_USER",
    secret="banvic-postgres-credentials",
    key="POSTGRES_USER",
)
secret_password = Secret(
    deploy_type="env",
    deploy_target="TARGET_POSTGRES_PASSWORD",
    secret="banvic-postgres-credentials",
    key="POSTGRES_PASSWORD",
)
secret_db = Secret(
    deploy_type="env",
    deploy_target="TARGET_POSTGRES_DBNAME",
    secret="banvic-postgres-credentials",
    key="POSTGRES_DB",
)

persistent_data_volume = k8s.V1Volume(
    name="meltano-data-volume",
    persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(claim_name="meltano-data-pvc"),
)
persistent_data_volume_mount = k8s.V1VolumeMount(
    name="meltano-data-volume",
    mount_path="/project/extract",
    read_only=True,
)

ENTITIES = {
    "agencias": "agencias.csv",
    "colaboradores": "colaboradores.csv",
    "colaborador_agencia": "colaborador_agencia.csv",
    "clientes": "clientes.csv",
    "contas": "contas.csv",
    "propostas_credito": "propostas_credito.csv",
    "transacoes": "transacoes.csv",
}

with DAG(
    dag_id="extract_pipeline",
    description="Extract selected streams from the Meltano PVC and load PostgreSQL.",
    default_args=default_args,
    schedule=None,
    catchup=False,
    tags=["meltano", "extract", "postgres", "banvic"],
) as dag:
    sync_tasks = {}

    for entity, filename in ENTITIES.items():
        sync_tasks[entity] = KubernetesPodOperator(
            task_id=f"sync_{entity}",
            name=f"meltano-{entity}-worker",
            namespace="meltano",
            image="meltano-pipeline:v1",
            image_pull_policy="IfNotPresent",
            cmds=["/bin/sh", "-ec"],
            arguments=[
                f"test -s /project/extract/{filename} || "
                f"(echo 'Required source file is missing or empty: {filename}' >&2; exit 1); "
                f"exec meltano --environment=prod run --state-id-suffix={entity} "
                "tap-csv target-postgres"
            ],
            volumes=[persistent_data_volume],
            volume_mounts=[persistent_data_volume_mount],
            secrets=[secret_user, secret_password, secret_db],
            env_vars={
                "TAP_CSV__SELECT": json.dumps([f"{entity}.*"]),
                "TARGET_POSTGRES_HOST": "{{ conn.banvic_postgres.host }}",
                "TARGET_POSTGRES_PORT": "{{ conn.banvic_postgres.port }}",
            },
            retries=3,
            retry_delay=timedelta(minutes=2),
            retry_exponential_backoff=True,
        )

    cross_downstream(
        [
            sync_tasks["agencias"],
            sync_tasks["colaboradores"],
            sync_tasks["colaborador_agencia"],
        ],
        [
            sync_tasks["clientes"],
            sync_tasks["contas"],
            sync_tasks["propostas_credito"],
        ],
    )

    [
        sync_tasks["clientes"],
        sync_tasks["contas"],
        sync_tasks["propostas_credito"],
    ] >> sync_tasks["transacoes"]
