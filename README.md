# linux-us-intl-ptbr

Configuração replicável para usar teclado **US (layout americano)** no Linux com comportamento fiel ao **Windows US-International**, refinado para **Português (PT-BR)** — funcionando de forma consistente em **Wayland, X11, GTK, Qt, Electron/Chromium, terminais e XWayland**.

Baseado na tabela XCompose de [raelgc/win_us_intl](https://github.com/raelgc/win_us_intl), com melhorias para uso moderno em Linux.

---

## O que este projeto resolve

1. **Cedilha e acentos idênticos ao Windows US-Intl (PT-BR):**
   - `'` + `c` → `ç` (em vez de `ć`).
   - `'` + consoantes (ex.: `'s`, `'t`, `'n`, `'k`) → sai apóstrofo + letra, sem sumir nem gerar acentos estranhos.
   - **Sem trema:** `Shift + '` produz `"` **imediatamente** (sem dead key) via layout XKB de usuário (`us_notrema`).
   - **Apenas acentos do português:** mantém `á é í ó ú ç à â ê ô ã õ` (e maiúsculas) e remove acentos não usados no PT-BR (`ý`, `ń`, `ḱ`, `ñ`, `è`, `î`, `û`, `ä`, `ü`, etc.).
2. **Consistência em todos os apps (inclusive Electron/Wayland):**
   - Instala e configura o **Fcitx5** em modo silencioso (todos os atalhos padrão como `Ctrl+Space` são desativados para não conflitar com autocomplete de IDEs).
   - Configura variáveis de ambiente via `systemd` (`~/.config/environment.d/`), `UWSM` e `X11` (`~/.xprofile`).
   - Aplica flags de **Wayland IME** (`--enable-wayland-ime --wayland-text-input-version=3`) em apps Electron/Chromium (Antigravity IDE, VS Code, Obsidian, Discord, Chromium, Brave).

---

## Compatibilidade

- **Distros (instalação automática de pacotes):** Arch / CachyOS / Manjaro (`pacman`), Debian / Ubuntu / Pop!_OS / Mint (`apt`), Fedora / Nobara (`dnf`), openSUSE (`zypper`). Outras distros funcionam usando `--no-packages`.
- **Sessões:** Wayland e X11.
- **Ambientes:** Hyprland (`.lua` e `.conf`, com ou sem UWSM), GNOME, KDE Plasma, Sway, i3, Xfce, Cinnamon, etc.

---

## Como usar

### Instalação completa (recomendado)

```bash
cd ~/Projects/linux-us-intl-ptbr
./install.sh
```

Após concluir, faça **logout/login** (ou reinicie os apps já abertos) e valide com:

```bash
./verify.sh
```

### Opções úteis do `install.sh`

| Flag | O que faz |
|---|---|
| `--dry-run` | Simula a execução sem alterar nenhum arquivo |
| `--no-packages` | Pula a instalação do `fcitx5` via gerenciador de pacotes (`sudo`) |
| `--no-system-keymap` | Pula o `sudo localectl set-x11-keymap us pc105 intl` |
| `--keep-trema` | Mantém o `us(intl)` padrão (sem remover a dead key de trema em `"`) |
| `--only <módulo>` | Executa apenas um módulo: `packages`, `xkb`, `xcompose`, `fcitx5`, `env`, `electron` ou `de` |

Exemplos:

```bash
# Testar antes de aplicar
./install.sh --dry-run

# Aplicar apenas o XCompose e o Fcitx5 (sem sudo)
./install.sh --only xcompose
./install.sh --only fcitx5
```

---

## Notas por ambiente gráfico

O `install.sh` configura automaticamente Hyprland (`inputs.lua`), GNOME (`gsettings`) e X11 (`setxkbmap`). Em outros ambientes:

- **Hyprland (`hyprland.conf`):** adicione no bloco `input { ... }`:
  ```ini
  kb_layout = us_notrema
  kb_variant = basic
  ```
- **Sway (`~/.config/sway/config`):**
  ```ini
  input type:keyboard {
      xkb_layout us_notrema
      xkb_variant basic
  }
  ```
- **KDE Plasma (Wayland):** em *System Settings → Keyboard → Virtual Keyboard*, selecione **Fcitx 5** e em *Layouts* adicione **English (US, intl., no trema)**.

---

## Estrutura do projeto

```text
linux-us-intl-ptbr/
├── install.sh        # Instalador modular e idempotente (com backup automático)
├── verify.sh         # Diagnóstico de Fcitx5, XKB, XCompose e variáveis de ambiente
├── uninstall.sh      # Reverte overrides e customizações de usuário
├── README.md
└── assets/
    ├── XCompose      # Tabela US-Intl PT-BR (sem trema e sem acentos estrangeiros)
    ├── xkb/
    │   ├── symbols/us_notrema   # Layout us(intl) com Shift+' literal
    │   └── rules/evdev.xml      # Registro do layout para Fcitx5/libxkbcommon
    └── fcitx5/
        ├── config               # Atalhos limpos (não rouba Ctrl+Space)
        ├── profile              # Layout padrão keyboard-us_notrema
        └── conf/                # Desativa atalhos de clipboard/unicode/quickphrase
```

---

## Backups e desinstalação

Todo arquivo existente modificado pelo `install.sh` recebe backup automático em:

```text
~/.local/share/linux-us-intl-ptbr/backups/<timestamp>/
```

Para remover as customizações:

```bash
./uninstall.sh
```
