# Kubernetes

Os namespaces, PVCs, banco de dados, Secrets, Airflow Helm chart e permissões para lançar tarefas Meltano são gerenciados por `terraform/platform/`.

O DAG `sync_sources_then_extract` usa um pod de sincronização para copiar os CSVs atuais da montagem local `data/` ao PVC Meltano e, após sucesso, dispara `extract_pipeline`. Os arquivos ficam disponíveis em `/project/extract` nos pods Meltano.

Não mantenha uma segunda cópia manual dos recursos gerenciados pelo Terraform: isso causa divergência entre estado e cluster.
