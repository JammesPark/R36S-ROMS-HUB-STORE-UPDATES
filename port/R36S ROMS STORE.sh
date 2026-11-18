#!/usr/bin/env bash
# R36S ROMS STORE - inicializador LÖVE 11.5 / PortMaster.
# Os erros sao registrados em r36s-roms-store/log.txt, mesmo sem imagem.
set -o pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
APP="$BASE/r36s-roms-store"
LOG="$APP/log.txt"
UPDATER="$APP/bin/store_updater.py"
# Reaproveita dados de uma instalacao anterior sem copiar os binarios antigos.
# O padrao so procura instalacoes antigas desta familia no SD1.
# Nao sobrescreve preferencias do aplicativo novo e nao exclui o anterior.
if [[ ! -f "$APP/state/.migration_checked" ]]; then
  mkdir -p "$APP/state" || exit 1
  for legacy in "$BASE"/r36s-store-*; do
    [[ -d "$legacy/state" && ! -L "$legacy" && "$legacy" != "$APP" ]] || continue
    for item in roms_settings.json roms_favorites.json roms_downloads.json gamestore_categories.json gamestore_games.json; do
      if [[ -f "$legacy/state/$item" && ! -e "$APP/state/$item" && ! -L "$legacy/state/$item" ]]; then
        cp -p -- "$legacy/state/$item" "$APP/state/$item" || echo "AVISO: nao foi possivel migrar $item" >&2
      fi
    done
    # Capas sao cache opcional e serao carregadas novamente se necessario.
    break
  done
  : > "$APP/state/.migration_checked"
fi
if ! mkdir -p "$APP/state/logs" "$APP/state/installations" "$APP/conf"; then
  echo "ERRO: nao foi possivel criar pastas em $APP" >&2
  exit 1
fi
exec > >(tee "$LOG" "$APP/state/logs/startup.log") 2>&1
echo "=== R36S ROMS STORE - STARTUP ==="
echo "Data: $(date -u +%FT%TZ)"
echo "Sistema: $(uname -a)"
echo "Launcher: $0"
echo "GAME: $APP/game.love"
fail() {
  echo "FALHA DE INICIALIZACAO: $*"
  echo "Veja o log: $LOG"
  exit 1
}
[[ -s "$APP/game.love" ]] || fail "game.love ausente ou vazio"
# Reverte atualizações interrompidas por perda de energia antes de abrir o app.
if [[ -f "$APP/state/updates/pending_health.json" ]]; then
  echo "Atualização anterior sem confirmação de boot: restaurando backup..."
  python3 "$UPDATER" recover || fail "Falha ao restaurar atualização interrompida"
fi
export R36S_STORE_HOME="$APP"
ORIGINAL_XDG="${XDG_DATA_HOME:-${HOME:-/home/ark}/.local/share}"
CONTROL=''
CANDIDATES=(
  "${R36S_PORTMASTER_DIR:-}"
  "/opt/system/Tools/PortMaster"
  "/opt/tools/PortMaster"
  "$ORIGINAL_XDG/PortMaster"
  "/roms/ports/PortMaster"
  "/roms2/ports/PortMaster"
)
for candidate in "${CANDIDATES[@]}"; do
  if [[ -n "$candidate" && -f "$candidate/control.txt" ]]; then
    CONTROL="$candidate"
    break
  fi
done
runtime=none
if [[ -n "$CONTROL" ]]; then
  echo "PortMaster: $CONTROL"
  if ! source "$CONTROL/control.txt"; then
    echo "AVISO: control.txt falhou"
  fi
  if [[ -n "${CFW_NAME:-}" && -f "$CONTROL/mod_${CFW_NAME}.txt" ]]; then
    source "$CONTROL/mod_${CFW_NAME}.txt" || echo "AVISO: mod da CFW falhou"
  fi
  if declare -F get_controls >/dev/null 2>&1; then
    get_controls || echo "AVISO: get_controls falhou"
  fi
  LOVE_SETUP="$CONTROL/runtimes/love_11.5/love.txt"
  if [[ -f "$LOVE_SETUP" ]]; then
    echo "Carregando runtime LÖVE 11.5 do PortMaster"
    if source "$LOVE_SETUP" && [[ -n "${LOVE_RUN:-}" ]]; then
      runtime=portmaster
    else
      echo "AVISO: LOVE_RUN nao definido pelo runtime"
    fi
  else
    echo "AVISO: love_11.5/love.txt nao encontrado no PortMaster"
  fi
