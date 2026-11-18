# R36S ROMS STORE — 0.4.5-beta

Versão Lua/LÖVE 11.5 da R36S ROMS STORE, com navegação para 640×480, catálogo de ROMs, BIOS, temas EmulationStation, favoritos, instalação no SD1/SD2 e atualização OTA.

## Alterações da 0.4.5-beta

**Menu principal, nesta ordem:** Início → Catálogo → BIOS → Temas → Downloads → Instalados → Favoritos → Configurações → Sobre → Sair.

A página **Downloads** reúne os downloads iniciados pelo usuário nos módulos de **ROMs, BIOS, temas EmulationStation e atualização da loja**, exibindo as etapas, os bytes recebidos e as barras percentuais quando o servidor informa o tamanho do arquivo. O histórico de ROMs já existentes continua disponível; BIOS e temas passam a ter histórico próprio, em `state/roms_transfer_log.json`, sem remover dados anteriores.

A seção **Temas** utiliza o catálogo público de Jetup13/Emulationstation-OGA-Theme-Gallery, mais os repositórios consultados pelo instalador. As capas fornecidas pelo catálogo são armazenadas em `state/es_theme_covers/` e apresentadas como miniaturas e uma prévia maior. Só são buscadas imagens PNG/JPEG por HTTPS em hosts permitidos, com limite de 2 MiB por imagem e cache de texturas limitado. Quando não houver prévia disponível, aparece o ícone de imagem indisponível, sem bloquear a instalação do tema.

As resoluções disponíveis continuam 480×320, **640×480** (padrão), 854×480, 960×544 e 720×720. A compatibilidade depende do tema. O aplicativo não ativa automaticamente o tema instalado; o EmulationStation deve selecioná-lo.

Em **Configurações → Temas e cores** permanece apenas a escolha das cores da própria ROMS STORE.

## BIOS

Gerenciador de BIOS com verificação por nome, tamanho e hash, análise de pacotes, backup, restauração e importação local. As operações que alteram arquivos precisam de confirmação; arquivos só são instalados após verificação de hash. O download requer uma fonte HTTPS configurada em `bios_url.txt` e de distribuição autorizada. **Não são incluídas BIOS comerciais.**

## Instalação e atualização OTA

As novas versões são distribuídas pelo canal oficial [R36S ROMS STORE UPDATES](https://github.com/JammesPark/R36S-ROMS-STORE-UPDATES/releases). O aplicativo consulta o `update.json`, compara as versões e solicita confirmação para baixar e instalar a atualização. Backups e rollback permanecem disponíveis; o pacote não substitui a pasta `state/`.

**Publicação sem upload manual de ZIP:** os códigos-fonte da ROMS STORE ficam diretamente na branch `main`. Para atualizar, altere os módulos necessários e aumente `VERSION` no mesmo commit. O workflow `.github/workflows/auto-release-on-version.yml` testa com LuaJIT, gera os pacotes TESTE, UPDATE e FONTE, cria a Release, baixa novamente os arquivos para verificar SHA-256 e só então atualiza o manifesto público. Se alguma etapa falhar, a versão anterior permanece publicada.

Para gerar pacotes localmente com LuaJIT, Lua 5.3, Python 3 e zip instalados, execute `bash tools/build.sh`. Os testes automatizados não substituem a validação no console físico.

## Créditos e licença

Software GPL-3.0. Motor de BIOS adaptado do R36SPORTSBR STORE HUB; preservar os créditos à base original R36S PORT HUB, por Lag do Lira, e os avisos dos demais componentes em `LICENSE` e `THIRD_PARTY_NOTICES.txt`. ROMs, jogos, BIOS e temas de terceiros podem possuir licenças próprias.
