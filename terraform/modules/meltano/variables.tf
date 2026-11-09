variable "namespace" {
  type        = string
  description = "Persistent namespace for Meltano workloads and input data"
}

variable "storage_size" {
  type        = string
  description = "Persistent volume size for CSV inputs"
}

variable "node_storage_path" {
  type        = string
  description = "Host path on the Kind node for CSV input data"
}

variable "postgres_host" {
  type        = string
  description = "PostgreSQL service hostname"
}

variable "postgres_port" {
  type        = number
  description = "PostgreSQL service port"
}

variable "postgres_user" {
  type        = string
  description = "Least-privilege Banvic database user"
}

variable "postgres_password" {
  type        = string
  description = "Banvic database user password"
  sensitive   = true
}

variable "postgres_database" {
  type        = string
  description = "Banvic data warehouse database name"
}
