# petbook - simple pet + fzf command bookmark helper

# ---------------------------
# Help
# ---------------------------
petbook-help() {
    cat <<'EOF'
zsh-pet commands (nix-env -iA pet):

  phelp                -> Usage
  psave                -> save last command
  pdump                -> dump full shell history into pet (dedupe)
  pdedupe              -> remove duplicate commands in pet
  pfind                -> search (pet)
  plist                -> List commands
  #Ctrl-s              -> save last command
  Ctrl-r               -> insert command (fzf)
  #Ctrl-g              -> run command (fzf)

EOF
}


petbook-dump-history() {
    local tmp
    tmp=$(mktemp)

    # extract history cleanly
    fc -ln 1 | while read -r cmd; do
        # skip empty
        [[ -z "$cmd" ]] && continue

        # skip plugin self commands
        [[ "$cmd" == petbook-* ]] && continue

        echo "$cmd"
    done > "$tmp"

    # merge with existing pet entries
    while read -r cmd; do
        # check if already exists
        if ! pet search "$cmd" 2>/dev/null | grep -Fxq "$cmd"; then
            pet new "$cmd" >/dev/null
        fi
    done < "$tmp"

    rm -f "$tmp"

    echo "📦 history dumped into pet"
}


petbook-dedupe() {
    local tmp all

    tmp=$(mktemp)

    # export all commands
    pet list 2>/dev/null |
        sed 's/^[^:]*: //' |
        awk '!seen[$0]++' > "$tmp"

    # rebuild pet database
    all=$(cat "$tmp")

    # optional: clear & reinsert
    # WARNING: depends on pet version behavior
    while read -r cmd; do
        pet new "$cmd" >/dev/null
    done < "$tmp"

    rm -f "$tmp"

    echo "🧹 dedup complete"
}


# ---------------------------
# Save last command to pet
# ---------------------------
petbook-save-last() {
    local cmd
    cmd="${history[$((HISTCMD-1))]}"

    # fallback for bash compatibility / edge cases
    if [[ -z "$cmd" ]]; then
        cmd=$(fc -ln -1)
    fi

    # sanitize
    [[ -z "$cmd" ]] && return
    [[ "$cmd" == petbook-* ]] && return

    pet new "$cmd"
    echo "📌 saved: $cmd"
}


petbook-save-current() {
    local cmd="$BUFFER"

    [[ -z "$cmd" ]] && return
    [[ "$cmd" == petbook-* ]] && return

    # escape quotes safely for TOML
    local escaped
    escaped="${cmd//\"/\\\"}"

    cat >> ~/.config/pet/snippet.toml <<EOF

[[Snippets]]
  Description = "cli"
  Output = ""
  Tag = []
  command = "$escaped"
EOF

    zle -M "Petbook saved to '~/.config/pet/snippet.toml'."
}


# ---------------------------
# fzf picker (insert into prompt)
# ---------------------------
petbook-insert() {
    local cmd

    cmd=$(
        pet search 2>/dev/null |
        fzf --height 40% --reverse --prompt="pet> " |
        sed 's/^[^:]*: //'
    ) || return

    LBUFFER+="$cmd"
}

# ---------------------------
# fzf picker (execute directly)
# ---------------------------
petbook-run() {
    local cmd

    cmd=$(
        pet search 2>/dev/null |
        fzf --height 40% --reverse --prompt="run> " |
        sed 's/^[^:]*: //'
    ) || return

    print -z "$cmd"
}

# ---------------------------
# Keybindings (ZSH only)
# ---------------------------
bindkey -r '^r'
bindkey -r '^s'
zle -N petbook-insert
zle -N petbook-save-current
#zle -N petbook-run

bindkey '^r' petbook-insert     # Ctrl-r = insert
bindkey '^s' petbook-save-current
#bindkey '^g' petbook-run        # Ctrl-g = run from pet
#bindkey '^s' petbook-save-last  # Ctrl-s = save last cmd

# ---------------------------
# aliases (optional)
# ---------------------------
alias phelp='petbook-help'
alias pdump='petbook-dump-history'
alias pdedupe='petbook-dedupe'
alias psave='petbook-save-last'
alias pfind='pet search'
alias plist='pet list'

