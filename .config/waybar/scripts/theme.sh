#!/usr/bin/env bash
# custom/theme: the palette icon (drawn by style.css), with the current pair
# and mode in the tooltip. Click handling is in the module's config.
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-theme/state.json"
read -r mode p s < <(jq -r '"\(.mode) \(.pair.primary) \(.pair.secondary)"' "$state" 2>/dev/null)
mode=${mode:-dark} p=${p:-#ff00ff} s=${s:-#8800ff}

tooltip="<b>Theme</b>: $mode\n<span color='$p'>■</span> $p  <span color='$s'>■</span> $s"
tooltip+="\n\nClick: palette · Right: next favourite · Middle: dark/light"
printf '{"text": " ", "tooltip": "%s", "class": "%s"}\n' "$tooltip" "$mode"
