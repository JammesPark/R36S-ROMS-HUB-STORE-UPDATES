# R36S ROMS STORE — Atualizações públicas

## Ativar OTA v0.4.4-beta em um unico upload (GitHub Actions)

O repositório já possui o workflow [`bootstrap-0.4.4.yml`](.github/workflows/bootstrap-0.4.4.yml). **Para executar a importação inicial**, faça o upload do arquivo **`R36S_ROMS_STORE_v0.4.4-beta_FONTE.zip`** na raiz da branch `main`, sem renomeá-lo. Este arquivo deve ter SHA-256:

`9ce943842c72d30b9f63289ca3c120aa78774756c196fc2af85e706c43259098`

O push de upload dispara o fluxo. Ele valida o SHA-256 do ZIP, inspeciona todos os caminhos e os extrai, **sem substituir os workflows existentes**, instala LuaJIT, testa e recria os três pacotes; em caso de sucesso, grava o código-fonte na branch `main`, cria a tag `roms-v0.4.4-beta`, publica a Release e compara os hashes dos arquivos obtidos da própria Release. Só então publica o `update.json`. O ZIP de upload é removido do último commit ao extrair a fonte.

**Importante:** o upload ainda precisa ser realizado por alguém com acesso de escrita; enquanto isso não ocorrer ou se algum teste falhar, o manifesto permanece na 0.4.1-beta. A publicação depende da permissão de escrita do GitHub Actions em **Settings → Actions → General → Workflow permissions**.

As versões seguintes podem usar o workflow normal `ota-release.yml`, após atualizar a fonte no `main`, alterar `VERSION` e criar a respectiva tag `roms-vX.Y.Z-beta`.


Repositório público **exclusivo** das atualizações da **R36S ROMS STORE** (console R36S).
O código-fonte de cada versão distribuída acompanha os pacotes de Release.

## Canal de atualizações

- Manifesto oficial: [`update.json`](update.json)
- Releases com tags `roms-vX.Y.Z-beta`, por exemplo `roms-v0.3.1-beta`
- Cada Release contém `R36S_ROMS_STORE_vX.Y.Z-beta_TESTE.zip`, `_UPDATE.zip` e `_FONTE.zip`.
- A publicação é realizada pelo workflow do projeto principal **após os testes**, validando SHA-256, versões e conteúdo dos arquivos.
- O aplicativo consulta este canal automaticamente, mas só baixa/instala após confirmação do usuário.
- Atualizações preservam as ROMs, o histórico de downloads, os favoritos e as configurações.

**Primeira Release publicada:** [roms-v0.3.1-beta](https://github.com/JammesPark/R36S-ROMS-STORE-UPDATES/releases/tag/roms-v0.3.1-beta). O manifesto [update.json](update.json) está ativo (`published`) e aponta para os arquivos verificados. O aplicativo instalado na mesma versão não precisará atualizar até a próxima Release.

## Licença e autoria

Software livre distribuído sob GNU GPL-3.0. Consulte os arquivos LICENSE e THIRD_PARTY_NOTICES.txt presentes no código-fonte de cada Release.
Este repositório não hospeda ROMs, BIOS nem jogos comerciais.

## Projeto independente

Este canal pertence apenas à **R36S ROMS STORE**. Não é a fonte de atualizações do R36SPORTSBR STORE HUB nem de outros aplicativos.


## Publicação OTA automatizada (preparada em 18/11/2026)

O workflow [`ota-release.yml`](.github/workflows/ota-release.yml) foi adicionado ao canal de atualizações. Ele valida a sintaxe LuaJIT, executa os testes, gera os ZIPs `TESTE`, `UPDATE` e `FONTE`, publica uma Release, baixa os arquivos publicados para conferir os SHA-256 e **só depois** atualiza o `update.json`.

**Pré-requisito ainda pendente:** o repositório contém o canal de distribuição, mas não o código-fonte completo da ROMS STORE. Antes de rodar o workflow, adicione a fonte v0.4.4-beta completa na raiz do repositório (pastas `src/`, `port/`, `tests/`, `tools/` e arquivo `VERSION`), de preferência em um único commit, preservando os workflows. Depois crie a tag `roms-v0.4.4-beta` nesse commit. Verifique nas configurações do repositório que GitHub Actions pode criar Releases e alterar arquivos (`contents: write`).

A versão 0.4.4-beta inclui um pacote OTA de **oito arquivos** para manter compatibilidade com os clientes 0.4.1-beta. Os binários auxiliares de BIOS e Loja de Temas estão no `game.love` e são instalados na primeira execução quando faltarem. O novo atualizador permite pacotes completos de 12 arquivos para as versões posteriores, com verificação de hash, backup e rollback.

**Não altere manualmente `update.json` para uma versão cujos ZIPs não estejam publicados e verificados.** Até a execução bem-sucedida do workflow, o canal público continua na versão indicada no manifesto.
