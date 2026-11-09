terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.13.0"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "banvic" {
  name            = var.cluster_name
  node_image      = var.node_image
  wait_for_ready  = true
  kubeconfig_path = abspath("${path.root}/${var.kubeconfig_path}")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_mounts {
        host_path      = abspath("${path.root}/${var.persistence_host_path}")
        container_path = "/mnt/banvic-persistence"
      }

      extra_mounts {
        host_path      = abspath("${path.root}/${var.airflow_dags_host_path}")
        container_path = var.airflow_dags_node_path
        read_only      = true
      }
    }
  }
}

output "kubectl_context" {
  description = "Context name for the Banvic Kind cluster"
  value       = kind_cluster.banvic.context_name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig"
  value       = kind_cluster.banvic.kubeconfig_path
}
