# Meltano

Este diretório contém o projeto Meltano e sua estrutura padrão de pastas, incluindo `transform/` para transformações dbt. A imagem é construída localmente e carregada no cluster Kind por `scripts/setup.sh`. O Airflow inicia pods Meltano de curta duração no namespace `meltano`.

Os CSVs são sincronizados para o PVC `meltano-data-pvc` e montados em `/project/data`. O target PostgreSQL usa as credenciais do Secret `banvic-postgres-credentials`; o host é o serviço PostgreSQL no namespace `postgres`.

Para provisionar o namespace/PVC, carregar a imagem e enviar os CSVs, siga as instruções em `terraform/platform/README.md` e execute `bash scripts/setup.sh`.
