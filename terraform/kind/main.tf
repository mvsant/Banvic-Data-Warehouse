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

locals {
  airflow_dags_host_path = startswith(var.airflow_dags_host_path, "/") ? var.airflow_dags_host_path : abspath("${path.root}/${var.airflow_dags_host_path}")
  source_data_host_path  = startswith(var.source_data_host_path, "/") ? var.source_data_host_path : abspath("${path.root}/${var.source_data_host_path}")
}

resource "kind_cluster" "default" {
  name           = "banvic-warehouse"
  node_image     = "kindest/node:v1.36.1"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_mounts {
        host_path      = local.airflow_dags_host_path
        container_path = var.airflow_dags_node_path
        read_only      = true
      }

      extra_mounts {
        host_path      = local.source_data_host_path
        container_path = "/mnt/banvic-source/data"
        read_only      = true
      }
    }
  }
}

resource "kind_load" "app" {
  image        = "meltano-pipeline:v1"
  cluster_name = kind_cluster.default.name
}
