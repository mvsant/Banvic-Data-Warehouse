# Meltano

Este diretório é a raiz do projeto Meltano: `meltano.yml`, `extract/` para os arquivos de entrada montados durante a execução e `transform/` para futuros modelos dbt. O Kind monta a pasta local `data/` como somente leitura; o DAG `sync_sources_then_extract` valida os CSVs e os copia para o PVC `meltano-data-pvc`, montado em `/project/extract`, antes de disparar `extract_pipeline`.

O DAG `sync_sources_then_extract` sincroniza os CSVs atuais, convertendo timestamps no formato `YYYY-MM-DD HH:MM:SS UTC` para ISO 8601 UTC, e então dispara `extract_pipeline`. Este último contém uma tarefa Meltano por stream e preserva as dependências entre estágios. Cada tarefa monta o PVC em `/project/extract`, valida o arquivo correspondente e executa `meltano run tap-csv target-postgres`. A variável `TAP_CSV__SELECT` seleciona um stream da configuração compartilhada `tap-csv` em `meltano.yml`. O DAG standalone `meltano_select` carrega somente `colaboradores` após os arquivos terem sido sincronizados. As credenciais do PostgreSQL são injetadas do Secret `banvic-postgres-credentials`; host e porta vêm da conexão Airflow `banvic_postgres` via template Jinja.

Na versão Meltano usada pela imagem, `meltano run` não oferece a opção `--select`; por isso, os streams desejados são selecionados em tempo de execução pela variável `TAP_CSV__SELECT`, sem alterar `meltano.yml`.

Os arquivos de projeto, incluindo futuros modelos dbt em `transform/`, são copiados para a imagem. Após atualizar os CSVs em `data/`, execute novamente `sync_sources_then_extract` para sincronizar as versões atuais e carregar os dados. Após alterar arquivos Meltano, execute `bash scripts/setup.sh` para reconstruir e carregar a imagem.

O DAG de sincronização verifica os arquivos da montagem local antes de copiá-los ao PVC; cada DAG de carga valida o arquivo necessário antes de iniciar Meltano. A montagem permite o envio manual de arquivos locais; para fontes que cheguem de forma assíncrona no futuro, será necessário adicionar um mecanismo de sinalização ou sensor compatível com a fonte de arquivos.

Para provisionar a plataforma e o PVC, siga as instruções em `terraform/platform/README.md`.
