resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "bootstrap" {
  metadata {
    name      = "postgres-bootstrap"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  type = "Opaque"
  data = {
    POSTGRES_USER     = var.administrator_user
    POSTGRES_PASSWORD = var.administrator_password
    POSTGRES_DB       = "postgres"
    BANVIC_USER       = var.banvic_user
    BANVIC_PASSWORD   = var.banvic_password
    BANVIC_DB         = var.banvic_database
    AIRFLOW_USER      = var.airflow_user
    AIRFLOW_PASSWORD  = var.airflow_password
    AIRFLOW_DB        = var.airflow_database
  }

  lifecycle {
    precondition {
      condition = (
        var.banvic_user != var.administrator_user &&
        var.airflow_user != var.administrator_user &&
        var.banvic_user != var.airflow_user &&
        var.banvic_database != "postgres" &&
        var.airflow_database != "postgres" &&
        var.banvic_database != var.airflow_database
      )
      error_message = "Use distinct administrator/application users and distinct database names; neither application database may be named postgres."
    }
  }
}

resource "kubernetes_persistent_volume_v1" "data" {
  metadata {
    name = "banvic-postgres-pv"
    labels = {
      app = "banvic-postgres"
    }
  }

  spec {
    capacity = {
      storage = var.storage_size
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = var.node_storage_path
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = "banvic-postgres-data"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.data.metadata[0].name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = "banvic-postgres"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app = "banvic-postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "banvic-postgres"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "banvic-postgres"
        }
      }

      spec {
        container {
          name              = "postgres"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5432
            name           = "postgres"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.bootstrap.metadata[0].name
            }
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.administrator_user, "-d", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 6
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.administrator_user, "-d", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgres-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_rollout = true
}

resource "kubernetes_service" "this" {
  metadata {
    name      = "postgres-service"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app = "banvic-postgres"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }

    selector = {
      app = "banvic-postgres"
    }
  }
}

resource "kubernetes_config_map_v1" "init" {
  metadata {
    name      = "postgres-database-init"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    "init.sql" = file("${path.module}/../../../k8s/postgres/init.sql")
  }
}

resource "kubernetes_job_v1" "database_init" {
  metadata {
    name      = "postgres-database-init"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    backoff_limit = 5

    template {
      metadata {
        labels = {
          app = "postgres-database-init"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name              = "database-init"
          image             = var.image
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/sh", "-ec"]
          args = [
            "export PGPASSWORD=\"$POSTGRES_PASSWORD\"; until pg_isready -h postgres-service.${var.namespace}.svc.cluster.local -U \"$POSTGRES_USER\"; do sleep 2; done; exec psql -X -v ON_ERROR_STOP=1 -h postgres-service.${var.namespace}.svc.cluster.local -U \"$POSTGRES_USER\" -d postgres -f /scripts/init.sql"
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret.bootstrap.metadata[0].name
            }
          }

          volume_mount {
            name       = "init-script"
            mount_path = "/scripts"
            read_only  = true
          }
        }

        volume {
          name = "init-script"
          config_map {
            name = kubernetes_config_map_v1.init.metadata[0].name
          }
        }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [
      kubernetes_config_map_v1.init,
      kubernetes_secret.bootstrap,
    ]
  }

  wait_for_completion = true

  depends_on = [kubernetes_deployment_v1.this, kubernetes_service.this]

  timeouts {
    create = "10m"
    update = "10m"
  }
}
