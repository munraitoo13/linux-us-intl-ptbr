#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { printf "${GREEN}[PASS]${NC} %s\n" "$*"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$*"; FAILURES=$((FAILURES + 1)); }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }

FAILURES=0

echo "=== 1. Fcitx5 ==="
if pgrep -x fcitx5 >/dev/null 2>&1; then
  pass "fcitx5 está rodando (PID $(pgrep -x fcitx5 | head -n1))"
else
  fail "fcitx5 não está rodando"
fi

if command -v busctl >/dev/null 2>&1; then
  group_info="$(busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 InputMethodGroupInfo s Default 2>/dev/null || true)"
  if [[ -n "$group_info" ]]; then
    pass "Fcitx5 grupo Default: ${group_info}"
  else
    warn "Não foi possível consultar o D-Bus do Fcitx5"
  fi
fi

echo ""
echo "=== 2. XKB (sem trema) ==="
if command -v xkbcli >/dev/null 2>&1 && [[ -f "$HOME/.config/xkb/symbols/us_notrema" ]]; then
  ac11="$(xkbcli compile-keymap --layout us_notrema 2>/dev/null | grep 'key <AC11>' || true)"
  if echo "$ac11" | grep -q "quotedbl"; then
    pass "Tecla <AC11> mapeada com aspas literais (sem dead_diaeresis)"
  else
    fail "Tecla <AC11> não contém quotedbl: ${ac11}"
  fi
else
  warn "xkbcli ou ~/.config/xkb/symbols/us_notrema ausente"
fi

echo ""
echo "=== 3. ~/.XCompose (PT-BR) ==="
if [[ -f "$HOME/.XCompose" ]]; then
  pass "~/.XCompose presente ($(wc -l < "$HOME/.XCompose") linhas)"
  if command -v xkbcli >/dev/null 2>&1 && [[ -f "$HOME/.config/xkb/symbols/us_notrema" ]]; then
    if xkbcli how-to-type --layout us_notrema 0x00e7 2>/dev/null | grep -q "dead_acute"; then
      pass "ç (U+00E7) acessível via dead_acute + c"
    else
      fail "ç (U+00E7) NÃO encontrado via dead_acute + c"
    fi

    for pair in "0x00fd:ý" "0x0144:ń" "0x1e31:ḱ" "0x00f1:ñ" "0x00e8:è" "0x00ee:î"; do
      cp="${pair%%:*}"
      ch="${pair##*:}"
      if xkbcli how-to-type --layout us_notrema "$cp" 2>/dev/null | grep -q "dead_"; then
        fail "${ch} (${cp}) ainda possui sequência de composição!"
      else
        pass "${ch} (${cp}) bloqueado"
      fi
    done
  fi
else
  fail "~/.XCompose não encontrado"
fi

echo ""
echo "=== 4. Variáveis de ambiente ==="
if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
  env_dump="$(systemctl --user show-environment 2>/dev/null || true)"
  for var in QT_IM_MODULE XMODIFIERS; do
    if echo "$env_dump" | grep -q "^${var}="; then
      pass "$(echo "$env_dump" | grep "^${var}=")"
    else
      warn "${var} não encontrado no ambiente do systemd --user (faça logout/login)"
    fi
  done
fi

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
  pass "Todas as verificações passaram!"
else
  fail "${FAILURES} verificação(ões) falharam."
  exit 1
fi
