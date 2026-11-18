# R36S ROMS STORE — 0.4.14-beta

## Segundo tema nativo: Layout B — Studio (0.4.14-beta)

O **Clássico** continua sendo o tema inicial, preservado sem migração
obrigatória. Em **Configurações → Tema da interface**, selecione **Studio**
para mudar para a interface horizontal inspirada no protótipo HTML aprovado.
Esta versão é uma **implementação em Lua/LÖVE 11.5**, não um navegador HTML.

- **Studio:** navegação horizontal de dez seções, cartões com capas verticais,
  painel de download, catálogo, favoritos, detalhes, configurações e
  gerenciador de downloads exibindo dados reais.
- **Cinco paletas completas:** Oceano, Esmeralda, Violeta, Âmbar e Ardósia.
  A opção **Cor do tema** altera fundos, cabeçalhos, bordas, cartões,
  botões e textos, não apenas a cor dos ícones. O Clássico mantém suas
  opções de cores anteriores.
- **Navegação:** **SELECT** (no SDL2, botão back) abre/fecha a seleção do
  menu superior; direcional esquerda/direita e **A** mudam a seção.
  A navegação tradicional e os motores de ROMs, BIOS, temas do
  EmulationStation e OTA permanecem os mesmos.
- **Telas especializadas:** BIOS, temas ES e rotinas OTA reutilizam os
  controles e conteúdos originais **dentro da moldura Studio**; não há
  substituição do motor de instalação e de verificações SHA-256.
- A escolha Clássico/Studio é armazenada em `state/roms_settings.json`.
  Uma falha de desenho no Studio restaura o visual Clássico, mantendo
  os dados e o acesso ao aplicativo.
- Uma bateria de testes offline cobre 29 rotas Lua, paletas,
  geometria de 640×480, controle de seleção e regressões OTA.
  A apresentação exata em BIOS/ES e o controle físico ainda dependem
  de validação no R36S.

## Layout aprovado do protótipo HTML (0.4.13-beta)

A tela **Início** do LÖVE agora utiliza o conceito aprovado no HTML:
**"Em destaque"** aparece logo abaixo do painel de transferência, com **três
capas em retrato 2:3** lado a lado. Abaixo delas ficam as contagens de
**Catálogo**, **Instalados** e **Favoritos**, calculadas dos dados reais.
As capas usam os arquivos já existentes em `state/covers/`; nenhuma imagem
ou contagem de demonstração do HTML entra na aplicação.

- As três capas permitem navegação por direcional e por clique/toque.
  A seleção usa o índice real do catálogo e abre a ROM correspondente.
- Em Catálogo e Resultados de busca, a capa selecionada é exibida em retrato,
  preservando a proporção e com botão de detalhes logo abaixo.
- Em Detalhes e Favoritos, as capas também respeitam a proporção vertical,
  sem esticar as imagens reais.
- Mantidos BIOS, Temas, Downloads, SD1/SD2, idiomas, detectores de resolução,
  dados pessoais em `state/` e mecanismo OTA existente.

A geometria 640x480 é testada por `tests/test_home_layout.lua` e a
navegação/integração por `tests/test_main_menu.py`.
Validação visual e de controles no console físico segue necessária.

## Etapa 2 — Tela física e adaptação automática (0.4.12-beta)

O aplicativo consulta a resolução do display ativo informada pelo **SDL2/LÖVE**.
No console PortMaster, tenta usar o modo de tela cheia do display detectado.
A interface existente continua desenhada em **640×480** internamente e é
redimensionada proporcionalmente, centralizada e sem distorção. Em telas 16:9,
quadradas ou outras proporções, o espaço restante vira margem preta; nenhum
menu é cortado para preencher a tela.

- Resoluções simuladas nos testes: 320×240, 640×480, 720×720, 854×480,
  960×544, 1024×768 e 1280×720.
- Cliques e toques que chegam como eventos de mouse do LÖVE são mapeados
  para as coordenadas virtuais 640×480; clicar fora da área útil não ativa
  opções por engano.
- Se SDL2 não informar a tela física, a aplicação utiliza as dimensões de
  renderização disponíveis. Sem nenhuma informação confiável, volta a 640×480.
- Se o driver não conseguir criar o canvas de escalonamento, o aplicativo tenta
  voltar à renderização direta em 640×480, preservando os botões e a navegação.
- O console registra em `log.txt` a resolução detectada, a área de saída,
  o fator de escala e as margens, em uma linha iniciada por `[DISPLAY]`.
- No PC, a janela inicia em 640×480 e pode ser redimensionada para testes;
  não é forçado modo de tela cheia fora dos caminhos de console.
- A atualização OTA e os arquivos pessoais em `state/` não foram alterados.

**Observação:** os testes automatizados verificam a geometria e a sintaxe.
A detecção do painel físico depende da CFW/SDL2 e precisa ser verificada no
console real na primeira execução após a atualização.

## Etapa 1 — Central de Downloads (0.4.10-beta)

A Central de Downloads usa **A** para pausar ou retomar a tarefa selecionada,
**X** para cancelar, **Y** para abrir o histórico e **B** para voltar.
As setas movimentam a seleção entre transferências ativas, fila e histórico.

- **Velocidade/ETA:** calculados a partir dos bytes efetivamente recebidos e
  do intervalo de medição; quando o servidor não informa o tamanho ou não há
  amostras suficientes, o tempo restante aparece como indisponível.
- **Fila:** ROMs, pacote BIOS e temas EmulationStation usam uma fila FIFO
  (até 20 tarefas pendentes). ROMs podem ser adicionadas durante outro download
  sem autorizar sobrescrita automática. A fila pendente fica no arquivo
  `state/roms_download_queue.json`, fora dos pacotes OTA.
