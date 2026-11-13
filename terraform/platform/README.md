# Airflow and PostgreSQL on the existing Kind cluster

This root deploys only PostgreSQL and Apache Airflow into the existing `banvic-warehouse` Kind cluster. PostgreSQL runs in namespace `postgres`; Airflow runs in namespace `airflow` and uses the separately managed `airflow` database in PostgreSQL. The Airflow Helm chart's bundled PostgreSQL is disabled.

The chart is pinned to `1.22.0` (Airflow `3.2.2`), the current stable release checked for this configuration. Apache Airflow does not designate a formal LTS release line.

## Requirements

- The existing Kind cluster must be running Kubernetes `v1.36.1`.
- Docker Desktop must be running with Linux containers and WSL integration enabled.
- Terraform and Helm are required. Terraform manages Helm releases directly.

Refresh the kubeconfig for the existing cluster if needed:

```bash
kind export kubeconfig --name banvic-warehouse --kubeconfig terraform/kind/kubeconfig
```

Provide four independent passwords either in a local, ignored `terraform.tfvars` file or as `TF_VAR_*` environment variables. The Banvic database password is shared by the Meltano target and the Airflow connection `Banvic_Postgres`. To use the example file, copy it and replace all placeholder values:

```bash
cp terraform/platform/terraform.example.tfvars terraform/platform/terraform.tfvars
```

Alternatively, enter passwords without echoing them in the current WSL shell:

```bash
read -r -s -p "PostgreSQL administrator password: " TF_VAR_postgres_admin_password; printf '\n'
export TF_VAR_postgres_admin_password
read -r -s -p "Airflow database password: " TF_VAR_airflow_db_password; printf '\n'
export TF_VAR_airflow_db_password
read -r -s -p "Airflow UI administrator password: " TF_VAR_airflow_admin_password; printf '\n'
export TF_VAR_airflow_admin_password
read -r -s -p "Banvic database password: " TF_VAR_banvic_password; printf '\n'
export TF_VAR_banvic_password
```

Initialize, review, and apply the platform plan:

```bash
terraform -chdir=terraform/platform init
terraform -chdir=terraform/platform plan -input=false -out=.terraform/platform.tfplan
terraform -chdir=terraform/platform apply -input=false .terraform/platform.tfplan
```

Do not commit `terraform.tfvars`, Terraform state, or saved plan files. Terraform state and the Helm release state contain credentials. Kubernetes Secrets are created for PostgreSQL, the Airflow metadata connection, and the shared Banvic database credentials/connection. The initial Airflow UI user is configured from the sensitive Terraform variable. The PostgreSQL bootstrap creates separate least-privilege users and databases for Airflow metadata (`airflow`) and the Banvic warehouse (`banvic`).

## Meltano ELT

The platform root creates the `meltano` namespace and a PVC for source CSV files. Run the setup script after provisioning the platform to validate the input files and build/load the complete Meltano project image:

```bash
bash scripts/setup.sh
```

The script uses a temporary empty Docker client config while building the public Meltano base image, loads `meltano-pipeline:v1` into an existing Kind cluster, and copies the current CSVs directly into the Meltano PVC. This avoids relying on the source bind mount when refreshing an existing cluster. Use Kind CLI v0.32.0 or newer for image loading with the containerd config v4 in this cluster's node image; set `KIND_BIN` to that binary if the default `kind` command is older. The script does not recreate an existing cluster.

The manual `sync_sources_then_extract` DAG syncs current CSVs from the Kind node's read-only local `data/` bind mount into the Meltano PVC, then triggers `extract_pipeline`; that mount must point to the WSL-native `/mnt/<drive>/.../data` path. The extraction DAG launches one short-lived Meltano pod per CSV stream in the `meltano` namespace and preserves the original dependency stages. Each Meltano pod mounts the CSV PVC read-only at `/project/extract`, selects one stream from the shared `tap-csv` definition using `TAP_CSV__SELECT`, and runs `tap-csv` directly into `target-postgres`. The separate manual `meltano_select` DAG loads only `colaboradores` from the PVC, which `scripts/setup.sh` refreshes. PostgreSQL host/port are rendered from Airflow's `banvic_postgres` connection; credentials are injected directly from the Kubernetes Secret. The pipeline loads data into the `banvic` database. No downstream dbt stage is configured yet.

## Persistence and access

- PostgreSQL data: `postgres/postgres-data` PVC.
- Source CSV files: `scripts/setup.sh` copies current local `data/` files into `meltano/meltano-data-pvc`; Meltano task pods mount it at `/project/extract`.
- Airflow task logs: `airflow/airflow-logs` PVC. The chart mounts this shared claim into Airflow components.
- Terraform initializes the shared log volume permissions for Airflow's UID/GID before starting the chart Pods.
- The static PVs use paths inside the Linux filesystem of the Kind node, not Windows bind mounts. Data survives pod restarts and Terraform changes that retain the PVCs, but deleting the Kind cluster deletes the node-local data. Back up the database and logs before destroying the cluster.
- The Airflow chart uses `LocalExecutor`, disables its bundled PostgreSQL and Redis, and runs migrations against the external PostgreSQL database.
- The Airflow scheduler has a namespace-scoped Role permitting it to create, inspect, read logs from, and delete Meltano task pods. It has no broader cluster permissions.
- The Role also permits `patch` on pods, which the KubernetesPodOperator uses to update task-pod metadata after creation.
- The Kind node bind-mounts local `airflow/dags/` and `data/`; Airflow components mount the DAG folder read-only, and the sync task reads source CSVs from the node's `/mnt/banvic-source/data`. Saving a DAG locally makes it available without building an image or running Terraform again. Updating CSVs is picked up by the next DAG run.
- Adding a bind mount to an existing Kind cluster requires replacing the cluster. Back up PostgreSQL, Meltano source files, and Airflow logs first; node-local data is lost when that cluster is replaced.

Open the Airflow UI with:

```bash
kubectl --kubeconfig terraform/kind/kubeconfig port-forward -n airflow svc/airflow-api-server 8080:8080
```

Then visit `http://localhost:8080` and sign in with `airflow_admin_user` and `airflow_admin_password`.
