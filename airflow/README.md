# Airflow

The current Terraform deployment is managed by `terraform/platform/`. It installs the official Apache Airflow Helm chart 1.22.0 (Airflow 3.2.2), with `LocalExecutor`, in namespace `airflow`. The Kind node bind-mounts the local `airflow/dags/` directory, which the API server, scheduler, DAG processor, and triggerer mount read-only. Saving a DAG locally makes it available to Airflow without rebuilding an image.

The chart's bundled PostgreSQL is disabled. Airflow uses the dedicated `airflow` metadata database and least-privilege user created in PostgreSQL in namespace `postgres`. A separate `banvic_postgres` connection uses the least-privilege Banvic database user and is shared with Meltano. Task logs are mounted from the persistent `airflow-logs` PVC.

Provide the PostgreSQL administrator, Airflow database, and Airflow UI administrator passwords using the `TF_VAR_*` environment variables or the ignored `terraform/platform/terraform.tfvars` file. Do not put credentials in DAG files. Terraform state and Helm release state contain credentials and must remain private.

The Kind cluster must be created with the local DAG mount:

```bash
terraform -chdir=terraform/kind apply
terraform -chdir=terraform/platform plan -input=false
terraform -chdir=terraform/platform apply -input=false
```

The manual `postgres_connectivity_test` DAG checks the `banvic_postgres` connection. The manual `meltano_help` DAG runs `meltano --environment=prod --help` in a Meltano pod and triggers `meltano_dragon`, which runs the `dragon` example command. Both run in the `meltano` namespace from `/project` in the container. The extraction DAG runs one short-lived Meltano pod per source CSV and loads data into the Banvic PostgreSQL database; no downstream output stage is configured.

The local bind mount is part of the Kind cluster definition. Applying this change to an already-created cluster requires recreating the cluster, which deletes data stored only inside its node. Back up PostgreSQL and Airflow logs before applying any plan that replaces the cluster.

See [`terraform/platform/README.md`](../terraform/platform/README.md) for deployment, credentials, persistence, and port-forwarding instructions.
