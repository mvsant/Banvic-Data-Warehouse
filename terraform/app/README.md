# Aplicação Kubernetes

Este root Terraform conecta ao cluster provisionado em `../kind/` e compõe os módulos reutilizáveis de Postgres, Meltano e Airflow. Ajuste os nomes de namespace, tamanhos dos PVCs, caminhos no nó, imagem do banco e versão do Helm chart em `variables.tf` ou por `-var`/`*.tfvars`.

As credenciais ficam em `terraform.tfvars`, ignorado pelo Git. Copie `terraform.example.tfvars` se ainda não existir; em configurações antigas, acrescente `banvic_password` e `airflow_password`. O state local inclui Secrets e também deve ser protegido.

Inicialize e aplique a partir da raiz do repositório, conforme [terraform/README.md](../README.md).