else
  echo "AVISO: control.txt do PortMaster nao encontrado"
fi
SYSTEM_LOVE=''
if [[ "$runtime" == none ]]; then
  SYSTEM_LOVE="$(command -v love 2>/dev/null || true)"
  [[ -n "$SYSTEM_LOVE" ]] || fail "LÖVE nao encontrado. Instale/atualize PortMaster com LÖVE 11.5."
  runtime=system
fi
echo "Runtime selecionado: $runtime"
if [[ "$runtime" == portmaster ]]; then
  echo "LOVE_RUN: ${LOVE_RUN:-indefinido}"
  echo "LOVE_BINARY: ${LOVE_BINARY:-indefinido}"
else
  echo "LOVE_BIN: $SYSTEM_LOVE"
fi

export XDG_DATA_HOME="$APP/conf"
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
cd "$APP" || fail "Nao foi possivel entrar na pasta do aplicativo"
if [[ "$runtime" == portmaster ]]; then
  # Entrada exclusiva via SDL2/LÖVE: sem GPTOKEYB e sem teclas duplicadas.
  if declare -F pm_platform_helper >/dev/null 2>&1 && [[ -n "${LOVE_BINARY:-}" ]]; then
    pm_platform_helper "$LOVE_BINARY" || echo "AVISO: pm_platform_helper retornou erro"
  fi
fi
UPDATE_RETRY=0
while true; do
  rm -f "$APP/state/launch.request"
  echo "Iniciando interface LÖVE 640x480..."
  if [[ "$runtime" == portmaster ]]; then
    $LOVE_RUN "$APP/game.love"
    code=$?
  else
    "$SYSTEM_LOVE" "$APP/game.love"
    code=$?
  fi
  echo "LÖVE encerrou com codigo: $code"
  if [[ "$code" -ne 0 ]]; then
    if [[ -f "$APP/state/updates/pending_health.json" && "$UPDATE_RETRY" -eq 0 ]]; then
      echo "Falha no primeiro boot da atualização: rollback automático"
      python3 "$UPDATER" rollback || fail "Falha no rollback"
      UPDATE_RETRY=1
      continue
    fi
    fail "Falha no runtime LÖVE (codigo $code)"
  fi
  # Somente o launcher aplica atualização: LÖVE não altera seu arquivo em uso.
  if [[ -f "$APP/state/store_update_apply.request" ]]; then
    echo "Aplicando pacote de atualização verificado..."
    python3 "$UPDATER" apply || fail "Instalação da atualização falhou"
    UPDATE_RETRY=0
    echo "Atualização aplicada, reiniciando interface..."
    continue
  fi
  if [[ -f "$APP/state/updates/pending_health.json" ]]; then
    python3 "$UPDATER" confirm || fail "Não foi possível confirmar a atualização"
  fi
  [[ -f "$APP/state/launch.request" ]] || break
  IFS= read -r SCRIPT < "$APP/state/launch.request"
  case "$SCRIPT" in
    /roms/ports/*.sh|/roms2/ports/*.sh) ;;
    *) fail "Caminho de script do jogo invalido" ;;
  esac
  [[ -f "$SCRIPT" && ! -L "$SCRIPT" ]] || fail "Jogo solicitado nao existe: $SCRIPT"
  echo "Executando port externo: $SCRIPT"
  bash "$SCRIPT" || echo "AVISO: o port externo encerrou com erro"
done
if [[ "$runtime" == portmaster ]] && declare -F pm_finish >/dev/null 2>&1; then
  pm_finish || echo "AVISO: pm_finish retornou erro"
fi
echo "Loja encerrada normalmente."
