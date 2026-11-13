# Airflow

The current Terraform deployment is managed by `terraform/platform/`. It installs the official Apache Airflow Helm chart 1.22.0 (Airflow 3.2.2), with `LocalExecutor`, in namespace `airflow`. Terraform packages the local `airflow/dags/*.py` files into a ConfigMap mounted read-only by the API server, scheduler, DAG processor, and triggerer. After adding or editing a DAG, run `terraform -chdir=terraform/platform apply` to update the ConfigMap and refresh Airflow; no Kind recreation or image rebuild is needed.

The chart's bundled PostgreSQL is disabled. Airflow uses the dedicated `airflow` metadata database and least-privilege user created in PostgreSQL in namespace `postgres`. A separate `banvic_postgres` connection uses the least-privilege Banvic database user and is shared with Meltano. Task logs are mounted from the persistent `airflow-logs` PVC.

Provide the PostgreSQL administrator, Airflow database, and Airflow UI administrator passwords using the `TF_VAR_*` environment variables or the ignored `terraform/platform/terraform.tfvars` file. Do not put credentials in DAG files. Terraform state and Helm release state contain credentials and must remain private.

The Kind cluster must be created with the local DAG and source-data mounts:

```bash
terraform -chdir=terraform/kind apply
terraform -chdir=terraform/platform plan -input=false
terraform -chdir=terraform/platform apply -input=false
```

The manual `postgres_connectivity_test` DAG checks the `banvic_postgres` connection. The manual `meltano_help` DAG runs `meltano --environment=prod --help` in a Meltano pod and triggers `meltano_dragon`, which runs the `dragon` example command. Both run in the `meltano` namespace from `/project` in the container.

The manual `sync_sources_then_extract` DAG validates and copies the current required CSVs from the Kind node's read-only `data/` bind mount into the Meltano PVC, then triggers `extract_pipeline`. The extraction DAG contains only the per-stream Meltano tasks and their original stage dependencies: `agencias`, `colaboradores`, and `colaborador_agencia` run first; `clientes`, `contas`, and `propostas_credito` wait for that stage; `transacoes` runs last. Each task uses the shared `tap-csv` definition from `meltano/meltano.yml` and sets `TAP_CSV__SELECT` to ingest only its stream. Use `bash scripts/setup.sh` to stage current CSVs directly into the PVC when the existing Kind node's source bind mount is empty.

The separate manual `meltano_select` DAG loads only `colaboradores` from the Meltano PVC, passing CSV values directly from `tap-csv` to `target-postgres`. Run `bash scripts/setup.sh` first to stage the current CSVs into the PVC. The DAG performs runtime stream selection and does not change `meltano.yml`.

The complete Meltano project, including future `transform/` dbt files, is packaged in the image. No downstream dbt stage is configured yet.

All DAGs are manual (`schedule=None`) and have descriptions and tags for discovery in the Airflow UI. The extraction pods validate their input file, retry failures, read PostgreSQL host/port from the Airflow `banvic_postgres` connection using Jinja, and receive database user/password/name from the Kubernetes Secret. The Airflow scheduler has only namespace-scoped permissions to create, patch, and monitor task pods in `meltano`.

See the [architecture and demo guide](../docs/architecture-and-demo.md) for diagrams, setup, and a walkthrough of the Terraform, Meltano, and loaded database.

The local DAG and source-data bind mounts are part of the Kind cluster definition. Applying these mounts to an already-created cluster requires recreating the cluster, which deletes data stored only inside its node. Back up PostgreSQL, the Meltano source PVC, and Airflow logs before applying any plan that replaces the cluster.

See [`terraform/platform/README.md`](../terraform/platform/README.md) for deployment, credentials, persistence, and port-forwarding instructions.
