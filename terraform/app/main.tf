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
  config_path = abspath("${path.module}/${var.kubeconfig_path}")
}

provider "helm" {
  kubernetes = {
    config_path = abspath("${path.module}/${var.kubeconfig_path}")
  }
}

module "postgres" {
  source = "../modules/postgres"

  namespace              = var.postgres_namespace
  image                  = var.postgres_image
  storage_size           = var.postgres_storage_size
  node_storage_path      = var.postgres_node_storage_path
  administrator_user     = var.postgres_user
  administrator_password = var.postgres_password
  banvic_user            = var.banvic_user
  banvic_password        = var.banvic_password
  banvic_database        = var.postgres_db
  airflow_user           = var.airflow_user
  airflow_password       = var.airflow_password
  airflow_database       = var.airflow_db
}

module "meltano" {
  source = "../modules/meltano"

  namespace         = var.meltano_namespace
  storage_size      = var.meltano_storage_size
  node_storage_path = var.meltano_node_storage_path
  postgres_host     = module.postgres.service_host
  postgres_port     = module.postgres.service_port
  postgres_user     = var.banvic_user
  postgres_password = var.banvic_password
  postgres_database = var.postgres_db
}

module "airflow" {
  source = "../modules/airflow"

  namespace                   = var.airflow_namespace
  release_name                = var.airflow_release_name
  chart_version               = var.airflow_chart_version
  postgres_service_host       = module.postgres.service_host
  postgres_service_port       = module.postgres.service_port
  airflow_user                = var.airflow_user
  airflow_password            = var.airflow_password
  airflow_database            = var.airflow_db
  banvic_user                 = var.banvic_user
  banvic_password             = var.banvic_password
  banvic_database             = var.postgres_db
  logs_storage_size           = var.airflow_logs_storage_size
  logs_node_storage_path      = var.airflow_logs_node_storage_path
  dags_node_path              = var.airflow_dags_node_path
  meltano_namespace           = module.meltano.namespace
  meltano_airflow_role_name   = module.meltano.airflow_role_name
  worker_service_account_name = var.airflow_worker_service_account

  depends_on = [module.postgres, module.meltano]
}
