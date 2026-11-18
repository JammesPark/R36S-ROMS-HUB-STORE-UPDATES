# Atualizações avançadas da ROMS STORE

Versão de referência: `0.4.6-beta`.

- **Distribuição:** `UPDATE.zip` completo é o link padrão e é compatível com versões anteriores. O feed também anuncia `UPDATE_DELTA.zip` com `incremental_min_version` e `incremental_max_version` iguais à versão-base exata.
- **Escolha:** o cliente atualizado seleciona automaticamente o delta somente se a versão instalada corresponder exatamente à base; caso contrário, escolhe o completo. Nunca usa delta de outra versão.
- **Segurança:** HTTPS, limites de tamanho, SHA-256 do pacote, manifesto com SHA-256 de cada arquivo, caminhos autorizados e proibição de links. A instalação ocorre exclusivamente pelo launcher após encerrar o LÖVE.
- **Backups:** diretório `state/updates/backup-*`, com metadados e cópias de arquivos substituídos; até três backups confirmados. A restauração cria novo backup, permite desfazer a operação e exige confirmação.
- **Histórico:** `state/updates/history.json`, até 100 eventos. Dados do usuário ficam fora dos pacotes OTA.
- **Atualização local:** colocar um pacote `R36S_ROMS_STORE_vX.Y.Z-beta_UPDATE.zip` em `state/updates/inbox/`. A loja valida manifesto e versão; não aceita nomes, caminhos ou arquivos estranhos. Atualização local também exige confirmação de instalação.
- **Publicação:** GitHub Actions obtém o instalador da versão anterior, verifica seu SHA-256, gera pacote completo, delta (quando aplicável), instalador e fonte. Publica a Release, baixa os artefatos e valida todos os SHA-256 antes de atualizar `update.json`.

A função de restauração não modifica ROMs, BIOS, temas nem favoritos do usuário. Em caso de falha no primeiro boot, o lançador executa rollback.
