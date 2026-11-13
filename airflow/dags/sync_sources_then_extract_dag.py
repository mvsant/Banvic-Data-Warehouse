from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from kubernetes.client import models as k8s

SOURCE_FILES = (
    "agencias.csv",
    "colaboradores.csv",
    "colaborador_agencia.csv",
    "clientes.csv",
    "contas.csv",
    "propostas_credito.csv",
    "transacoes.csv",
)

source_data_volume = k8s.V1Volume(
    name="source-data-volume",
    host_path=k8s.V1HostPathVolumeSource(
        path="/mnt/banvic-source/data",
        type="Directory",
    ),
)
source_data_volume_mount = k8s.V1VolumeMount(
    name="source-data-volume",
    mount_path="/source",
    read_only=True,
)
persistent_data_volume = k8s.V1Volume(
    name="meltano-data-volume",
    persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
        claim_name="meltano-data-pvc",
    ),
)
persistent_data_volume_mount = k8s.V1VolumeMount(
    name="meltano-data-volume",
    mount_path="/project/extract",
)

with DAG(
    dag_id="sync_sources_then_extract",
    description="Copy the current source CSVs to the Meltano PVC, then trigger extract_pipeline.",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["meltano", "extract", "sync"],
) as dag:
    sync_source_files = KubernetesPodOperator(
        task_id="sync_source_files",
        name="meltano-source-sync",
        namespace="meltano",
        image="meltano-pipeline:v1",
        image_pull_policy="IfNotPresent",
        cmds=["/bin/sh", "-ec"],
        arguments=[
            f"""
            for filename in {" ".join(SOURCE_FILES)}; do
                if [ ! -s "/source/$filename" ]; then
                    echo "Required source file is missing or empty: $filename" >&2
                    exit 1
                fi
            done

            mkdir -p /project/extract
            for filename in {" ".join(SOURCE_FILES)}; do
                sed -E \
                    's/([0-9]{{4}}-[0-9]{{2}}-[0-9]{{2}}) ([0-9]{{2}}:[0-9]{{2}}:[0-9]{{2}}) UTC/\\1T\\2+00:00/g' \
                    "/source/$filename" > "/project/extract/$filename"
            done
            echo "Synced current source CSV files and normalized UTC timestamps"
            """,
        ],
        volumes=[source_data_volume, persistent_data_volume],
        volume_mounts=[source_data_volume_mount, persistent_data_volume_mount],
        retries=2,
        retry_delay=timedelta(minutes=1),
    )

    trigger_extract_pipeline = TriggerDagRunOperator(
        task_id="trigger_extract_pipeline",
        trigger_dag_id="extract_pipeline",
        wait_for_completion=False,
    )

    sync_source_files >> trigger_extract_pipeline
