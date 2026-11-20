#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/linux-us-intl-ptbr"
BACKUP_DIR="${STATE_DIR}/backups/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
INSTALL_PACKAGES=true
SET_SYSTEM_KEYMAP=true
KEEP_TREMA=false
ONLY_MODULE=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}[ERR]${NC} %s\n" "$*" >&2; }

usage() {
  cat << 'EOF'
Uso: ./install.sh [opções]

Configura o layout US-International estilo Windows adaptado para Português (PT-BR)
em sistemas Linux modernos (Wayland e X11) usando XKB + XCompose + Fcitx5.

Opções:
  --dry-run            Mostra o que seria feito sem alterar arquivos
  --no-packages        Pula a instalação de pacotes via gerenciador (sudo)
  --no-system-keymap   Pula a atualização do keymap do sistema (localectl)
  --keep-trema         Mantém o layout us(intl) padrão (Shift+' continua dead_diaeresis)
  --only <módulo>      Executa apenas um módulo:
                         packages | xkb | xcompose | fcitx5 | env | electron | de
  -h, --help           Exibe esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)          DRY_RUN=true ;;
    --no-packages)      INSTALL_PACKAGES=false ;;
    --no-system-keymap) SET_SYSTEM_KEYMAP=false ;;
    --keep-trema)       KEEP_TREMA=true ;;
    --only)
      shift
      ONLY_MODULE="${1:-}"
      [[ -z "$ONLY_MODULE" ]] && { error "--only requer o nome de um módulo"; exit 1; }
      ;;
    -h|--help)          usage; exit 0 ;;
    *)                  error "Opção desconhecida: $1"; usage; exit 1 ;;
  esac
  shift
done

run() {
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
  else
    "$@"
  fi
}

backup_file() {
  local target="$1"
  if [[ -f "$target" ]]; then
    local rel="${target#$HOME/}"
    local dest="${BACKUP_DIR}/${rel}"
    if $DRY_RUN; then
      printf "${YELLOW}[DRY-RUN]${NC} backup %s -> %s\n" "$target" "$dest"
    else
      mkdir -p "$(dirname "$dest")"
      cp -a "$target" "$dest"
    fi
  fi
}

should_run() {
  local mod="$1"
  [[ -z "$ONLY_MODULE" || "$ONLY_MODULE" == "$mod" ]]
}

detect_session() {
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "wayland"
  else
    echo "x11"
  fi
}

SESSION_TYPE="$(detect_session)"
LAYOUT_NAME="us_notrema"
LAYOUT_VARIANT="basic"
FCITX_IM="keyboard-us_notrema"

if $KEEP_TREMA; then
  LAYOUT_NAME="us"
  LAYOUT_VARIANT="intl"
  FCITX_IM="keyboard-us-intl"
fi

# ---------------------------------------------------------------------------
# 1. Packages (Fcitx5 + GTK/Qt modules)
# ---------------------------------------------------------------------------
install_packages() {
  if ! $INSTALL_PACKAGES; then
    info "Pulando instalação de pacotes (--no-packages)."
    return
  fi

  info "Instalando Fcitx5 e módulos GTK/Qt..."
  if command -v pacman >/dev/null 2>&1; then
    run sudo pacman -S --needed --noconfirm fcitx5 fcitx5-gtk fcitx5-qt
  elif command -v apt-get >/dev/null 2>&1; then
    run sudo apt-get update
    run sudo apt-get install -y fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6
  elif command -v dnf >/dev/null 2>&1; then
    run sudo dnf install -y fcitx5 fcitx5-gtk fcitx5-qt
  elif command -v zypper >/dev/null 2>&1; then
    run sudo zypper install -y fcitx5 fcitx5-gtk fcitx5-qt
  else
    warn "Gerenciador de pacotes não reconhecido. Instale manualmente: fcitx5, fcitx5-gtk e fcitx5-qt."
    return
  fi
  ok "Pacotes do Fcitx5 verificados/instalados."
}

