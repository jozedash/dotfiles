#!/usr/bin/env bash
# Current temperature from wttr.in, which finds the location from the IP address.
# Prints nothing (hiding the module) when offline.

TEXT=$(curl -sf --max-time 10 'https://wttr.in/?format=%t') || exit 0
grep -q "Unknown location" <<< "$TEXT" && exit 0
TOOLTIP=$(curl -sf --max-time 10 'https://wttr.in/?0QT')

jq -cn --arg text "${TEXT#+}" --arg tooltip "<tt>$TOOLTIP</tt>" '{$text, $tooltip, class: "weather"}'
