# R36S ROMS STORE v0.4.4-beta — OTA de transição, BIOS e Temas

Código-fonte da versão de teste construída a partir do pacote R36S ROMS STORE v0.4.1-beta_TESTE,
com integração do motor de BIOS GPL-3.0 do R36SPORTSBR STORE HUB 0.6.2-beta, sem modificar a PORTS STORE.

**Funcionalidades:** Menu principal → BIOS, quatro abas (Sistemas, Pacotes,
Histórico, Local), detecção de BIOS, análise e seleção de arquivos verificados por hash,
download condicionado a uma fonte HTTPS (URL padrão herdada do HUB, substituível em `bios_url.txt`), instalação confirmada
com backup e recuperação, histórico/restauração e importação local existente preservada.
Interface 640×480 usando componentes ui.lua/theme.lua da ROMS STORE e idiomas PT-BR/EN/ES/RU.

**Nenhum arquivo de BIOS acompanha este projeto.** O aplicativo exige uma fonte externa
HTTPS autorizada, que o usuário pode substituir em `<app>/bios_url.txt`. A fonte padrão do HUB foi incluída, mas sua disponibilidade e autorização de distribuição não foram verificadas.
Não configure fontes para arquivos protegidos que você não tem direito de distribuir.

## Para instalar a versão de teste
Extraia `R36S_ROMS_STORE_v0.4.4-beta_TESTE.zip` na pasta `/roms/ports/`,
por cima da versão da ROMS STORE existente, após fazer backup da pasta do aplicativo.
Isso não remove a PORTS STORE nem os dados da ROMS STORE em `state/`.
As pastas `state/` e `conf/` não são incluídas no ZIP de teste.

O gerenciador original da ROMS STORE (importação local e backup) continua na aba **Local**;
os backups avançados ficam em `<app>/backups/bios/` e dados em `<app>/bios/`.
O sistema antigo permanece em `<app>/state/bios_manager/`.

## Controles
`L1/R1`: alternar as quatro abas; `D-pad`: navegar; `A`: abrir ou marcar;
`X`: verificar/instalar conforme tela; `Y`: marcar BIOS confirmadas na análise;
`B`: voltar, cancelar operação em andamento. Instalar, baixar, limpar e restaurar
solicitam confirmação explícita.

Na aba Pacotes, o primeiro A em **Baixar pacote** consulta nome e tamanho na fonte;
um segundo A abre a confirmação para efetivamente baixar, se a fonte estiver correta.

## Testes / Build

```bash
sudo apt-get install -y luajit zip unzip python3
bash tools/build.sh
luajit -b src/main.lua /tmp/main.lua.bytecode
```

Os testes automatizados checam sintaxe/estrutura e simulação da navegação nos quatro idiomas.
**Ainda precisa de teste físico no R36S com LÖVE 11.5 / LuaJIT** (controles,
rastreamento de diretórios, download HTTPS, extração, backup e restauração com dados
legalmente obtidos). Não usar pacotes contendo BIOS de terceiros sem autorização.

Esta fonte inclui geração do pacote OTA, mas a distribuição ainda depende de publicar uma Release verificada no GitHub.
O manifesto OTA legado contém somente parte dos arquivos e não inclui os novos utilitários.

## Créditos
Gerenciador derivado de `R36SPORTSBR STORE HUB`, baseado no `R36S PORT HUB` (Lag do Lira).
Licença GNU GPL-3.0 e avisos preservados nos arquivos LICENSE/THIRD_PARTY_NOTICES.txt.

## Menu principal (640×480)
O menu principal agora possui opções independentes **BIOS** e **Loja de Temas**,
com ícones próprios e navegação por D-pad/A/B ou mouse.
Em Configurações, **Temas e cores** continua servindo exclusivamente para trocar
as cores da interface da própria loja, não os temas do EmulationStation.

### Loja de Temas EmulationStation
- Galeria de temas públicos: Jetup13/Emulationstation-OGA-Theme-Gallery e
  repositorios de temas do GitHub, com catálogo local se faltar internet.
- Filtra compatibilidade para resoluções 480x320, **640x480** (padrão),
  854x480, 960x544 e 720x720; L1/R1 escolhem a resolução e Y atualiza.
- A abre confirmação de instalação, B retorna. Um tema que existe no destino
  é movido para backup antes da substituição; o tema não é ativado sozinho.
- Busca diretórios já existentes (ArkOS/dArkOS, AmberELEC, ROCKNIX etc.),
  ou respeita `R36S_STORE_ES_THEMES_DIR`, sem criar diretórios automaticamente.
- Não inclui temas de terceiros; confirma a instalação antes de baixar.

**Atenção:** a v0.4.3-beta ainda exige teste físico no R36S, inclusive
compatibilidade de temas e existência/permissões dos diretórios. O link padrão
de BIOS pode exigir uma fonte legalmente autorizada.

## Atualizações on-line — 0.4.4-beta

A 0.4.4-beta é um **OTA de transição**: o pacote `_UPDATE.zip` contém apenas
os oito caminhos permitidos pelo atualizador já instalado na 0.4.1-beta.
Os novos auxiliares de temas (`es_theme_manager.py`, `es_themes_seed.json`),
`fetch.sh` e `7zzs` estão dentro do `game.love` e, se ausentes no SD,
são instalados na primeira inicialização. O ZIP de teste manual inclui tudo.

O novo atualizador aceita as três listas exatas: 7 (legado), 8 (transição) ou
12 (formato completo para 0.4.5-beta e posteriores). Pacotes com arquivos
arbitrários, links simbólicos ou manifestos e hashes divergentes são rejeitados.

Para publicar **on-line**, a fonte precisa estar em um repositório GitHub com
este workflow `.github/workflows/ota-release.yml` e com acesso de escrita do token ao
repositório de atualizações. O workflow incluso foi preparado para rodar no próprio
`JammesPark/R36S-ROMS-STORE-UPDATES` (que já hospeda `update.json`): o código-fonte
deve estar no mesmo repositório antes da publicação. Faça um commit com todos os
arquivos de código-fonte, rode o build/CI e crie a tag `roms-v0.4.4-beta` apontando
para esse commit; o Action gerará `TESTE`, `UPDATE`, `FONTE` e Release. Somente após
verificar todos os três downloads remotos ele atualizará `update.json`.

**Estado da entrega local:** nenhum release foi publicado no GitHub ao criar os ZIPs.
É necessário executar o workflow no GitHub e observar um job verde. Nunca aponte
o feed para ZIPs locais ou artefatos do Actions que não são Releases públicos.
