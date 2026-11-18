#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
VERSION="$(tr -d '\r\n' < VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-beta$ ]] || { echo 'VERSION inválida' >&2; exit 1; }
command -v zip >/dev/null || { echo 'instale zip' >&2; exit 1; }
mkdir -p build
# LuaJIT exigido no CI de publicação, mas build local também pode ser gerado
# sem o interpretador; isso NÃO equivale a validar a sintaxe para console.
if command -v luajit >/dev/null; then
  while IFS= read -r -d '' file; do luajit -b "$file" /tmp/r36s_roms_file.lua.bytecode >/dev/null; done < <(find src -type f -name '*.lua' -print0)
else
  echo 'AVISO: LuaJIT ausente; o CI precisa realizar a validação de bytecode antes de publicar.' >&2
  [[ "${CI:-}" != true ]] || exit 1
fi
if command -v lua5.3 >/dev/null; then
  lua5.3 tests/test_bios_ui.lua
  lua5.3 tests/test_es_themes_ui.lua
  lua5.3 tests/test_transfer_center.lua
  lua5.3 tests/test_ota_bootstrap.lua
fi
python3 tests/test_es_theme_manager.py
python3 tests/test_es_theme_previews.py
python3 tests/test_main_menu.py
printf '%s\n' "$VERSION" > src/VERSION
printf '%s\n' "$VERSION" > port/r36s-roms-store/VERSION
rm -f port/r36s-roms-store/game.love
(cd src && zip -X -q -r ../port/r36s-roms-store/game.love .)
python3 tools/build_ota.py
python3 tests/test_ota_update.py
