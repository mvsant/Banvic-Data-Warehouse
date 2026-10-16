from datetime import datetime, timedelta
import logging

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from airflow.providers.cncf.kubernetes.secret import Secret
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.models.baseoperator import cross_downstream
from kubernetes.client import models as k8s
from airflow.sdk.bases.operator import cross_downstream

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

secret_user = Secret(deploy_type="env", deploy_target="TARGET_POSTGRES_USER", secret="postgres-credentials", key="POSTGRES_USER")
secret_password = Secret(deploy_type="env", deploy_target="TARGET_POSTGRES_PASSWORD", secret="postgres-credentials", key="POSTGRES_PASSWORD")
secret_db = Secret(deploy_type="env", deploy_target="TARGET_POSTGRES_DBNAME", secret="postgres-credentials", key="POSTGRES_DB")

pvc_volume = k8s.V1Volume(
    name="csv-ingestion-volume",
    persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(claim_name="meltano-csv-pvc"),
)
pvc_volume_mount = k8s.V1VolumeMount(
    name="csv-ingestion-volume",
    mount_path="/project/extract",
)

ENTITIES = {
    "agencias": "agencias.csv",
    "colaboradores": "colaboradores.csv",
    "clientes": "clientes.csv",
    "colaborador_agencia": "colaborador_agencia.csv",
    "contas": "contas.csv",
    "propostas_credito": "propostas_credito.csv",
    "transacoes": "transacoes.csv"
}

with DAG(
    'extract_pipeline',
    default_args=default_args,
    schedule=None,
    catchup=False,
) as dag:

    sensor_tasks = {}
    sync_tasks = {}

    for entity, filename in ENTITIES.items():
        
        sensor_tasks[entity] = KubernetesPodOperator(
            task_id=f'sensor_check_{entity}',
            name=f'sensor-check-{entity}',
            namespace='meltano',
            image='busybox:stable',
            cmds=["/bin/sh", "-c"],
            arguments=[f"if [ ! -f /project/extract/{filename} ]; then echo 'CRITICAL ERROR: {filename} missing on local drive storage!'; exit 1; fi"],
            volumes=[pvc_volume],
            volume_mounts=[pvc_volume_mount],
            retries=0, 
        )

        sync_tasks[entity] = KubernetesPodOperator(
            task_id=f'sync_{entity}',
            name=f'meltano-{entity}-worker',
            namespace='meltano',
            image='meltano-pipeline:v1',
            cmds=["/bin/sh", "-c"],
            arguments=[f"meltano --environment=prod run tap-csv--{entity} target-postgres"],
            volumes=[pvc_volume],
            volume_mounts=[pvc_volume_mount],
            secrets=[secret_user, secret_password, secret_db],
            env_vars={
                'TARGET_POSTGRES_HOST': 'postgres-service.postgres.svc.cluster.local',
                'TARGET_POSTGRES_PORT': '5432',
            },
            retries=3,
            retry_delay=timedelta(minutes=2),
            retry_exponential_backoff=True,
        )

        sensor_tasks[entity] >> sync_tasks[entity]

    cross_downstream(
        [sync_tasks["agencias"], sync_tasks["colaboradores"], sync_tasks["colaborador_agencia"]], 
        [sync_tasks["clientes"], sync_tasks["contas"], sync_tasks["propostas_credito"]]
    )

    [sync_tasks["clientes"], sync_tasks["contas"], sync_tasks["propostas_credito"]] >> sync_tasks["transacoes"]

    trigger_analisys = TriggerDagRunOperator(
        task_id="trigger_analisys_dag",
        trigger_dag_id="analise_churn_risk_dag", 
        wait_for_completion=False, 
    )

    sync_tasks["transacoes"] >> trigger_analisys
