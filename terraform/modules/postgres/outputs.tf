output "service_host" {
  description = "Internal PostgreSQL service DNS name"
  value       = "${kubernetes_service.this.metadata[0].name}.${kubernetes_namespace.this.metadata[0].name}.svc.cluster.local"
}

output "service_port" {
  description = "Internal PostgreSQL service port"
  value       = kubernetes_service.this.spec[0].port[0].port
}
