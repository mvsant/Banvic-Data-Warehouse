# Kubernetes

O namespace e os recursos persistentes do Meltano são declarados no módulo Terraform `terraform/modules/meltano`; Deployment, Service, Secret, PVC, Job de inicialização e probes do Postgres ficam em `terraform/modules/postgres`. O Helm chart do Airflow e seu armazenamento ficam em `terraform/modules/airflow`.

Este diretório contém somente recursos auxiliares operacionais que não pertencem ao ciclo de vida Terraform, como o Pod temporário `meltano/data-loader.yaml`, utilizado para sincronizar os CSVs do host com o PVC. O script o remove ao terminar, mas os dados permanecem no volume.

Não mantenha uma segunda cópia manual dos recursos gerenciados pelo Terraform: isso causa divergência entre estado e cluster.
