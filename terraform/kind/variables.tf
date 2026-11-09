variable "cluster_name" {
  type        = string
  description = "Name of the local Kind cluster"
  default     = "banvic"
}

variable "node_image" {
  type        = string
  description = "Kind node image, including its Kubernetes version"
  default     = "kindest/node:v1.31.0"
}

variable "kubeconfig_path" {
  type        = string
  description = "Kubeconfig output path relative to this Terraform root"
  default     = "kubeconfig"
}

variable "persistence_host_path" {
  type        = string
  description = "Local directory mounted for persistent database, CSV, and log data"
  default     = "../../.kind-data"
}

variable "airflow_dags_host_path" {
  type        = string
  description = "Local airflow/dags directory mounted into the Kind node"
  default     = "../../airflow/dags"
}

variable "airflow_dags_node_path" {
  type        = string
  description = "Mount path for local DAGs inside the Kind node"
  default     = "/mnt/banvic-source/airflow-dags"
}
