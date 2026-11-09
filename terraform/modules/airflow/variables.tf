variable "namespace" {
  type        = string
  description = "Namespace for Airflow"
}

variable "release_name" {
  type        = string
  description = "Helm release name"
}

variable "chart_version" {
  type        = string
  description = "Apache Airflow Helm chart version"
}

variable "postgres_service_host" {
  type        = string
  description = "PostgreSQL service hostname"
}

variable "postgres_service_port" {
  type        = number
  description = "PostgreSQL service port"
}

variable "airflow_user" {
  type        = string
  description = "Airflow metadata database user"
}

variable "airflow_password" {
  type        = string
  description = "Airflow metadata database password"
  sensitive   = true
}

variable "airflow_database" {
  type        = string
  description = "Airflow metadata database name"
}

variable "banvic_user" {
  type        = string
  description = "Banvic database user"
}

variable "banvic_password" {
  type        = string
  description = "Banvic database password"
  sensitive   = true
}

variable "banvic_database" {
  type        = string
  description = "Banvic data warehouse database name"
}

variable "logs_storage_size" {
  type        = string
  description = "Persistent Airflow task log volume size"
}

variable "logs_node_storage_path" {
  type        = string
  description = "Host path on the Kind node for Airflow logs"
}

variable "dags_node_path" {
  type        = string
  description = "Path on the Kind node mounted from the local DAG directory"
}

variable "meltano_namespace" {
  type        = string
  description = "Namespace in which Airflow runs Meltano pods"
}

variable "meltano_airflow_role_name" {
  type        = string
  description = "RBAC role granting Airflow permission to run Meltano pods"
}

variable "worker_service_account_name" {
  type        = string
  description = "Airflow worker service account used for KubernetesPodOperator"
}
