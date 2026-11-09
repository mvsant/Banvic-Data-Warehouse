# Meltano

O projeto Meltano e seu Dockerfile estão neste diretório. A imagem é construída localmente e carregada no cluster Kind por `scripts/setup.sh`; os pods executados pelo Airflow pertencem ao namespace persistente `meltano`.

Os CSVs não são empacotados na imagem. Eles vêm de `data/`, são sincronizados para `meltano-data-pvc` e montados nos pods em `/project/data`. O PVC usa armazenamento persistente do host em `.kind-data/meltano`.

Os Secrets de conexão são criados pelo módulo Terraform a partir de `terraform/app/terraform.tfvars`. O usuário do Meltano tem permissões somente no banco de dados do DW.
