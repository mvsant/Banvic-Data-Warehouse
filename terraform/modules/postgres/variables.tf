variable "namespace" {
  type        = string
  description = "Namespace for PostgreSQL"
}

variable "image" {
  type        = string
  description = "PostgreSQL container image"
}

variable "storage_size" {
  type        = string
  description = "Persistent PostgreSQL data volume size"
}

variable "node_storage_path" {
  type        = string
  description = "Host path on the Kind node for PostgreSQL data"
}

variable "administrator_user" {
  type        = string
  description = "Bootstrap administrator username"
}

variable "administrator_password" {
  type        = string
  description = "Bootstrap administrator password"
  sensitive   = true
}

variable "banvic_user" {
  type        = string
  description = "Application user for the Banvic database"
}

variable "banvic_password" {
  type        = string
  description = "Application password for the Banvic database"
  sensitive   = true
}

variable "banvic_database" {
  type        = string
  description = "Banvic data warehouse database name"
}

variable "airflow_user" {
  type        = string
  description = "Application user for the Airflow metadata database"
}

variable "airflow_password" {
  type        = string
  description = "Application password for the Airflow metadata database"
  sensitive   = true
}

variable "airflow_database" {
  type        = string
  description = "Airflow metadata database name"
}
