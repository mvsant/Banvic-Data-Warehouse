output "airflow_namespace" {
  description = "Namespace hosting Airflow"
  value       = kubernetes_namespace_v1.airflow.metadata[0].name
}

output "airflow_service" {
  description = "Airflow API server service"
  value       = "airflow-api-server.${kubernetes_namespace_v1.airflow.metadata[0].name}.svc.cluster.local"
}

output "postgres_namespace" {
  description = "Namespace hosting PostgreSQL and the Airflow metadata database"
  value       = kubernetes_namespace_v1.postgres.metadata[0].name
}

output "postgres_service" {
  description = "PostgreSQL service used by Airflow"
  value       = "postgres.${kubernetes_namespace_v1.postgres.metadata[0].name}.svc.cluster.local:5432"
}
