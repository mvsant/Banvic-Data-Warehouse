# Terraform

Esta pasta concentra o provisionamento da infraestrutura e da aplicação, separado do código de ingestão e das DAGs.

* `kind/` cria o cluster local e expõe os diretórios persistentes e `airflow/dags` ao nó.
* `app/` configura os providers e liga os módulos por variáveis.
* `modules/postgres`, `modules/meltano` e `modules/airflow` gerenciam os componentes com entradas configuráveis.

## Instalação local

Requisitos: Docker Desktop, Kind e Terraform 1.5 ou superior. A partir da raiz:

```bash
mkdir -p .kind-data
cp -n terraform/app/terraform.example.tfvars terraform/app/terraform.tfvars
```

Edite `terraform/app/terraform.tfvars` com senhas fortes e únicas. Se estiver reutilizando o arquivo local de uma versão anterior, acrescente `banvic_password` e `airflow_password`. Esse arquivo, o state e o kubeconfig são locais e não devem ser versionados.

```bash
terraform -chdir=terraform/kind init
terraform -chdir=terraform/kind apply

terraform -chdir=terraform/app init
terraform -chdir=terraform/app plan -var-file=terraform.tfvars
terraform -chdir=terraform/app apply -var-file=terraform.tfvars

bash scripts/setup.sh
```

Se já existir um cluster Kind chamado `banvic` sem state Terraform correspondente, escolha um nome novo para evitar conflito:

```bash
terraform -chdir=terraform/kind apply -var=cluster_name=banvic-dev
```

O nome selecionado fica salvo no state; use o mesmo valor ao executar `destroy`.

O módulo `postgres` provisiona um Deployment autogerenciado por probes, um Service e um PVC com política `Retain`; os bancos `airflow` e `banvic` permanecem separados. O módulo `meltano` cria um namespace durável durante a vida do cluster e um PVC persistente para os arquivos de entrada. O módulo `airflow` persiste os logs e monta as DAGs do workspace local em modo somente leitura.

## Atualização de uma instalação antiga

O Terraform anterior e o novo layout usam estados e clusters diferentes; não aplique o novo código sobre o cluster antigo sem antes exportar os dados. O `terraform.tfstate` legado na raiz permanece intocado e não é importado automaticamente pelos novos roots. Faça backup lógico dos bancos, preserve o state e os arquivos locais antigos, crie o Kind e restaure os dados de negócio no banco `banvic`. A nova configuração guarda os dados sob `.kind-data/`; mantenha esse diretório em backup mesmo ao recriar o cluster. Os dados não são migrados automaticamente entre provedores ou volumes.

Para encerrar, destrua primeiro os recursos da aplicação e depois o cluster:

```bash
terraform -chdir=terraform/app destroy -var-file=terraform.tfvars
terraform -chdir=terraform/kind destroy
```

Não remova `.kind-data/` se precisar preservar o banco, os CSVs ou os logs.
