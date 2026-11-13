# Kind

This Terraform root creates a Kind cluster running Kubernetes `v1.36.1`, loads the locally built image `meltano-pipeline:v1`, and bind-mounts the repository's `airflow/dags/` and `data/` directories into the control-plane node. The Airflow pods use the DAG mount; the extraction DAG's sync pod reads current source CSVs from `/mnt/banvic-source/data`.

Requirements: Terraform, Kind CLI v0.32.0 or newer, Docker Desktop using Linux containers, and Docker Desktop WSL integration enabled for Ubuntu. Kind v0.32.0 added support for the containerd config v4 used by this node image; older Kind CLIs fail when loading local images.

To update the Kind CLI in WSL without replacing the existing cluster:

```bash
curl -fsSLo /tmp/kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
chmod +x /tmp/kind
sudo install /tmp/kind /usr/local/bin/kind
rm /tmp/kind
kind version
```

This command is for WSL on x86_64. Download the matching binary for another architecture from the [Kind installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries).

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

Both host bind mounts are read-only in the Kind node. The Airflow Helm release mounts the DAG folder read-only into its API server, scheduler, DAG processor, and triggerer. The sync task mounts the source-data directory read-only and writes CSVs into the Meltano PVC. Saving a DAG locally updates the files visible to Airflow without rebuilding an image; updating CSVs in `data/` is picked up on the next manual `extract_pipeline` run.

When using Docker Desktop from WSL with the repository under `/mnt/<drive>/`, use those WSL paths directly for `airflow_dags_host_path` and `source_data_host_path`; translating them to `/run/desktop/mnt/host/...` can bind an empty directory. The setup script stages CSVs into the Meltano PVC directly, so it can refresh an existing cluster without replacing it. The `sync_sources_then_extract` DAG depends on the Kind source-data bind mount and therefore requires a cluster created with the corrected path.

Review the plan before applying. Adding either local bind mount to an existing cluster replaces it and deletes data stored only inside the node. Back up PostgreSQL, Meltano source files, and Airflow logs before applying any plan that replaces `kind_cluster.default`. After replacement, apply `terraform/platform/` again to recreate the namespaces and PVCs before running `scripts/setup.sh`.

No Airflow, Meltano, PostgreSQL, namespaces, or application workloads are created by this Terraform root.
