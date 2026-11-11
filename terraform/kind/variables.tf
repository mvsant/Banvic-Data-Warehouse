variable "airflow_dags_host_path" {
  type        = string
  description = "Path to local DAG files relative to the Kind Terraform root"
  default     = "../../airflow/dags"
}

variable "airflow_dags_node_path" {
  type        = string
  description = "Path where local DAG files are mounted inside the Kind node"
  default     = "/mnt/banvic-source/airflow-dags"
}