# ---------------------------------------------------------------------------
# 2. Custom XKB layout (us_notrema) + system keymap
# ---------------------------------------------------------------------------
install_xkb() {
  if ! $KEEP_TREMA; then
    info "Instalando layout XKB de usuário (us_notrema)..."
    run mkdir -p "$HOME/.config/xkb/symbols" "$HOME/.config/xkb/rules"
    backup_file "$HOME/.config/xkb/symbols/us_notrema"
    backup_file "$HOME/.config/xkb/rules/evdev.xml"
    run cp "${ASSETS_DIR}/xkb/symbols/us_notrema" "$HOME/.config/xkb/symbols/us_notrema"
    run cp "${ASSETS_DIR}/xkb/rules/evdev.xml" "$HOME/.config/xkb/rules/evdev.xml"
    ok "Layout us_notrema instalado em ~/.config/xkb/."
  else
    info "Mantendo layout us(intl) padrão (--keep-trema)."
  fi

  if $SET_SYSTEM_KEYMAP && command -v localectl >/dev/null 2>&1; then
    info "Definindo keymap base do sistema (us/intl) via localectl..."
    run sudo localectl set-x11-keymap us pc105 intl
    ok "Keymap do sistema atualizado."
  fi
}

# ---------------------------------------------------------------------------
# 3. ~/.XCompose (Windows US-Intl PT-BR)
# ---------------------------------------------------------------------------
install_xcompose() {
  info "Instalando ~/.XCompose (US-Intl PT-BR)..."
  backup_file "$HOME/.XCompose"
  if $KEEP_TREMA; then
    if $DRY_RUN; then
      printf "${YELLOW}[DRY-RUN]${NC} instalar ~/.XCompose mantendo trema\n"
    else
      grep -vE '^<dead_diaeresis> <[AEIOUa-eiouy]>' "${ASSETS_DIR}/XCompose" > "$HOME/.XCompose"
    fi
  else
    run cp "${ASSETS_DIR}/XCompose" "$HOME/.XCompose"
  fi
  ok "~/.XCompose instalado."
}

# ---------------------------------------------------------------------------
# 4. Fcitx5 configuration (silencioso, sem roubar Ctrl+Space)
# ---------------------------------------------------------------------------
install_fcitx5() {
  info "Configurando Fcitx5 (layout ${FCITX_IM}, sem conflito de atalhos)..."
  if ! $DRY_RUN; then
    pkill -x fcitx5 2>/dev/null || true
    sleep 1
  fi

  run mkdir -p "$HOME/.config/fcitx5/conf"
  backup_file "$HOME/.config/fcitx5/config"
  backup_file "$HOME/.config/fcitx5/profile"

  run cp "${ASSETS_DIR}/fcitx5/config" "$HOME/.config/fcitx5/config"
  run cp "${ASSETS_DIR}/fcitx5/conf/clipboard.conf" "$HOME/.config/fcitx5/conf/clipboard.conf"
  run cp "${ASSETS_DIR}/fcitx5/conf/unicode.conf" "$HOME/.config/fcitx5/conf/unicode.conf"
  run cp "${ASSETS_DIR}/fcitx5/conf/quickphrase.conf" "$HOME/.config/fcitx5/conf/quickphrase.conf"

  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} escrever ~/.config/fcitx5/profile (%s)\n" "$FCITX_IM"
  else
    cat << EOF > "$HOME/.config/fcitx5/profile"
[Groups/0]
Name=Default
Default Layout=${LAYOUT_NAME}
DefaultIM=${FCITX_IM}

[Groups/0/Items/0]
Name=${FCITX_IM}
Layout=

[GroupOrder]
0=Default
EOF
  fi

  if command -v fcitx5 >/dev/null 2>&1; then
    if ! $DRY_RUN; then
      nohup fcitx5 -d >/dev/null 2>&1 &
      sleep 1
    fi
    ok "Fcitx5 configurado e iniciado."
  else
    warn "Binário fcitx5 não encontrado no PATH; arquivos de configuração gravados."
  fi
}

