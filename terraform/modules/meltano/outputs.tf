output "namespace" {
  description = "Persistent namespace for Meltano workloads"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "airflow_role_name" {
  description = "Role used by Airflow to launch Meltano pods"
  value       = kubernetes_role.airflow_pod_manager.metadata[0].name
}

output "input_pvc_name" {
  description = "PVC storing synchronized CSV input data"
  value       = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
}
