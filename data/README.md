# Dados de entrada

Os arquivos CSV versionados neste diretório são a cópia de origem. O Kind monta esta pasta como somente leitura em `/mnt/banvic-source/data`. A tarefa `sync_source_files` do DAG `sync_sources_then_extract` valida e copia os arquivos atuais para o PVC do namespace `meltano`; os pods Meltano leem os arquivos em `/project/extract`. Depois de atualizar os CSVs, execute novamente `sync_sources_then_extract` para sincronizar e ingerir as versões atuais.

Depois de atualizar um CSV ou adicionar uma nova fonte, ajuste a configuração do stream e seu schema em `meltano/meltano.yml` e execute novamente `bash scripts/setup.sh`. Não armazene segredos neste diretório.
