# Kind cluster

Este Terraform root provisiona somente o cluster Kind e seus bind mounts locais. As variáveis em `variables.tf` permitem ajustar nome, versão do nó e caminhos locais; os padrões apontam para `.kind-data/` e `airflow/dags/` na raiz do repositório.

Execute os comandos da raiz:

```bash
mkdir -p .kind-data
terraform -chdir=terraform/kind init
terraform -chdir=terraform/kind plan
terraform -chdir=terraform/kind apply
```

O kubeconfig é criado em `terraform/kind/kubeconfig`. O diretório `airflow/dags/` fica montado somente para leitura no nó, permitindo ao Airflow observar edições locais sem Git-Sync ou `terraform apply`.
