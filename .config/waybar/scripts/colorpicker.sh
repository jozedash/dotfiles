#!/usr/bin/env bash

check() {
  command -v "$1" 1>/dev/null
}

notify() {
  check notify-send && {
    notify-send -a "Color Picker" "$@"
    return
  }
  echo "$@"
}

loc="$HOME/.cache/colorpicker"
[ -d "$loc" ] || mkdir -p "$loc"
[ -f "$loc/colors" ] || touch "$loc/colors"

limit=10

[[ $# -eq 1 && $1 = "-l" ]] && {
  cat "$loc/colors"
  exit
}

[[ $# -eq 1 && $1 = "-j" ]] && {
  # The picker icon comes from style.css; the swatch shows the last colour,
  # the tooltip the whole history
  jq -cn --arg last "$(head -n 1 "$loc/colors")" --rawfile all "$loc/colors" '
    ($all | split("\n") | map(select(. != ""))) as $c
    | { text: "<span color=\"\(if $last == "" then "#d8dee9" else $last end)\">■</span>",
        tooltip: ("<b>COLORS</b>\n\n" + ($c | to_entries | map((if .key == 0 then "-> " else "   " end)
            + "<b>\(.value)</b>  <span color=\"\(.value)\">■</span>") | join("\n"))) }'
  exit
}

check hyprpicker || {
  notify "hyprpicker is not installed"
  exit
}
pkill -x hyprpicker
color=$(hyprpicker)

check wl-copy && {
  echo "$color" | sed -z 's/\n//g' | wl-copy
}

prevColors=$(head -n $((limit - 1)) "$loc/colors")
echo "$color" >"$loc/colors"
echo "$prevColors" >>"$loc/colors"
sed -i '/^$/d' "$loc/colors"
pkill -RTMIN+1 waybar
