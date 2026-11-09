output "postgres_service" {
  description = "Internal PostgreSQL service address"
  value       = "${module.postgres.service_host}:${module.postgres.service_port}"
}

output "meltano_namespace" {
  description = "Namespace that persists the Meltano input PVC"
  value       = module.meltano.namespace
}

output "airflow_namespace" {
  description = "Namespace hosting Airflow"
  value       = module.airflow.namespace
}
