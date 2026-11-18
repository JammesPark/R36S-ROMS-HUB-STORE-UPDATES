# R36S ROMS STORE — Atualizações públicas

Repositório público **exclusivo** das atualizações da **R36S ROMS STORE** (console R36S).
O código-fonte de cada versão distribuída acompanha os pacotes de Release.

## Canal de atualizações

- Manifesto oficial: [`update.json`](update.json)
- Releases com tags `roms-vX.Y.Z-beta`, por exemplo `roms-v0.3.1-beta`
- Cada Release contém `R36S_ROMS_STORE_vX.Y.Z-beta_TESTE.zip`, `_UPDATE.zip` e `_FONTE.zip`.
- A publicação é realizada pelo workflow do projeto principal **após os testes**, validando SHA-256, versões e conteúdo dos arquivos.
- O aplicativo consulta este canal automaticamente, mas só baixa/instala após confirmação do usuário.
- Atualizações preservam as ROMs, o histórico de downloads, os favoritos e as configurações.

**Atenção:** enquanto `update.json` indicar `awaiting_release`, nenhuma atualização está publicada ou pronta para instalar.

## Licença e autoria

Software livre distribuído sob GNU GPL-3.0. Consulte os arquivos LICENSE e THIRD_PARTY_NOTICES.txt presentes no código-fonte de cada Release.
Este repositório não hospeda ROMs, BIOS nem jogos comerciais.

## Projeto independente

Este canal pertence apenas à **R36S ROMS STORE**. Não é a fonte de atualizações do R36SPORTSBR STORE HUB nem de outros aplicativos.
