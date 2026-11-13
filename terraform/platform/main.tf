terraform {
  required_version = ">= 1.5.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}

provider "kubernetes" {
  config_path = abspath("${path.module}/${var.kubeconfig_path}")
}

provider "helm" {
  kubernetes = {
    config_path = abspath("${path.module}/${var.kubeconfig_path}")
  }
}

locals {
  airflow_dags_dir         = "${path.module}/../../airflow/dags"
  airflow_dag_files        = fileset(local.airflow_dags_dir, "*.py")
  airflow_dags_config_hash = substr(sha256(join("", [for filename in local.airflow_dag_files : file("${local.airflow_dags_dir}/${filename}")])), 0, 8)
}

resource "kubernetes_namespace_v1" "postgres" {
  metadata {
    name = "postgres"
  }
}

resource "kubernetes_namespace_v1" "airflow" {
  metadata {
    name = "airflow"
  }
}

resource "kubernetes_namespace_v1" "meltano" {
  metadata {
    name = "meltano"
  }
}

resource "kubernetes_config_map_v1" "airflow_dags" {
  metadata {
    name      = "airflow-local-dags-${local.airflow_dags_config_hash}"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  data = {
    for filename in local.airflow_dag_files :
    filename => file("${local.airflow_dags_dir}/${filename}")
  }
}

resource "kubernetes_secret_v1" "postgres_admin" {
  metadata {
    name      = "postgres-admin"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  data = {
    POSTGRES_USER     = var.postgres_admin_user
    POSTGRES_PASSWORD = var.postgres_admin_password
    POSTGRES_DB       = "postgres"
  }
}

resource "kubernetes_secret_v1" "airflow_database" {
  metadata {
    name      = "airflow-database"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  data = {
    AIRFLOW_DB_USER     = var.airflow_db_user
    AIRFLOW_DB_PASSWORD = var.airflow_db_password
    AIRFLOW_DB_NAME     = var.airflow_db_name
  }
}

resource "kubernetes_secret_v1" "banvic_database" {
  metadata {
    name      = "banvic-database"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  data = {
    BANVIC_USER     = var.banvic_user
    BANVIC_PASSWORD = var.banvic_password
    BANVIC_DB       = var.banvic_database
  }

  lifecycle {
    precondition {
      condition = (
        var.banvic_user != var.postgres_admin_user &&
        var.airflow_db_user != var.postgres_admin_user &&
        var.banvic_user != var.airflow_db_user &&
        var.banvic_database != "postgres" &&
        var.airflow_db_name != "postgres" &&
        var.banvic_database != var.airflow_db_name
      )
      error_message = "Use distinct admin/application users and distinct database names; application databases cannot be named postgres."
    }
  }
}

resource "kubernetes_secret_v1" "banvic_meltano_credentials" {
  metadata {
    name      = "banvic-postgres-credentials"
    namespace = kubernetes_namespace_v1.meltano.metadata[0].name
  }

  data = {
    POSTGRES_USER     = var.banvic_user
    POSTGRES_PASSWORD = var.banvic_password
    POSTGRES_DB       = var.banvic_database
  }
}

resource "kubernetes_secret_v1" "banvic_airflow_connection" {
  metadata {
    name      = "banvic-postgres-connection"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  data = {
    AIRFLOW_CONN_BANVIC_POSTGRES = "postgresql://${urlencode(var.banvic_user)}:${urlencode(var.banvic_password)}@postgres.postgres.svc.cluster.local:5432/${urlencode(var.banvic_database)}"
  }
}

resource "kubernetes_persistent_volume_v1" "postgres" {
  metadata {
    name = "airflow-postgres-pv"
  }

  spec {
    capacity = {
      storage = var.postgres_storage_size
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/var/local/airflow/postgres"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  metadata {
    name      = "postgres-data"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.postgres.metadata[0].name

    resources {
      requests = {
        storage = var.postgres_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "meltano_data" {
  metadata {
    name = "meltano-data-pv"
  }

  spec {
    capacity = {
      storage = var.meltano_data_storage_size
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/var/local/meltano/data"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "meltano_data" {
  metadata {
    name      = "meltano-data-pvc"
    namespace = kubernetes_namespace_v1.meltano.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.meltano_data.metadata[0].name

    resources {
      requests = {
        storage = var.meltano_data_storage_size
      }
    }
  }
}

resource "kubernetes_role_v1" "airflow_meltano_pod_runner" {
  metadata {
    name      = "airflow-meltano-pod-runner"
    namespace = kubernetes_namespace_v1.meltano.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "patch", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "airflow_meltano_pod_runner" {
  metadata {
    name      = "airflow-meltano-pod-runner"
    namespace = kubernetes_namespace_v1.meltano.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "airflow-scheduler"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.airflow_meltano_pod_runner.metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
    labels = {
      app = "airflow-postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "airflow-postgres"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "airflow-postgres"
        }
      }

      spec {
        container {
          name              = "postgres"
          image             = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "postgres"
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres_admin.metadata[0].name
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_admin_user, "-d", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 12
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_admin_user, "-d", "postgres"]
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
            claim_name = kubernetes_persistent_volume_claim_v1.postgres.metadata[0].name
          }
        }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [kubernetes_secret_v1.postgres_admin]
  }

  wait_for_rollout = true
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  spec {
    selector = {
      app = "airflow-postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }
  }
}

resource "kubernetes_config_map_v1" "database_init" {
  metadata {
    name      = "airflow-database-init"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  data = {
    "init.sql" = file("${path.module}/init-airflow-database.sql")
  }
}

resource "kubernetes_job_v1" "database_init" {
  metadata {
    name      = "airflow-database-init"
    namespace = kubernetes_namespace_v1.postgres.metadata[0].name
  }

  spec {
    backoff_limit = 5

    template {
      metadata {
        labels = {
          app = "airflow-database-init"
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
            "export PGPASSWORD=\"$POSTGRES_PASSWORD\"; until pg_isready -h postgres.postgres.svc.cluster.local -U \"$POSTGRES_USER\"; do sleep 2; done; exec psql -X -v ON_ERROR_STOP=1 -h postgres.postgres.svc.cluster.local -U \"$POSTGRES_USER\" -d postgres -v postgres_user=\"$POSTGRES_USER\" -v airflow_user=\"$AIRFLOW_DB_USER\" -v airflow_password=\"$AIRFLOW_DB_PASSWORD\" -v airflow_db=\"$AIRFLOW_DB_NAME\" -v banvic_user=\"$BANVIC_USER\" -v banvic_password=\"$BANVIC_PASSWORD\" -v banvic_db=\"$BANVIC_DB\" -f /scripts/init.sql"
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres_admin.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.airflow_database.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.banvic_database.metadata[0].name
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
            name = kubernetes_config_map_v1.database_init.metadata[0].name
          }
        }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [
      kubernetes_config_map_v1.database_init,
      kubernetes_secret_v1.airflow_database,
      kubernetes_secret_v1.banvic_database,
    ]
  }

  wait_for_completion = true

  depends_on = [
    kubernetes_deployment_v1.postgres,
    kubernetes_service_v1.postgres,
  ]

  timeouts {
    create = "10m"
    update = "10m"
  }
}

resource "kubernetes_secret_v1" "airflow_metadata" {
  metadata {
    name      = "airflow-metadata"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  data = {
    connection = "postgresql+psycopg2://${urlencode(var.airflow_db_user)}:${urlencode(var.airflow_db_password)}@postgres.postgres.svc.cluster.local:5432/${urlencode(var.airflow_db_name)}"
  }
}

resource "kubernetes_persistent_volume_v1" "airflow_logs" {
  metadata {
    name = "airflow-logs-pv"
  }

  spec {
    capacity = {
      storage = var.airflow_logs_storage_size
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "manual"

    persistent_volume_source {
      host_path {
        path = "/var/local/airflow/logs"
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "airflow_logs" {
  metadata {
    name      = "airflow-logs"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "manual"
    volume_name        = kubernetes_persistent_volume_v1.airflow_logs.metadata[0].name

    resources {
      requests = {
        storage = var.airflow_logs_storage_size
      }
    }
  }
}

resource "kubernetes_job_v1" "airflow_logs_permissions" {
  metadata {
    name      = "airflow-logs-permissions"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  spec {
    backoff_limit = 3

    template {
      metadata {}

      spec {
        restart_policy = "Never"

        container {
          name              = "set-log-permissions"
          image             = "apache/airflow:3.2.2"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/bash", "-ec"]
          args              = ["chown -R 50000:0 /opt/airflow/logs && chmod -R g+rwX /opt/airflow/logs"]

          security_context {
            run_as_user = 0
          }

          volume_mount {
            name       = "airflow-logs"
            mount_path = "/opt/airflow/logs"
          }
        }

        volume {
          name = "airflow-logs"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.airflow_logs.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = true

  depends_on = [kubernetes_persistent_volume_claim_v1.airflow_logs]
}

resource "helm_release" "airflow" {
  name          = "airflow"
  repository    = "https://airflow.apache.org"
  chart         = "airflow"
  version       = "1.22.0"
  namespace     = kubernetes_namespace_v1.airflow.metadata[0].name
  timeout       = 1800
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      executor = "LocalExecutor"

      dags = {
        persistence = {
          enabled = false
        }
      }

      apiServer = {
        extraVolumes = [{
          name = "local-dags"
          configMap = {
            name = kubernetes_config_map_v1.airflow_dags.metadata[0].name
          }
        }]
        extraVolumeMounts = [
          for filename in local.airflow_dag_files : {
            name      = "local-dags"
            mountPath = "/opt/airflow/dags/${filename}"
            subPath   = filename
            readOnly  = true
          }
        ]
      }

      dagProcessor = {
        extraVolumes = [{
          name = "local-dags"
          configMap = {
            name = kubernetes_config_map_v1.airflow_dags.metadata[0].name
          }
        }]
        extraVolumeMounts = [
          for filename in local.airflow_dag_files : {
            name      = "local-dags"
            mountPath = "/opt/airflow/dags/${filename}"
            subPath   = filename
            readOnly  = true
          }
        ]
      }

      scheduler = {
        serviceAccount = {
          name = "airflow-scheduler"
        }
        extraVolumes = [{
          name = "local-dags"
          configMap = {
            name = kubernetes_config_map_v1.airflow_dags.metadata[0].name
          }
        }]
        extraVolumeMounts = [
          for filename in local.airflow_dag_files : {
            name      = "local-dags"
            mountPath = "/opt/airflow/dags/${filename}"
            subPath   = filename
            readOnly  = true
          }
        ]
      }

      triggerer = {
        extraVolumes = [{
          name = "local-dags"
          configMap = {
            name = kubernetes_config_map_v1.airflow_dags.metadata[0].name
          }
        }]
        extraVolumeMounts = [
          for filename in local.airflow_dag_files : {
            name      = "local-dags"
            mountPath = "/opt/airflow/dags/${filename}"
            subPath   = filename
            readOnly  = true
          }
        ]
      }

      extraEnvFrom = yamlencode([{
        secretRef = {
          name = kubernetes_secret_v1.banvic_airflow_connection.metadata[0].name
        }
      }])

      postgresql = {
        enabled = false
      }

      redis = {
        enabled = false
      }

      data = {
        metadataSecretName = kubernetes_secret_v1.airflow_metadata.metadata[0].name
      }

      createUserJob = {
        useHelmHooks   = false
        applyCustomEnv = false
        defaultUser = {
          role      = "Admin"
          username  = var.airflow_admin_user
          email     = "admin@localhost"
          firstName = "Airflow"
          lastName  = "Admin"
          password  = var.airflow_admin_password
        }
      }

      migrateDatabaseJob = {
        useHelmHooks   = false
        applyCustomEnv = false
      }

      logs = {
        persistence = {
          enabled          = true
          existingClaim    = kubernetes_persistent_volume_claim_v1.airflow_logs.metadata[0].name
          storageClassName = "manual"
          size             = var.airflow_logs_storage_size
        }
      }
    })
  ]

  depends_on = [
    kubernetes_job_v1.database_init,
    kubernetes_job_v1.airflow_logs_permissions,
    kubernetes_persistent_volume_claim_v1.airflow_logs,
    kubernetes_secret_v1.banvic_airflow_connection,
    kubernetes_role_binding_v1.airflow_meltano_pod_runner,
  ]
}
