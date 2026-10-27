#!/usr/bin/env bash
# Run by security-scan-notify.path when the weekly scan finds something new
STATE=/var/lib/security-scan

COUNT=$(grep -c . "$STATE/new" 2>/dev/null)
[ "${COUNT:-0}" -gt 0 ] || exit 0
notify-send -u critical -a Security "$COUNT new security scan findings" \
    "$(head -5 "$STATE/new")"$'\n\n'"Full report: $STATE/report"