# ---------------------------------------------------------------------------
# 5. Environment variables (Wayland / UWSM / systemd / X11)
# ---------------------------------------------------------------------------
install_env() {
  info "Configurando variáveis de ambiente para sessão ${SESSION_TYPE}..."

  # 5a. systemd environment.d (funciona na maioria das distros modernas: GNOME, KDE, Sway, Hyprland)
  local envd_dir="$HOME/.config/environment.d"
  local envd_file="${envd_dir}/90-fcitx5.conf"
  run mkdir -p "$envd_dir"
  backup_file "$envd_file"

  if ! $DRY_RUN; then
    {
      echo "# Gerado por linux-us-intl-ptbr"
      echo "QT_IM_MODULES=wayland;fcitx;ibus"
      echo "QT_IM_MODULE=fcitx"
      echo "XMODIFIERS=@im=fcitx"
      echo "SDL_IM_MODULE=fcitx"
      echo "GLFW_IM_MODULE=ibus"
      if [[ "$SESSION_TYPE" == "x11" ]]; then
        echo "GTK_IM_MODULE=fcitx"
      fi
    } > "$envd_file"
  fi

  # 5b. UWSM (se presente)
  if [[ -f "$HOME/.config/uwsm/env" ]]; then
    if ! grep -q "XMODIFIERS" "$HOME/.config/uwsm/env"; then
      backup_file "$HOME/.config/uwsm/env"
      if ! $DRY_RUN; then
        cat << 'EOF' >> "$HOME/.config/uwsm/env"

# Input Method (Fcitx5 + XCompose)
export QT_IM_MODULES="wayland;fcitx;ibus"
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF
      fi
    fi
  fi

  # 5c. X11 (~/.xprofile)
  if [[ "$SESSION_TYPE" == "x11" ]]; then
    backup_file "$HOME/.xprofile"
    if ! grep -q "XMODIFIERS" "$HOME/.xprofile" 2>/dev/null; then
      if ! $DRY_RUN; then
        cat << 'EOF' >> "$HOME/.xprofile"

# Input Method (Fcitx5 + XCompose)
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF
      fi
    fi
  fi

  # Aplica na sessão atual do systemd --user (se disponível)
  if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    run systemctl --user set-environment \
      QT_IM_MODULES="wayland;fcitx;ibus" \
      QT_IM_MODULE=fcitx \
      XMODIFIERS="@im=fcitx" \
      SDL_IM_MODULE=fcitx \
      GLFW_IM_MODULE=ibus
  fi

  ok "Variáveis de ambiente configuradas."
}

# ---------------------------------------------------------------------------
# 6. Electron / Chromium Wayland IME flags
# ---------------------------------------------------------------------------
append_ime_flags() {
  local file="$1"
  run mkdir -p "$(dirname "$file")"
  if [[ -f "$file" ]] && grep -q "enable-wayland-ime" "$file"; then
    return
  fi
  backup_file "$file"
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} adicionar flags Wayland IME em %s\n" "$file"
  else
    printf -- "--enable-wayland-ime\n--wayland-text-input-version=3\n" >> "$file"
  fi
}

patch_desktop_ime() {
  local app="$1"
  local src="/usr/share/applications/${app}.desktop"
  local dst="$HOME/.local/share/applications/${app}.desktop"
  [[ -f "$src" ]] || return 0

  run mkdir -p "$HOME/.local/share/applications"
  backup_file "$dst"
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} criar override %s com flags Wayland IME\n" "$dst"
  else
    cp "$src" "$dst"
    if ! grep -q "enable-wayland-ime" "$dst"; then
      sed -i "s|^Exec=\([^ ]*\) |Exec=\1 --enable-wayland-ime --wayland-text-input-version=3 |" "$dst"
    fi
  fi
}

