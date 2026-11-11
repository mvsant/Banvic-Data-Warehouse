variable "kubeconfig_path" {
  type        = string
  description = "Kubeconfig for the existing Kind cluster"
  default     = "../kind/kubeconfig"
}

variable "postgres_admin_user" {
  type        = string
  description = "PostgreSQL bootstrap administrator"
  default     = "postgres"
}

variable "postgres_admin_password" {
  type        = string
  description = "Password for the PostgreSQL bootstrap administrator"
  sensitive   = true
}

variable "airflow_db_user" {
  type        = string
  description = "Least-privilege PostgreSQL user for Airflow metadata"
  default     = "airflow"
}

variable "airflow_db_password" {
  type        = string
  description = "Password for the Airflow metadata database user"
  sensitive   = true
}

variable "airflow_db_name" {
  type        = string
  description = "Airflow metadata database name"
  default     = "airflow"
}

variable "banvic_user" {
  type        = string
  description = "Least-privilege PostgreSQL user for the Banvic warehouse"
  default     = "banvic_app"
}

variable "banvic_password" {
  type        = string
  description = "Password shared by Meltano and the Airflow Banvic_Postgres connection"
  sensitive   = true
}

variable "banvic_database" {
  type        = string
  description = "PostgreSQL database used by the Banvic ELT pipeline"
  default     = "banvic"
}

variable "airflow_admin_user" {
  type        = string
  description = "Initial Airflow UI administrator username"
  default     = "admin"
}

variable "airflow_admin_password" {
  type        = string
  description = "Initial Airflow UI administrator password"
  sensitive   = true
}

variable "airflow_dags_node_path" {
  type        = string
  description = "Path to local DAGs mounted inside the Kind node"
  default     = "/mnt/banvic-source/airflow-dags"
}

variable "postgres_storage_size" {
  type        = string
  description = "PostgreSQL data volume size"
  default     = "5Gi"
}

variable "meltano_data_storage_size" {
  type        = string
  description = "Persistent volume size for the source CSV files"
  default     = "2Gi"
}

variable "airflow_logs_storage_size" {
  type        = string
  description = "Persistent Airflow task log volume size"
  default     = "2Gi"
}
