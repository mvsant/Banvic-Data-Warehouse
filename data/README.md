# Dados de entrada

Os arquivos CSV versionados neste diretório são a entrada do pipeline Meltano. `scripts/setup.sh` sincroniza os arquivos para o PVC persistente do namespace `meltano`; os extratores leem os CSVs em `/project/data`.

Adicione novos arquivos de origem aqui e configure o extrator correspondente em `meltano/meltano.yml` e a tarefa de ingestão em `airflow/dags/extract_pipeline_dag.py`. Não armazene segredos neste diretório.
