# Kubernetes

Os namespaces, PVCs, banco de dados, Secrets, Airflow Helm chart e permissões para lançar tarefas Meltano são gerenciados por `terraform/platform/`.

Este diretório contém somente o Pod temporário `meltano/data-loader.yaml`, usado por `scripts/setup.sh` para copiar os CSVs locais ao PVC. O script remove o Pod ao terminar, mas os arquivos permanecem no volume.

Não mantenha uma segunda cópia manual dos recursos gerenciados pelo Terraform: isso causa divergência entre estado e cluster.
