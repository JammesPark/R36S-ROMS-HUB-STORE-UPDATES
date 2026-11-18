# Atualizações — R36S ROMS STORE

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
