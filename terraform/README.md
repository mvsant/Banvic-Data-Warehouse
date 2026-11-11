# Terraform

- [`kind/`](kind/README.md) provisions the `banvic-warehouse` Kind cluster and loads the local Meltano image.
- [`platform/`](platform/README.md) deploys PostgreSQL and Apache Airflow into that existing cluster.

Run the roots in order from Ubuntu/WSL with Docker Desktop running and WSL integration enabled. The Kind cluster bind-mounts local `airflow/dags/` so saved DAG changes are visible without rebuilding an image or reapplying Terraform. Adding this mount to an existing cluster requires replacement and loses node-local data; back up PostgreSQL and logs before applying any replacement plan.

```bash
terraform -chdir=terraform/platform init
terraform -chdir=terraform/platform plan -input=false
```

Provide the credentials described in [`platform/README.md`](platform/README.md) before planning. Review the plan before applying.
