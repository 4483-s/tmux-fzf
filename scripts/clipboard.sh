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
    all_items=$(copyq eval '
      var out = [];
      var len = size();
      for (var i = 0; i < len; ++i) {
        var val = str(read(i)).replace(/\r?\\n/g, " ");
        out.push(i + ": " + val);
      }
      out.join("\\n");
    ')

    copyq_index=$(printf '%s\n' "$all_items" | eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS --preview=\"echo {} | sed 's/: .*//' | xargs -I, copyq read , 2> /dev/null\"" | sed 's/: .*//')
    [[ -z "$copyq_index" ]] && exit
    while read -r i;do
      paste_content+=$(copyq read "$i")
    done <<< "$copyq_index"
    tmux set-buffer -b _temp_tmux_fzf "${paste_content}" && tmux paste-buffer -b _temp_tmux_fzf && tmux delete-buffer -b _temp_tmux_fzf
elif [[ "$action" == "buffer" ]]; then
    selected_buffer=$(tmux list-buffers | sed -e 's/:.*bytes//' -e '1s/^/[cancel]\n/' -e 's/: "/: /' -e 's/"$//' | eval "$TMUX_FZF_BIN $TMUX_FZF_OPTIONS --preview=\"echo {} | sed -e 's/\[cancel\]//' -e 's/:.*$//' | head -1 | xargs tmux show-buffer -b\"" | sed 's/:.*$//')
    [[ -z "$selected_buffer" ]] && exit
    echo "$selected_buffer" | xargs -I{} sh -c 'tmux paste-buffer -b {}'
fi
