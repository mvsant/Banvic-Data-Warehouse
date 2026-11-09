resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_persistent_volume_v1" "logs" {
  metadata {
    name = "airflow-logs-pv"
    labels = {
      app = "airflow-logs"
    }
  }

  spec {
    capacity = {
      storage = var.logs_storage_size
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = var.logs_node_storage_path
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "logs" {
  metadata {
    name      = "airflow-logs-pvc"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.logs.metadata[0].name

    resources {
      requests = {
        storage = var.logs_storage_size
      }
    }
  }
}

resource "kubernetes_secret" "metadata" {
  metadata {
    name      = "airflow-metadata"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  type = "Opaque"
  data = {
    connection = "postgresql+psycopg2://${urlencode(var.airflow_user)}:${urlencode(var.airflow_password)}@${var.postgres_service_host}:${var.postgres_service_port}/${urlencode(var.airflow_database)}"
  }
}

resource "kubernetes_secret" "banvic_connection" {
  metadata {
    name      = "airflow-banvic-connection"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  type = "Opaque"
  data = {
    AIRFLOW_CONN_BANVIC_POSTGRES = "postgresql://${urlencode(var.banvic_user)}:${urlencode(var.banvic_password)}@${var.postgres_service_host}:${var.postgres_service_port}/${urlencode(var.banvic_database)}"
  }
}

resource "kubernetes_role_binding" "meltano" {
  metadata {
    name      = "airflow-meltano-binding"
    namespace = var.meltano_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = var.meltano_airflow_role_name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.worker_service_account_name
    namespace = kubernetes_namespace.this.metadata[0].name
  }
}

resource "helm_release" "this" {
  name       = var.release_name
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name
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
        metadataSecretName = kubernetes_secret.metadata.metadata[0].name
      }

      extraEnvFrom = yamlencode([{
        secretRef = {
          name = kubernetes_secret.banvic_connection.metadata[0].name
        }
      }])

      logs = {
        persistence = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.logs.metadata[0].name
        }
      }

      volumes = [
        {
          name = "local-dags"
          hostPath = {
            path = var.dags_node_path
            type = "Directory"
          }
        }
      ]

      volumeMounts = [
        {
          name      = "local-dags"
          mountPath = "/opt/airflow/dags"
          readOnly  = true
        }
      ]

      workers = {
        serviceAccount = {
          name = var.worker_service_account_name
        }
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
          enabled = false
        }
      }
    })
  ]

  depends_on = [
    kubernetes_role_binding.meltano,
    kubernetes_persistent_volume_claim_v1.logs,
  ]
}
