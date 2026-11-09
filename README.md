# Banvic Data Warehouse

Projeto de engenharia de dados que ingere arquivos CSV com Meltano, orquestra os pipelines com Airflow e persiste os dados em PostgreSQL.

## Estrutura

```text
airflow/       DAGs montadas localmente no Airflow
data/          CSVs de entrada versionados
k8s/           Manifestos auxiliares e recursos Kubernetes
meltano/       Imagem e projeto de ingestão Meltano
terraform/     Provisionamento do Kind e módulos da solução
scripts/       Rotinas locais de desenvolvimento
```

Os diretórios principais contêm READMEs com instruções próprias. O [guia Terraform](terraform/README.md) descreve a ordem de provisionamento.

## Persistência

O cluster Kind monta `.kind-data/` no nó para persistir os dados do DW, arquivos CSV sincronizados e logs do Airflow. O Postgres usa um Deployment com probes para recuperação automática, e o Airflow mantém os logs em um PVC persistente. O namespace `meltano` e seu PVC são recursos declarativos Terraform; recriar o cluster não preserva os dados se `.kind-data/` for removido.

As credenciais e o state são locais e ignorados pelo Git. Veja as orientações de segurança em [terraform/README.md](terraform/README.md).

## Desenvolvimento local

* Edite uma DAG em `airflow/dags/`; o Kind monta essa pasta diretamente no Airflow, sem Git-Sync, rebuild ou `terraform apply`. O Airflow a identifica no próximo ciclo de leitura.
* Atualize um CSV em `data/` e execute `bash scripts/setup.sh` para sincronizar a versão local com o PVC persistente do namespace `meltano`.
* Os logs e os arquivos do banco ficam em `.kind-data/airflow-logs/` e `.kind-data/postgres/`. Faça backup desse diretório antes de substituir ou remover o cluster.
* Para acessar o Airflow e o Postgres:

  ```bash
  kubectl --kubeconfig terraform/kind/kubeconfig port-forward svc/banvic-release-api-server 8080:8080 -n airflow
  kubectl --kubeconfig terraform/kind/kubeconfig port-forward svc/postgres-service 5432:5432 -n postgres
  ```

![Arquitetura do projeto](assets/image.png)
