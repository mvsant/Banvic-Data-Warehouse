output "namespace" {
  description = "Namespace hosting Airflow"
  value       = kubernetes_namespace.this.metadata[0].name
}
