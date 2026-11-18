# Integração e isolamento de dados

- Entrada no menu: Menu principal → BIOS, independente de Configurações.
- `src/bios_enhanced_ui.lua`: controlador e renderizador da interface de BIOS nativa 640×480.
- `src/roms_bios/`: motor BIOS adaptado e suas dependências.
- `src/bios_manager.lua` e `port/r36s-roms-store/bin/bios_manager.py`: motor anterior mantido,
  acessível pela aba Local (não apagar backups existentes).
- `port/r36s-roms-store/bin/fetch.sh`: downloads por HTTPS com certificado TLS verificado.
- `port/r36s-roms-store/bin/7zzs`: ferramenta de extração usada em pacotes suportados.

## Caminhos

Os dados do gerenciador novo são isolados em:
- `<app>/bios/` (registro, histórico, estado e arquivos temporários)
- `<app>/backups/bios/` (backups do gerenciador avançado)

Os dados do gerenciador antigo permanecem em:
- `<app>/state/bios_manager/` e `<app>/state/bios_import/`.

A seleção de destino das BIOS segue a configuração real de sistema do RetroArch quando
acessível, e usa os diretórios existentes `/roms/bios` e `/roms2/bios` como fallback.
Não cria automaticamente pasta BIOS quando ausente.

## Segurança

- Sem BIOS embutidas; URL HTTPS padrão herdada do HUB (sem garantias de disponibilidade/licenciamento).
- Fonte permitida somente `https://` com verificação TLS (não há `-k`).
- BIOS de pacote só entram na seleção automática quando verificadas por hash do banco.
- Instalação, download, limpeza e restauração só depois de confirmação explícita.
- Sem atualização direta dos outros projetos, e sem integração à fila geral de ROMs.
- Quando a atualização do app for implementada, proteger `bios/`, `backups/bios/`,
  `state/` e `conf/` contra sobrescrita/apagamento.

## Atenção

Esta versão é beta. Testes sem BIOS reais comprovam somente navegação/estrutura;
valide no console antes de usar instalação e restauração em BIOS importantes.
