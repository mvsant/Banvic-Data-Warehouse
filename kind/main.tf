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
  name            = "banvic"
  node_image      = "kindest/node:v1.31.0"
  wait_for_ready  = true
  kubeconfig_path = "${path.root}/kubeconfig"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_mounts {
        host_path      = abspath("${path.root}/../.kind-data")
        container_path = "/mnt/banvic-persistence"
      }
    }
  }
}

output "kubectl_context" {
  description = "Context name for the Banvic Kind cluster"
  value       = kind_cluster.banvic.context_name
}
