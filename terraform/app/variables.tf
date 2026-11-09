variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig created by the Kind Terraform root"
  default     = "../kind/kubeconfig"
}

variable "postgres_namespace" {
  type        = string
  description = "Namespace for PostgreSQL and its bootstrap resources"
  default     = "postgres"
}

variable "meltano_namespace" {
  type        = string
  description = "Persistent namespace for Meltano workloads and input data"
  default     = "meltano"
}

variable "airflow_namespace" {
  type        = string
  description = "Namespace for Airflow"
  default     = "airflow"
}

variable "postgres_image" {
  type        = string
  description = "PostgreSQL container image"
  default     = "postgres:16-alpine"
}

variable "postgres_storage_size" {
  type        = string
  description = "Persistent PostgreSQL data volume size"
  default     = "5Gi"
}

variable "postgres_node_storage_path" {
  type        = string
  description = "Path on the Kind node used for PostgreSQL data"
  default     = "/mnt/banvic-persistence/postgres"
}

variable "meltano_storage_size" {
  type        = string
  description = "Persistent volume size for CSV inputs"
  default     = "2Gi"
}

variable "meltano_node_storage_path" {
  type        = string
  description = "Path on the Kind node used for Meltano input data"
  default     = "/mnt/banvic-persistence/meltano"
}

variable "airflow_logs_storage_size" {
  type        = string
  description = "Persistent Airflow task log volume size"
  default     = "2Gi"
}

variable "airflow_logs_node_storage_path" {
  type        = string
  description = "Path on the Kind node used for Airflow logs"
  default     = "/mnt/banvic-persistence/airflow-logs"
}

variable "airflow_dags_node_path" {
  type        = string
  description = "Kind-node path mounted from the local airflow/dags directory"
  default     = "/mnt/banvic-source/airflow-dags"
}

variable "airflow_release_name" {
  type        = string
  description = "Helm release name for Airflow"
  default     = "banvic-release"
}

variable "airflow_chart_version" {
  type        = string
  description = "Apache Airflow Helm chart version"
  default     = "1.22.0"
}

variable "airflow_worker_service_account" {
  type        = string
  description = "Airflow worker service account allowed to launch Meltano pods"
  default     = "banvic-release-airflow-worker"
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL administrator username used only for database initialization"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL administrator password"
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  description = "Banvic data warehouse database name"
}

variable "banvic_user" {
  type        = string
  description = "Least-privilege user for the Banvic data warehouse"
  default     = "banvic_app"
}

variable "banvic_password" {
  type        = string
  description = "Password for the Banvic data warehouse user"
  sensitive   = true
}

variable "airflow_user" {
  type        = string
  description = "User for the Airflow metadata database"
  default     = "airflow"
}

variable "airflow_password" {
  type        = string
  description = "Password for the Airflow metadata database user"
  sensitive   = true
}

variable "airflow_db" {
  type        = string
  description = "Airflow metadata database name"
  default     = "airflow"
}
