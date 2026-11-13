variable "airflow_dags_host_path" {
  type        = string
  description = "DAG directory path visible to Docker; relative paths resolve from the Kind Terraform root"
  default     = "../../airflow/dags"
}

variable "airflow_dags_node_path" {
  type        = string
  description = "Path where local DAG files are mounted inside the Kind node"
  default     = "/mnt/banvic-source/airflow-dags"
}

variable "source_data_host_path" {
  type        = string
  description = "Source data directory path visible to Docker; relative paths resolve from the Kind Terraform root"
  default     = "../../data"
}
