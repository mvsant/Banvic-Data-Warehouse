# Kind

This Terraform root creates a Kind cluster running Kubernetes `v1.36.1`, loads the locally built image `meltano-pipeline:v1`, and bind-mounts the repository's `airflow/dags/` directory into the control-plane node at `/mnt/banvic-source/airflow-dags`.

Requirements: Terraform, Docker Desktop using Linux containers, and Docker Desktop WSL integration enabled for Ubuntu.

From Ubuntu/WSL, with Docker Desktop running and WSL integration enabled, build the local image first:

```bash
docker build -t meltano-pipeline:v1 -f meltano/Dockerfile meltano
```

Then provision the cluster and load the image:

```bash
terraform -chdir=terraform/kind init
terraform -chdir=terraform/kind plan
terraform -chdir=terraform/kind apply
```

The host bind mount is read-only in the Kind node. The Airflow Helm release mounts it read-only into its API server, scheduler, DAG processor, and triggerer. Saving a DAG locally updates the files visible to Airflow without rebuilding an image or running Terraform.

Review the plan before applying. Adding the local DAG bind mount to an existing cluster replaces it and deletes data stored only inside the node. Back up PostgreSQL and Airflow logs before applying any plan that replaces `kind_cluster.default`.

No Airflow, Meltano, PostgreSQL, namespaces, or application workloads are created by this Terraform root.
