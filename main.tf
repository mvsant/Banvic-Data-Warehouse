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
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

# =========================================================================
# 1. NAMESPACES PROVISIONING
# =========================================================================
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

# =========================================================================
# 2. STORAGE INFRASTRUCTURE (RANCHER LOCAL-PATH CLASSIFICATION)
# =========================================================================
resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "banvic-database-postgres-pvc"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard" # Strictly mirrors your default rancher provisioner
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
  wait_until_bound = false 
}

resource "kubernetes_persistent_volume_claim" "meltano_csv_pvc" {
  metadata {
    name      = "meltano-csv-pvc"
    namespace = kubernetes_namespace.meltano.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
  wait_until_bound = false 
}

variable "postgres_user" {
  type        = string
  description = "The username for the PostgreSQL database"
}

variable "postgres_password" {
  type        = string
  description = "The password for the PostgreSQL database"
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  description = "The database name for the PostgreSQL database"
}

# =========================================================================
# 3. POSTGRESQL ENGINE TARGET AND SERVICE NETWORK LAYER
# =========================================================================
resource "kubernetes_pod" "postgres_pod" {
  metadata {
    name      = "banvic-database-postgres-alpine-pod"
    namespace = kubernetes_namespace.postgres.metadata[0].name
    labels = {
      app     = "postgres"
      release = "banvic-database"
    }
  }
  spec {
    container {
      name  = "postgres"
      image = "postgres:16-alpine"
      port {
        container_port = 5432
        name           = "dbport"
      }
      env {
        name  = "POSTGRES_USER"
        value = var.postgres_user
      }
      env {
        name  = "POSTGRES_PASSWORD"
        value = var.postgres_password
      }
      env {
        name  = "POSTGRES_DB"
        value = var.postgres_db
      }
      volume_mount {
        name       = "postgres-data-volume"
        mount_path = "/var/lib/postgresql/data"
      }
    }
    volume {
      name = "postgres-data-volume"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
      }
    }
  }
}

resource "kubernetes_service" "postgres_service" {
  metadata {
    name      = "postgres-service"
    namespace = kubernetes_namespace.postgres.metadata[0].name
    labels = {
      app = "postgres"
    }
  }
  spec {
    type = "ClusterIP"
    port {
      port        = 5432
      target_port = 5432
      name        = "postgres"
    }
    selector = {
      app = "postgres"
    }
  }
}

# =========================================================================
# 4. CROSS-NAMESPACE SECURITY VAULTS (CREDENTIALS)
# =========================================================================
resource "kubernetes_secret" "postgres_credentials_meltano" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.meltano.metadata[0].name
  }
  type = "Opaque"
  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = var.postgres_db
  }
}

# =========================================================================
# 5. SECURITY RBAC FOR KUBERNETESPODOPERATOR PARALLELISM WORKERS
# =========================================================================
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
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
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

# =========================================================================
# 6. APACHE AIRFLOW DEPLOYMENT WITH GIT-SYNC SYNCED AUTOMATICALLY
# =========================================================================
resource "helm_release" "airflow" {
  name       = "banvic-release"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  version    = "1.22.0"
  namespace  = "airflow"

  timeout = 600 # Lowered timeout so you don't have to wait an hour if it breaks

  set = [
    {  
    name  = "createUserJob.useHelmHooks"
    value = "false"
    },
    {
    name  = "migrateDatabaseJob.useHelmHooks"
    value = "false"
    },
    {
    name  = "createUserJob.applyCustomEnv"
    value = "false"
    },
    {
    name  = "migrateDatabaseJob.applyCustomEnv"
    value = "false"
    },
    {
    name  = "dags.gitSync.enabled"
    value = "false"
    },
    {
    name  = "dagProcessor.waitForMigrations.enabled"
    value = "false"
    },
    {
    name  = "triggerer.waitForMigrations.enabled"
    value = "false"
    },
    {
    name  = "worker.waitForMigrations.enabled"
    value = "false"
   },
   {
  name  = "secret.AIRFLOW_CONN_STANDALONE_POSTGRES"
  value = "postgresql://${var.postgres_user}:${var.postgres_password}@postgres:5432/${var.postgres_db}"
  }   
  ]
  values = [
    yamlencode({
      # 1. FIX THE 100Gi STORAGE CRAZINESS (Shrink log storage allocations)
      # 1. Disable the built-in PostgreSQL to bypass the PVC WaitForFirstConsumer deadlock
      postgresql = {
        enabled = false
      }

      # 2. Point Airflow to use YOUR custom PostgreSQL engine provisioned in Section 3
      data = {
        metadataConnection = {
          user     = var.postgres_user
          pass     = var.postgres_password
          host     = "postgres-service.postgres.svc.cluster.local"
          port     = 5432
          db       = var.postgres_db
          protocol = "postgresql"
        }
      }
      workers = {
        persistence = {
          enabled = true
          size    = "2Gi" # Much safer for a local machine!
        }
      }
      triggerer = {
        persistence = {
          enabled = true
          size    = "2Gi" # Much safer for a local machine!
        }
      }

      # 2. FIX GIT-SYNC IMAGES & CONFIGURATION
      images = {
        airflow = {
          repository = "banvic-dags"
          tag        = "0.0.1"
        }
      }

      dags = {
        persistence = {
          enabled = false
        }
      }
    })
  ]
  
}
