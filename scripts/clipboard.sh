#!/usr/bin/env bash

FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --header='Select clipboard history. Press TAB to mark multiple items.'"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/.envs"

if ! [ -x "$(command -v copyq)" ]; then
    action="buffer"
elif [ -z "$1" ]; then
    action="system"
else
    action="$1"
fi

if [[ "$action" == "system" ]]; then
    item_numbers=$(copyq count)
    index=0
    declare -A obj
    while [ "$index" -lt "$item_numbers" ]; do
        item_value=$(copyq read ${index})
        # real newlines are converted to spaces, each key is a line in fzf
        item_key="copy${index}: ${item_value//$'\n'/ }"
        obj[$item_key]=$item_value
        index=$((index + 1))
    done
    copyq_index=$(printf '%s\n' "${!obj[@]}"|sort -V| eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS --preview=\"echo {} | sed -e 's/^copy//' -e 's/: .*//' | xargs -I, copyq read , 2> /dev/null\"" | sed -e 's/^copy//' -e 's/: .*//')
    [[ -z "$copyq_index" ]] && exit
    echo "$copyq_index" | xargs -I{} sh -c 'tmux set-buffer -b _temp_tmux_fzf "$(copyq read {})" && tmux paste-buffer -b _temp_tmux_fzf && tmux delete-buffer -b _temp_tmux_fzf'
elif [[ "$action" == "buffer" ]]; then
    selected_buffer=$(tmux list-buffers | sed -e 's/:.*bytes//' -e '1s/^/[cancel]\n/' -e 's/: "/: /' -e 's/"$//' | eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS --preview=\"echo {} | sed -e 's/\[cancel\]//' -e 's/:.*$//' | head -1 | xargs tmux show-buffer -b\"" | sed 's/:.*$//')
    [[ -z "$selected_buffer" ]] && exit
    echo "$selected_buffer" | xargs -I{} sh -c 'tmux paste-buffer -b {}'
fi