install_electron() {
  if [[ "$SESSION_TYPE" != "wayland" ]]; then
    info "Sessão X11 detectada; flags de Wayland IME para Electron não são necessárias."
    return
  fi

  info "Configurando flags Wayland IME para apps Electron/Chromium..."
  append_ime_flags "$HOME/.config/electron-flags.conf"

  command -v code >/dev/null 2>&1      && append_ime_flags "$HOME/.config/code-flags.conf"
  command -v chromium >/dev/null 2>&1  && append_ime_flags "$HOME/.config/chromium-flags.conf"
  command -v brave >/dev/null 2>&1     && append_ime_flags "$HOME/.config/brave-flags.conf"
  command -v obsidian >/dev/null 2>&1  && append_ime_flags "$HOME/.config/obsidian/user-flags.conf"

  patch_desktop_ime "antigravity"
  patch_desktop_ime "discord"

  # Wrapper CLI para antigravity no terminal
  if [[ -x "/usr/bin/antigravity" ]]; then
    run mkdir -p "$HOME/.local/bin"
    backup_file "$HOME/.local/bin/antigravity"
    if ! $DRY_RUN; then
      cat << 'EOF' > "$HOME/.local/bin/antigravity"
#!/bin/sh
exec /usr/bin/antigravity --enable-wayland-ime --wayland-text-input-version=3 "$@"
EOF
      chmod +x "$HOME/.local/bin/antigravity"
    fi
  fi

  if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  fi

  ok "Flags Wayland IME para Electron/Chromium aplicadas."
}

# ---------------------------------------------------------------------------
# 7. Desktop Environment / Window Manager integration
# ---------------------------------------------------------------------------
install_de() {
  info "Configurando integração com o Desktop/Compositor..."

  # Hyprland (Lua config)
  if [[ -f "$HOME/.config/hypr/config/inputs.lua" ]]; then
    backup_file "$HOME/.config/hypr/config/inputs.lua"
    if ! $DRY_RUN; then
      sed -i -E "s|(kb_layout\s*=\s*\")[^\"]*(\")|\1${LAYOUT_NAME}\2|" "$HOME/.config/hypr/config/inputs.lua"
      sed -i -E "s|(kb_variant\s*=\s*\")[^\"]*(\")|\1${LAYOUT_VARIANT}\2|" "$HOME/.config/hypr/config/inputs.lua"
    fi
    command -v hyprctl >/dev/null 2>&1 && run hyprctl reload || true
    ok "Hyprland (inputs.lua) atualizado para ${LAYOUT_NAME}/${LAYOUT_VARIANT}."
  elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
    warn "Hyprland (.conf) detectado. Garanta em input { ... }: kb_layout = ${LAYOUT_NAME} e kb_variant = ${LAYOUT_VARIANT}."
  fi

  # GNOME
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && command -v gsettings >/dev/null 2>&1; then
    run gsettings set org.gnome.desktop.input-sources sources "[('xkb', '${LAYOUT_NAME}+${LAYOUT_VARIANT}')]" || true
    ok "GNOME input-sources atualizado."
  fi

  # X11 ao vivo
  if [[ "$SESSION_TYPE" == "x11" ]] && command -v setxkbmap >/dev/null 2>&1; then
    run setxkbmap -layout "$LAYOUT_NAME" -variant "$LAYOUT_VARIANT" || true
  fi
}

# ---------------------------------------------------------------------------
# Execução principal
# ---------------------------------------------------------------------------
info "Sessão detectada: ${SESSION_TYPE} | Layout alvo: ${LAYOUT_NAME} (${LAYOUT_VARIANT})"

should_run "packages" && install_packages
should_run "xkb"      && install_xkb
should_run "xcompose" && install_xcompose
should_run "fcitx5"   && install_fcitx5
should_run "env"      && install_env
should_run "electron" && install_electron
should_run "de"       && install_de

echo ""
ok "Instalação concluída! Rode ./verify.sh para validar."
if [[ -d "$BACKUP_DIR" ]]; then
  info "Backups salvos em: ${BACKUP_DIR}"
fi
info "Recomendação: faça logout/login (ou reinicie apps abertos) para que todos os programas herdem o ambiente novo."
