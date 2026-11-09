terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "kubernetes" {
  config_path = "${path.module}/kind/kubeconfig"
}

provider "helm" {
  kubernetes = {
    config_path = "${path.module}/kind/kubeconfig"
  }
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL bootstrap administrator username"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL bootstrap administrator password"
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  description = "Banvic data warehouse database name"
}

variable "banvic_user" {
  type        = string
  description = "Least-privilege user for the Banvic data warehouse"
  default     = "banvic_app"
}

variable "banvic_password" {
  type        = string
  description = "Password for the Banvic data warehouse user"
  sensitive   = true
}

variable "airflow_user" {
  type        = string
  description = "User for the Airflow metadata database"
  default     = "airflow"
}

variable "airflow_password" {
  type        = string
  description = "Password for the Airflow metadata database user"
  sensitive   = true
}

variable "airflow_db" {
  type        = string
  description = "Airflow metadata database name"
  default     = "airflow"
}

resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
}

resource "kubernetes_namespace" "meltano" {
  metadata {
    name = "meltano"
  }
}

resource "kubernetes_namespace" "postgres" {
  metadata {
    name = "postgres"
  }
}

resource "kubernetes_persistent_volume_v1" "postgres" {
  metadata {
    name = "banvic-postgres-pv"
    labels = {
      app = "banvic-postgres"
    }
  }

  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/mnt/banvic-persistence/postgres"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  metadata {
    name      = "banvic-database-postgres-pvc"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.postgres.metadata[0].name

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "meltano_csv" {
  metadata {
    name = "meltano-csv-pv"
    labels = {
      app = "meltano-csv"
    }
  }

  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/mnt/banvic-persistence/meltano"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "meltano_csv" {
  metadata {
    name      = "meltano-csv-pvc"
    namespace = kubernetes_namespace.meltano.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.meltano_csv.metadata[0].name

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "airflow_logs" {
  metadata {
    name = "airflow-logs-pv"
    labels = {
      app = "airflow-logs"
    }
  }

  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/mnt/banvic-persistence/airflow-logs"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "airflow_logs" {
  metadata {
    name      = "airflow-logs-pvc"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.airflow_logs.metadata[0].name

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_secret" "postgres_bootstrap" {
  metadata {
    name      = "postgres-bootstrap"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  type = "Opaque"
  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = "postgres"
    BANVIC_USER       = var.banvic_user
    BANVIC_PASSWORD   = var.banvic_password
    BANVIC_DB         = var.postgres_db
    AIRFLOW_USER      = var.airflow_user
    AIRFLOW_PASSWORD  = var.airflow_password
    AIRFLOW_DB        = var.airflow_db
  }

  lifecycle {
    precondition {
      condition = (
        var.banvic_user != var.postgres_user &&
        var.airflow_user != var.postgres_user &&
        var.banvic_user != var.airflow_user &&
        var.postgres_db != "postgres" &&
        var.airflow_db != "postgres" &&
        var.postgres_db != var.airflow_db
      )
      error_message = "Use distinct administrator/application users and distinct database names; neither application database may be named postgres."
    }
  }
}

resource "kubernetes_secret" "banvic_credentials_meltano" {
  metadata {
    name      = "banvic-postgres-credentials"
    namespace = kubernetes_namespace.meltano.metadata[0].name
  }

  type = "Opaque"
  data = {
    POSTGRES_USER     = var.banvic_user
    POSTGRES_PASSWORD = var.banvic_password
    POSTGRES_DB       = var.postgres_db
  }
}

resource "kubernetes_secret" "airflow_metadata" {
  metadata {
    name      = "airflow-metadata"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }

  type = "Opaque"
  data = {
    connection = "postgresql+psycopg2://${urlencode(var.airflow_user)}:${urlencode(var.airflow_password)}@postgres-service.postgres.svc.cluster.local:5432/${urlencode(var.airflow_db)}"
  }
}

resource "kubernetes_secret" "airflow_banvic_connection" {
  metadata {
    name      = "airflow-banvic-connection"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }

  type = "Opaque"
  data = {
    AIRFLOW_CONN_BANVIC_POSTGRES = "postgresql://${urlencode(var.banvic_user)}:${urlencode(var.banvic_password)}@postgres-service.postgres.svc.cluster.local:5432/${urlencode(var.postgres_db)}"
  }
}

resource "kubernetes_pod" "postgres" {
  metadata {
    name      = "banvic-database-postgres-alpine-pod"
    namespace = kubernetes_namespace.postgres.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    container {
      name              = "postgres"
      image             = "postgres:16-alpine"
      image_pull_policy = "IfNotPresent"

      port {
        container_port = 5432
        name           = "postgres"
      }

      env_from {
        secret_ref {
          name = kubernetes_secret.postgres_bootstrap.metadata[0].name
        }
      }

      volume_mount {
        name       = "postgres-data"
        mount_path = "/var/lib/postgresql/data"
      }
    }

    volume {
      name = "postgres-data"

      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.postgres.metadata[0].name
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres-service"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }

    selector = {
      app = "postgres"
    }
  }
}

resource "kubernetes_config_map_v1" "postgres_init" {
  metadata {
    name      = "postgres-database-init"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  data = {
    "init.sql" = file("${path.module}/postgres-init.sql")
  }
}

resource "kubernetes_job_v1" "postgres_database_init" {
  metadata {
    name      = "postgres-database-init"
    namespace = kubernetes_namespace.postgres.metadata[0].name
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
          image             = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/sh", "-ec"]
          args = [
            "export PGPASSWORD=\"$POSTGRES_PASSWORD\"; until pg_isready -h postgres-service.postgres.svc.cluster.local -U \"$POSTGRES_USER\"; do sleep 2; done; exec psql -X -v ON_ERROR_STOP=1 -h postgres-service.postgres.svc.cluster.local -U \"$POSTGRES_USER\" -d postgres -f /scripts/init.sql"
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret.postgres_bootstrap.metadata[0].name
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
            name = kubernetes_config_map_v1.postgres_init.metadata[0].name
          }
        }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [
      kubernetes_config_map_v1.postgres_init,
      kubernetes_secret.postgres_bootstrap,
    ]
  }

  wait_for_completion = true
}

resource "kubernetes_role" "airflow_pod_manager" {
  metadata {
    name      = "airflow-pod-manager-role"
    namespace = kubernetes_namespace.meltano.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "get", "list", "watch", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "get"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "airflow_meltano_binding" {
  metadata {
    name      = "airflow-meltano-binding"
    namespace = kubernetes_namespace.meltano.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.airflow_pod_manager.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "banvic-release-airflow-worker"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }
}

resource "helm_release" "airflow" {
  name       = "banvic-release"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  version    = "1.22.0"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  timeout    = 600
  wait       = true

  set = [
    { name = "createUserJob.useHelmHooks", value = "false" },
    { name = "migrateDatabaseJob.useHelmHooks", value = "false" },
    { name = "dagProcessor.waitForMigrations.enabled", value = "false" },
    { name = "triggerer.waitForMigrations.enabled", value = "false" },
    { name = "worker.waitForMigrations.enabled", value = "false" },
  ]

  values = [
    yamlencode({
      postgresql = {
        enabled = false
      }

      data = {
        metadataSecretName = kubernetes_secret.airflow_metadata.metadata[0].name
      }

      extraEnvFrom = yamlencode([{
        secretRef = {
          name = kubernetes_secret.airflow_banvic_connection.metadata[0].name
        }
      }])

      logs = {
        persistence = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.airflow_logs.metadata[0].name
        }
      }

      workers = {
        persistence = {
          enabled = true
          size    = "1Gi"
        }
      }

      triggerer = {
        persistence = {
          enabled = true
          size    = "1Gi"
        }
      }

      config = {
        logging = {
          remote_logging = "False"
          logging_level  = "INFO"
        }
      }

      dags = {
        persistence = {
          enabled = false
        }

        gitSync = {
          enabled = true
          repo    = "https://github.com/mvsant/Banvic-Data-Warehouse"
          branch  = "main"
          rev     = "HEAD"
          depth   = 1
          subPath = "dags"
          period  = "10s"
        }
      }
    })
  ]

  depends_on = [
    kubernetes_job_v1.postgres_database_init,
    kubernetes_role_binding.airflow_meltano_binding,
    kubernetes_persistent_volume_claim_v1.airflow_logs,
  ]
}
