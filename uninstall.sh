#!/usr/bin/env bash
set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }

info "Removendo customizações de usuário do linux-us-intl-ptbr..."

rm -f "$HOME/.config/xkb/symbols/us_notrema"
rm -f "$HOME/.config/xkb/rules/evdev.xml"
rmdir -p "$HOME/.config/xkb/symbols" "$HOME/.config/xkb/rules" 2>/dev/null || true

rm -f "$HOME/.config/environment.d/90-fcitx5.conf"
rm -f "$HOME/.local/share/applications/antigravity.desktop"
rm -f "$HOME/.local/share/applications/discord.desktop"
rm -f "$HOME/.local/bin/antigravity"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

if [[ -f "$HOME/.config/hypr/config/inputs.lua" ]]; then
  sed -i -E 's|(kb_layout\s*=\s*")us_notrema(")|\1us\2|' "$HOME/.config/hypr/config/inputs.lua"
  sed -i -E 's|(kb_variant\s*=\s*")basic(")|\1intl\2|' "$HOME/.config/hypr/config/inputs.lua"
  command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
fi

warn "Arquivos não apagados automaticamente (remova manualmente se desejar):"
echo "  - ~/.XCompose"
echo "  - ~/.config/fcitx5/"
echo "  - ~/.config/uwsm/env (linhas de IM)"
echo "  - ~/.config/*flags.conf"
echo "  - Backups anteriores em: ${XDG_DATA_HOME:-$HOME/.local/share}/linux-us-intl-ptbr/backups/"

ok "Desinstalação concluída. Faça logout/login para aplicar."
