# Airflow

As DAGs ficam em `airflow/dags/`. O Kind monta esse diretório do workspace no nó do cluster, e o Helm chart monta o caminho no scheduler, DAG processor, workers e demais componentes. Git-Sync está desabilitado. Salvar um arquivo Python em `airflow/dags/` atualiza a fonte vista pelo Airflow sem rebuild ou `terraform apply`; a DAG aparecerá após o próximo ciclo de leitura do Airflow.

O chart e seus valores são declarados pelo módulo `terraform/modules/airflow`. Os logs são gravados no PVC `airflow-logs-pvc`, que usa o diretório persistente `.kind-data/airflow-logs`.

O Airflow conecta ao banco de metadados `airflow` com seu próprio usuário. A conexão de negócio `Banvic_Postgres` aponta para o banco `banvic` com credenciais separadas. Não coloque credenciais nas DAGs.

Para observar as DAGs, use o `kubectl port-forward` descrito no [guia principal](../README.md).
