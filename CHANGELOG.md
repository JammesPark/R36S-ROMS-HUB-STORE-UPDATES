# Alterações da v0.4.3-beta

- BIOS movida para o menu principal, fora de Configurações.
- Loja de Temas EmulationStation adicionada ao menu principal (separada das cores do app).
- Navegação compactada para 10 opções em 640x480, com mouse e D-pad alinhados.
- Catálogo ThemeMaster/OGA adaptado, incluindo consulta ao GitHub e cache offline.
- Seleção de resolução com padrão 640x480 e verificação de compatibilidade.
- Instalação de temas confirmada, com ZIP validado e backup do tema anterior.
- Fonte HTTPS padrão de BIOS herdada do HUB; substituível via bios_url.txt.
- Dados e funcionamento da PORTS STORE não foram modificados.

# Alterações da v0.4.2-beta

- Base v0.4.1-beta_TESTE da ROMS STORE mantida integralmente, com identidade visual nativa.
- Função handleKey subdividida; contagem de upvalues reduzida de 64 para 55 para o LuaJIT.
- Inclusão de backend separado `roms_bios`, análise de pacote/hash, controle de arquivos,
  confirmação de substituição, backup/restauração e histórico.
- Quatro abas na seção BIOS, visual nativo e quatro traduções, com gerenciador local antigo preservado.
- Fonte HTTPS obrigatória configurada via `bios_url.txt` no diretório do aplicativo;
  sem links de BIOS pré-instalados ou arquivos de firmware distribuídos.
- Scripts auxiliares de fetch/7zzs e avisos de licenças incluídos.
- Nenhum dado de `state/`/`conf/` instalado ou sobrescrito pelo pacote.

## 0.4.4-beta — Migração OTA segura
- Pacote OTA-ponte com 8 arquivos para preservar clientes 0.4.1-beta.
- Auxiliares da Loja de Temas e BIOS embutidos no `game.love` e restaurados na primeira execução, se ausentes.
- Atualizador passa a aceitar formato de atualização completo (12 arquivos) nas versões futuras.
- GitHub Actions: validações, hashes, build de TESTE/FONTE/UPDATE, publicação em Releases e manifesto após sucesso, com token autorizado.
- Backups, estado e rollback mantidos, sem alteração em ROMs nem cartões SD.
