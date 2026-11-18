# Atualizações — R36S ROMS STORE

## 0.4.13-beta — 18/11/2026
- Aplicado o conceito HTML aprovado da tela Início ao código Lua/LÖVE 11.5.
- Novo "Em destaque" com três capas verticais 2:3 acima das contagens de jogos.
- Contagens reais de Catálogo, Instalados e Favoritos organizadas em cartões inferiores.
- Navegação pelo direcional e clique/toque nas capas abre a ROM correta.
- Capas em Catálogo, Detalhes e Favoritos preservam a proporção e não são esticadas.
- Painel de download e métricas de velocidade/ETA preservados.
- Testes de geometria e regressão para a interface 640x480, sem alterar o motor OTA.

## 0.4.12-beta — 18/11/2026
- Detecção automática da resolução de exibição do console via SDL2/LÖVE.
- Fullscreen no tamanho detectado e escalonamento proporcional do layout-base 640×480.
- Margens simétricas para manter proporção de 4:3, sem cortar menus ou esticar imagens.
- Conversão dos eventos de mouse para a área virtual, ignorando cliques fora dela.
- Fallback para renderização direta 640×480 quando o driver não suporta canvas.
- Log de resolução, escala, origem da detecção e margens para diagnóstico.
- Testes automatizados de sete resoluções, troca dinâmica de modo, entrada e falhas de driver.
- OTA, backups e dados do usuário mantidos inalterados.

## 0.4.11-beta — 18/11/2026
- Tela Início agora exibe velocidade e ETA do download em andamento usando a mesma leitura da Central de Downloads.
- Faixa inferior do painel reorganizada para bytes, velocidade e tempo restante sem sobreposição em 640x480.
- Testes de regressão para garantir que Início e Downloads compartilham as mesmas métricas.
- Fila, controles de downloads e atualização OTA mantidos.

## 0.4.10-beta — 18/11/2026
- Etapa 1A: velocidade de download e ETA medidos com amostras reais na Central.
- Etapa 1B: fila FIFO persistente para ROMs, BIOS e temas; seleção e ordem de execução seguras.
- Etapa 1C: pausar, retomar e cancelar transferências em andamento; cancelar itens pendentes.
- BIOS mantida em segundo plano ao mudar de menu e identificada na Central e no Início.
- Downloads de ROMs com falha ou cancelados registrados em histórico sem manter entradas ativas travadas.
- Testes automáticos Lua/CI e Python offline para fila, controles, limites e preservação de dados.
- OTA incremental e completo inalterados; estado do usuário protegido em state/.

## 0.4.9-beta — 18/11/2026
- Ícone de Temas redesenhado como camadas, legível em 640x480.
- A resolução dos temas muda somente por L1/R1, não por setas ou clique no cabeçalho.
- Legenda Temas alinhada com botões de controle L1, R1, Y e B.
- Tela Início agora mostra o download em andamento de BIOS, ROMs, Temas ou OTA usando a mesma central de Downloads.
- Testes de interface e progresso compartilhado para impedir regressões.

## 0.4.8-beta — 18/11/2026
- Download de BIOS continua quando o usuario sai com B; X cancela explicitamente.
- Corrigidos os icones da BIOS e dos Temas no menu principal.
- Temas: lista so com nomes, sem miniaturas, e capa principal ampliada para 230x171.
- Autor e compatibilidade removidos do painel de previa; botao Instalar acessivel pelo controle ou clique.
- Cache das capas mantido, priorizando a previa do tema selecionado.

## 0.4.7-beta — 18/11/2026
- Corrigida tela azul em Downloads (main.lua:567), causada por historico antigo sem done/total.
- Normalizacao de registros antigos, calculo seguro da porcentagem e preservacao do historico.
- Mantidos ROMs, BIOS, temas, OTA e mecanismo de recuperacao.

## 0.4.6-beta — 18/11/2026
- Atualização incremental para quem está exatamente na versão-base autorizada, com fallback completo para as demais versões.
- Histórico de até 100 operações de atualização e recuperação.
- Retenção dos três backups anteriores confirmados; listagem, restauração com confirmação e exclusão individual.
- Importação local de pacotes UPDATE.zip devidamente validados em state/updates/inbox/.
- SHA-256 verificado no download, no manifesto e antes de instalar; instalação pelo lançador após o LÖVE encerrar.
- Dados de ROMs, BIOS, temas, favoritos e configurações continuam protegidos.

## 0.4.5-beta — 18/11/2026
- Navegação principal reorganizada: Início, Catálogo, BIOS, Temas, Downloads, Instalados, Favoritos, Configurações, Sobre e Sair.
- Renomeada "Loja de Temas" para "Temas" (quatro idiomas).
- Downloads: progresso de ROMs, pacote BIOS, temas EmulationStation e OTA, além de histórico dos downloads concluídos de BIOS/temas.
- Capas de temas: download de prévias PNG/JPEG em segundo plano, limite de 2 MB por capa, cache e exibição na lista e em destaque, sem depender de memória de vídeo ilimitada.
- Limites e validações de URL mantidos. Nenhuma BIOS ou ROM comercial é distribuída.
- Atualização segura sem modificar dados de `state/`, SHA-256 e rollback.

## 0.4.4-beta
- Ponte OTA para versões antigas e BIOS/Temas no menu.
