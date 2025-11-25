# Colar com clique direito no terminal (X11 / Cinnamon)

Este guia descreve como mapear o clique direito do mouse para executar um "colar" (Ctrl+Shift+V) apenas quando a janela em foco for um terminal, usando `xbindkeys` + `xdotool` no X11 (Cinnamon usa Xorg por padrão).

IMPORTANTE: isto funciona em X11. Em Wayland essas ferramentas geralmente não funcionam.

---

## Resumo das etapas

- Instalar dependências: `xbindkeys` e `xdotool`.
- Criar um pequeno script que detecta se a janela focada é um terminal e envia `Ctrl+Shift+V` para ela; caso contrário reenvia o clique direito.
- Criar `~/.xbindkeysrc` apontando para o script para o botão 3 (right click).
- Iniciar `xbindkeys` e adicionar à inicialização (opcional).
- Testar e ajustar a lista de terminais (WM_CLASS) se necessário.

---

## Comandos (copiar/colar)

1) Instalar as ferramentas:

```bash
sudo apt update
sudo apt install -y xbindkeys xdotool
```

2) Criar o script (cria em `~/.local/bin/rightclick-paste-if-terminal.sh`):

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/rightclick-paste-if-terminal.sh <<'EOF'
#!/usr/bin/env bash
# rightclick-paste-if-terminal.sh
# Se a janela focada for um terminal, envia Ctrl+Shift+V para colar.
# Caso contrário, reenvia o clique direito (botão 3).

WIN_ID=$(xdotool getwindowfocus 2>/dev/null)
if [ -z "$WIN_ID" ]; then
  exit 0
fi

WM_CLASS=$(xprop -id "$WIN_ID" WM_CLASS 2>/dev/null | tr -d '"' | tr ',' ' ')

# Ajuste a regex abaixo conforme o nome do seu terminal
if echo "$WM_CLASS" | grep -E -i "gnome-terminal|gnome-terminal-server|konsole|xfce4-terminal|terminator|xterm|urxvt|kitty|alacritty|tilix|st" >/dev/null; then
  xdotool key --window "$WIN_ID" ctrl+shift+v
else
  # reenviar clique direito para a janela (pode não replicar 100% do contexto em alguns apps)
  xdotool click --window "$WIN_ID" 3
fi
EOF

chmod +x ~/.local/bin/rightclick-paste-if-terminal.sh
```

3) Criar `~/.xbindkeysrc` para mapear o botão direito ao script:

```bash
cat > ~/.xbindkeysrc <<'EOF'
# Right-click paste in terminal windows
"$HOME/.local/bin/rightclick-paste-if-terminal.sh"
    b:3
EOF
```

4) Iniciar `xbindkeys` agora (para testar):

```bash
# inicia em background; se já estiver rodando, reinicie-o
pkill xbindkeys || true
xbindkeys
```

5) Adicionar `xbindkeys` à inicialização (opções):

- Método GUI (Cinnamon): Menu → Preferences → Startup Applications → Add → Command: `xbindkeys`.
- Ou criar um arquivo `.desktop` em `~/.config/autostart/xbindkeys.desktop`:

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/xbindkeys.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=xbindkeys
Exec=xbindkeys
X-GNOME-Autostart-enabled=true
EOF
```

---

## Teste

- Abra seu terminal (por exemplo `gnome-terminal`), copie algum texto para a área de transferência (Ctrl+C) ou copie texto para PRIMARY selecionando com o mouse.
- Foque a janela do terminal e clique com o botão direito. O script deve enviar `Ctrl+Shift+V` e o texto deve ser colado.
- Foque outra aplicação (por exemplo navegador) e clique direito: o menu de contexto deve aparecer (ou o script reenviará o clique, se aplicável).

Se não funcionar, veja o log com:

```bash
# ver se xbindkeys está rodando
pgrep -a xbindkeys
# testar manualmente o script (com a janela alvo em foco)
~/.local/bin/rightclick-paste-if-terminal.sh
```

---

## Personalizações e ajustes

- Ajustar lista de terminais: se o seu terminal não estiver listado, descubra seu `WM_CLASS` com:

```bash
xprop | grep WM_CLASS
# depois clique na janela do terminal
```

Adicione o texto retornado (por exemplo `"my-terminal", "My-terminal"`) à regex do `grep -E` no script.

- Se quiser que o clique direito envie apenas `Ctrl+V` (alguns terminais usam Ctrl+V para colar), substitua `ctrl+shift+v` por `ctrl+v` no `xdotool key`.

---

## Como reverter / remover a configuração

Para parar e remover tudo:

```bash
# matar xbindkeys
pkill xbindkeys
# remover arquivos criados
rm -f ~/.xbindkeysrc ~/.local/bin/rightclick-paste-if-terminal.sh ~/.config/autostart/xbindkeys.desktop
```

---

## Observações e limitações

- Wayland: em Wayland (se estiver usando), `xbindkeys` e `xdotool` geralmente não funcionam. Para Wayland existem alternativas específicas do compositor (por exemplo, sway has input remapping), mas a solução descrita aqui é para Xorg.
- Middle-click: em X11, selecionar texto já copia para o buffer PRIMARY e o middle-click (botão do meio) cola — essa é a alternativa mais simples e nativa para colar sem usar Ctrl+V.
- Reenvio do clique direito: o script tenta reenviar o clique para janelas não-terminais, mas em algumas aplicações o menu de contexto pode não aparecer exatamente como esperado. Use a GUI de Shortcuts do Cinnamon para alternativas mais integrais.

---

## Ajuda adicional

Se quiser, posso:

- Ajustar o script para o seu terminal específico (diga o nome do terminal, ex.: `gnome-terminal`, `kitty`, `alacritty`, `tilix`).
- Criar e aplicar os arquivos diretamente para você (se você permitir que eu execute os comandos aqui), ou apenas gerar os arquivos e instruções passo-a-passo.

Arquivo criado: `/var/www/html/RIGHTCLICK_PASTE.md`
