# Banvic Data Warehouse

Projeto de engenharia de dados que ingere arquivos CSV com Meltano, orquestra os pipelines com Airflow e persiste os dados em PostgreSQL.

## Estrutura

```text
airflow/       DAGs e documentação do Airflow
data/          CSVs de entrada versionados
k8s/           Manifestos e utilitários auxiliares
meltano/       Projeto Meltano com a estrutura padrão
terraform/kind/      Cluster Kind
terraform/platform/  PostgreSQL externo e Airflow Helm
scripts/       Rotinas locais de desenvolvimento
```

Os diretórios principais contêm READMEs com instruções próprias. O [guia Terraform](terraform/README.md) descreve a ordem de provisionamento.

## Persistência

PostgreSQL e Airflow são provisionados por `terraform/platform/` no Kind existente, em namespaces separados. Os dados do PostgreSQL e os logs do Airflow usam volumes no filesystem Linux do nó Kind; sobrevivem a reinícios de Pods, mas não à destruição do cluster. A persistência local não substitui backups.

As credenciais e o state são locais e ignorados pelo Git. Veja as orientações de segurança em [terraform/README.md](terraform/README.md).

## Desenvolvimento local

* O Terraform `terraform/kind/` cria o cluster Kind, carrega a imagem Meltano local e monta `airflow/dags/` e `data/` do workspace no nó. Salvar uma DAG local atualiza o conteúdo visível ao Airflow sem rebuild; o DAG lê os CSVs atuais da montagem `data/`.
* `terraform/platform/` instala PostgreSQL, Airflow e o namespace/PVC do Meltano. Rode `bash scripts/setup.sh` para validar os CSVs, construir/carregar o projeto Meltano completo e aplicar a configuração do Kind.
* O DAG manual `sync_sources_then_extract` sincroniza os arquivos atuais de `data/` ao PVC e então dispara `extract_pipeline`, que executa as tarefas por stream preservando as dependências entre estágios. O DAG standalone `meltano_select` carrega apenas `colaboradores`. Ao atualizar arquivos em `data/`, execute `sync_sources_then_extract` novamente; não é necessário reconstruir a imagem ou executar `setup.sh`. Os futuros modelos dbt vivem no projeto Meltano. A carga usa uma credencial de privilégio mínimo; host/porta vêm da conexão Airflow `banvic_postgres`.
* Os dados do Postgres, CSVs sincronizados e logs do Airflow persistem nos volumes do nó Kind, mas não sobrevivem à destruição do cluster. Faça backup antes de substituí-lo.
* Para acessar o Airflow:

  ```bash
  kubectl --kubeconfig terraform/kind/kubeconfig port-forward svc/airflow-api-server 8080:8080 -n airflow
  ```

![Arquitetura do projeto](assets/image.png)

Para pré-requisitos, instalação, decisões tecnológicas, diagramas detalhados, configuração dos componentes e um roteiro de apresentação com consultas para verificar os dados carregados, veja o [guia de arquitetura e demonstração](docs/architecture-and-demo.md).