- **Pausa/retomada:** BIOS suspende e continua o processo de rede; ROMs e temas
  pausam cooperativamente a transferência em andamento, mantendo os arquivos
  parciais sob controle do motor original.
- **Segurança:** cancelamento de download não remove uma ROM instalada.
  Verificação SHA-256 e validação de destino permanecem no motor de cada tipo;
  tema só é instalado após recebimento e conferência do pacote. O OTA usa o
  atualizador isolado existente, sem entrar na fila de conteúdo.
- **Limites da versão beta:** a retomada de uma tarefa ativa é destinada ao
  aplicativo ainda aberto; após reiniciar o console, apenas tarefas pendentes
  são recuperadas. Transferências interrompidas e pausas prolongadas podem
  exigir um novo download se o servidor fechar a conexão. Os controles não
  interrompem etapas críticas de verificação ou instalação.

Versão Lua/LÖVE 11.5 da R36S ROMS STORE, com navegação para 640×480, catálogo de ROMs, BIOS, temas EmulationStation, favoritos, instalação no SD1/SD2 e atualização OTA.

## Alterações da 0.4.5-beta

**Menu principal, nesta ordem:** Início → Catálogo → BIOS → Temas → Downloads → Instalados → Favoritos → Configurações → Sobre → Sair.

A página **Downloads** reúne os downloads iniciados pelo usuário nos módulos de **ROMs, BIOS, temas EmulationStation e atualização da loja**, exibindo as etapas, os bytes recebidos e as barras percentuais quando o servidor informa o tamanho do arquivo. O histórico de ROMs já existentes continua disponível; BIOS e temas passam a ter histórico próprio, em `state/roms_transfer_log.json`, sem remover dados anteriores.

A seção **Temas** utiliza o catálogo público de Jetup13/Emulationstation-OGA-Theme-Gallery, mais os repositórios consultados pelo instalador. As capas fornecidas pelo catálogo são armazenadas em `state/es_theme_covers/` e apresentadas como miniaturas e uma prévia maior. Só são buscadas imagens PNG/JPEG por HTTPS em hosts permitidos, com limite de 2 MiB por imagem e cache de texturas limitado. Quando não houver prévia disponível, aparece o ícone de imagem indisponível, sem bloquear a instalação do tema.

As resoluções disponíveis continuam 480×320, **640×480** (padrão), 854×480, 960×544 e 720×720. A compatibilidade depende do tema. O aplicativo não ativa automaticamente o tema instalado; o EmulationStation deve selecioná-lo.

Em **Configurações → Temas e cores** permanece apenas a escolha das cores da própria ROMS STORE.

## BIOS

Gerenciador de BIOS com verificação por nome, tamanho e hash, análise de pacotes, backup, restauração e importação local. As operações que alteram arquivos precisam de confirmação; arquivos só são instalados após verificação de hash. O download requer uma fonte HTTPS configurada em `bios_url.txt` e de distribuição autorizada. **Não são incluídas BIOS comerciais.**

## Instalação e atualização

A versão 0.4.4-beta já possui um atualizador OTA que aceita pacotes oficiais de 12 arquivos. O pacote da 0.4.5-beta deve ser publicado no repositório `JammesPark/R36S-ROMS-STORE-UPDATES`, passando por build, testes, SHA-256 dos ZIPs e atualização do `update.json` **apenas após confirmar a Release pública**. Enquanto isso não acontecer, o usuário deve continuar utilizando a versão publicada anteriormente.

**Arquivo manual:** `R36S_ROMS_STORE_v0.4.5-beta_TESTE.zip`, extraído em `/roms/ports/` depois de fazer backup do aplicativo. A atualização segura não inclui a pasta `state/` e preserva as configurações, favoritos e histórico.

**Código-fonte e CI:** `R36S_ROMS_STORE_v0.4.5-beta_FONTE.zip`. Em Debian/Ubuntu com LuaJIT, Lua 5.3, zip e Python 3 instalados, execute `bash tools/build.sh`. A execução do GitHub Actions realiza a validação LuaJIT antes de publicar. Os testes locais foram feitos com simulações e **ainda não substituem o teste de download e renderização no console físico**.

## Créditos e licença

Software GPL-3.0. Motor de BIOS adaptado do R36SPORTSBR STORE HUB; preservar os créditos à base original R36S PORT HUB, por Lag do Lira, e os avisos dos demais componentes em `LICENSE` e `THIRD_PARTY_NOTICES.txt`. ROMs, jogos, BIOS e temas de terceiros podem possuir licenças próprias.


## Atualizações avançadas (a partir de 0.4.6-beta)

A loja consulta automaticamente a fonte oficial, mas só instala depois de autorização.
A página **Configurações → Atualizações** oferece: **X** para backups, **Y** para histórico e **START** para atualizações locais. Em backups, **A** solicita restauração e **X** solicita exclusão; ambas exigem confirmação. Pacotes locais devem ser copiados manualmente para `r36s-roms-store/state/updates/inbox/`. A instalação ocorre após encerrar o LÖVE.

A atualização incremental é oferecida apenas para a versão-base exata indicada no feed. Quem está em versão diferente recebe o pacote completo. O SHA-256, manifesto, lista de caminhos autorizados, backup, rollback e confirmação no próximo boot permanecem obrigatórios. Retém até três backups confirmados e até 100 eventos do histórico. Para detalhes, consulte `docs/OTA_AVANCADO.md`.
