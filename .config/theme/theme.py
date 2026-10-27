"""Shared code for the theme switcher (theme-apply and theme-popup): the
state file, the per-mode palettes and the colour maths."""

import colorsys
import json
import os
import re
import tempfile
from pathlib import Path

STATE_FILE = (Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
              / "dotfiles-theme/state.json")
MAX_FAVOURITES = 3
DEFAULT_PAIR = {"primary": "#ff00ff", "secondary": "#8800ff"}

# Everything except the accent pair. Dark follows VS Code's dark theme:
# panels (bg) like its side bar #191a1b, content (base) like its editor
# #121314; the surface colours (hover, darker, focus, close_*) step from those.
MODES = {
    "dark": {
        "bg_rgb": (25, 26, 27), "bg_alpha": 0.7,
        "base": "#121314",
        "fg": "#d8dee9", "fg_disabled": "#969696",
        "muted": "#595959",
        "hover": "#2a2b2d", "darker": "#0e0f10", "focus": "rgba(60, 62, 65, 0.6)",
        "close_bg": "#2f3033", "close_bg_hover": "#3c3d40",
        "critical": "#f53c3c",
    },
    # Warm off-white with brown-grey text
    "light": {
        "bg_rgb": (242, 240, 235), "bg_alpha": 0.8,
        "base": "#faf8f3",
        "fg": "#3b3631", "fg_disabled": "#8a847a",
        "muted": "#b8b2a7",
        "hover": "#e6e2d9", "darker": "#e9e5dc", "focus": "rgba(59, 54, 49, 0.08)",
        "close_bg": "#ddd8ce", "close_bg_hover": "#cfc9bd",
        "critical": "#d32f2f",
    },
}

# Terminal colours 0-15 (black, red, green, yellow, blue, magenta, cyan, white,
# then the bright versions) per mode, as @color0@..@color15@. Fixed rather
# than following the pair: programs rely on red meaning red. Checked for
# contrast on the mode's base colour (the terminal background).
ANSI = {
    "dark": ["#4a4a4a", "#ff5050", "#8fd16a", "#ffbe61", "#6aa6ff", "#d070ff", "#5fd7d7", "#d8dee9",
             "#7a7a7a", "#ff6b6b", "#a8e68a", "#ffd68a", "#8cbcff", "#e29cff", "#8ae8e8", "#ffffff"],
    "light": ["#3b3631", "#c0392b", "#3f7d20", "#9a6200", "#1f5fbf", "#9b30b0", "#10808a", "#b0aa9f",
              "#8a847a", "#d9443a", "#4f8f2c", "#b07400", "#3a78d8", "#b84fd0", "#1f959f", "#d0cbc2"],
}

# System-wide settings per mode: which built-in Adwaita our GTK3 theme builds
# on, the freedesktop colour scheme (libadwaita, portal apps like Firefox) and
# the icon theme.
SYSTEM = {
    "dark": {"adwaita_css": "gtk-contained-dark.css", "color_scheme": "prefer-dark",
             "prefer_dark": "1", "icon_theme": "Papirus-Dark"},
    "light": {"adwaita_css": "gtk-contained.css", "color_scheme": "prefer-light",
              "prefer_dark": "0", "icon_theme": "Papirus-Light"},
}
FALLBACK_ICON_THEME = "Adwaita"  # until papirus-icon-theme is installed
ICON_DIRS = (Path.home() / ".local/share/icons", Path("/usr/share/icons"))

HEX = re.compile(r"#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})")


def normalise(colour):
    """'#F0F', 'ff00ff' etc. -> '#ff00ff'. Raises ValueError for anything else."""
    m = HEX.fullmatch(colour.strip())
    if not m:
        raise ValueError(f"not a hex colour: {colour!r}")
    digits = m.group(1).lower()
    if len(digits) == 3:
        digits = "".join(c * 2 for c in digits)
    return "#" + digits


def pair(primary, secondary):
    return {"primary": normalise(primary), "secondary": normalise(secondary)}


def default_state():
    return {"mode": "dark", "pair": dict(DEFAULT_PAIR), "favourites": [dict(DEFAULT_PAIR)]}


def load_state():
    """The saved state, or the defaults for anything missing or broken."""
    state = default_state()
    try:
        saved = json.loads(STATE_FILE.read_text())
    except (OSError, ValueError):
        return state
    if not isinstance(saved, dict):
        return state
    if saved.get("mode") in MODES:
        state["mode"] = saved["mode"]
    try:
        state["pair"] = pair(saved["pair"]["primary"], saved["pair"]["secondary"])
    except (KeyError, TypeError, AttributeError, ValueError):
        pass
    if isinstance(saved.get("favourites"), list):
        favourites = []
        for fav in saved["favourites"]:
            try:
                fav = pair(fav["primary"], fav["secondary"])
            except (KeyError, TypeError, AttributeError, ValueError):
                continue
            if fav not in favourites:
                favourites.append(fav)
        state["favourites"] = favourites[:MAX_FAVOURITES]
    return state


def write_atomic(path, data):
    """Write text or bytes via a temp file and rename, so readers never see
    half a file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "wb" if isinstance(data, bytes) else "w") as f:
            f.write(data)
        os.chmod(tmp, 0o644)  # mkstemp makes it 0600
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def save_state(state):
    write_atomic(STATE_FILE, json.dumps(state, indent=2) + "\n")


def rgb(colour):
    colour = normalise(colour)
    return tuple(int(colour[i:i + 2], 16) for i in (1, 3, 5))


def luminance(colour):
    """WCAG relative luminance, 0 (black) to 1 (white)."""
    def channel(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb(colour))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def readable_on(colour):
    """Whichever of the two modes' text colours reads better on this
    background. Not pure white/black: those overpower the normal text."""
    light, dark = MODES["dark"]["fg"], MODES["light"]["fg"]
    return light if contrast(colour, light) >= contrast(colour, dark) else dark


CSS_COLOUR = re.compile(r"#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b|rgba?\([^)]*\)|\b(?:white|black)\b")

# Built-in GTK3 Adwaita declares its palette as named colours at the top of
# its compiled CSS. Our GTK3 theme is Adwaita recoloured by mapping these onto
# ours; reading them (rather than hard-coding) follows a GTK update.
ADWAITA_NAMES = {"base": "theme_base_color", "bg": "theme_bg_color", "fg": "theme_fg_color",
                 "accent": "theme_selected_bg_color", "accent_fg": "theme_selected_fg_color"}


def adwaita_palette(css):
    """Adwaita's own palette, from its @define-color lines."""
    palette = {}
    for key, name in ADWAITA_NAMES.items():
        m = re.search(rf"@define-color {name} ({CSS_COLOUR.pattern});", css)
        if not m:
            raise ValueError(f"Adwaita's CSS no longer defines @{name}")
        palette[key] = _format_css_colour(*_parse_css_colour(m.group(1))[:3], 1)
    return palette


def _parse_css_colour(text):
    """'#abc', '#aabbcc', 'rgb(..)', 'rgba(..)', 'white', 'black' -> (r, g, b, a)."""
    if text in ("white", "black"):
        v = 255 if text == "white" else 0
        return v, v, v, 1.0
    if text.startswith("#"):
        return (*rgb(text), 1.0)
    parts = [p.strip() for p in text[text.index("(") + 1:-1].split(",")]
    r, g, b = (int(float(p)) for p in parts[:3])
    return r, g, b, float(parts[3]) if len(parts) > 3 else 1.0


def _format_css_colour(r, g, b, a):
    r, g, b = (max(0, min(255, round(c))) for c in (r, g, b))
    return f"#{r:02x}{g:02x}{b:02x}" if a >= 1 else f"rgba({r}, {g}, {b}, {a:g})"


def recolour_adwaita(css, values):
    """Map Adwaita's colours onto ours. Its blues (the accent and every shade
    derived from it) become the same shades of our secondary; its greys are
    placed by lightness between our base, background and text colours. Other
    colours (green, red, yellow for success/error/warning) stay. Its selected
    text colour, on a selection or an accent background, becomes on_secondary.

    Returns (css, number of accent colours replaced). Raises ValueError if
    Adwaita's palette can't be found."""
    adw = adwaita_palette(css)
    lightness = lambda c: colorsys.rgb_to_hls(*(v / 255 for v in rgb(c)))[1]
    # (Adwaita lightness, our colour) anchors for the greys, low to high.
    # In dark mode white becomes our text colour (no bright white text).
    if values["mode"] == "dark":
        anchors = [(0.0, "#000000"), (lightness(adw["base"]), values["base"]),
                   (lightness(adw["bg"]), values["bg_opaque"]),
                   (lightness(adw["fg"]), values["fg"]), (1.0, values["fg"])]
    else:
        anchors = [(0.0, "#000000"), (lightness(adw["fg"]), values["fg"]),
                   (lightness(adw["bg"]), values["bg_opaque"]), (1.0, values["base"])]
    acc_h, acc_l, acc_s = colorsys.rgb_to_hls(*(v / 255 for v in rgb(adw["accent"])))
    sec_h, sec_l, sec_s = colorsys.rgb_to_hls(*(v / 255 for v in rgb(values["secondary"])))

    def grey(l):
        for (l0, c0), (l1, c1) in zip(anchors, anchors[1:]):
            if l <= l1:
                f = 0 if l1 == l0 else (l - l0) / (l1 - l0)
                return [a + (b - a) * f for a, b in zip(rgb(c0), rgb(c1))]
        return list(rgb(anchors[-1][1]))

    def is_accent(h, l, s):
        return s >= 0.25 and min(abs(h - acc_h), 1 - abs(h - acc_h)) <= 0.06

    def accent_text(m):
        selector, body = m.group(1), m.group(2)
        backgrounds = re.findall(r"background(?:-color|-image)?:([^;]*)", body)
        on_accent = any(
            is_accent(*colorsys.rgb_to_hls(*(v / 255 for v in _parse_css_colour(c.group(0))[:3])))
            for bg in backgrounds for c in CSS_COLOUR.finditer(bg))
        if on_accent or ":selected" in selector or "selection" in selector:
            # A token (keeping the alpha), so the colour pass below leaves it alone
            def on_secondary(c):
                *colour, alpha = _parse_css_colour(c.group(1))
                same = tuple(colour) == rgb(adw["accent_fg"])
                return f"color: ON_SECONDARY/{alpha:g}" if same else c.group(0)
            body = re.sub(rf"(?<![-\w])color: *({CSS_COLOUR.pattern})", on_secondary, body)
        return selector + "{" + body + "}"

    css = re.sub(r"([^{}]+)\{([^{}]*)\}", accent_text, css)

    accents = 0

    def sub(m):
        nonlocal accents
        r, g, b, a = _parse_css_colour(m.group(0))
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if is_accent(h, l, s):
            accents += 1
            s = min(1.0, sec_s * s / acc_s)
            l = min(1.0, max(0.0, sec_l + l - acc_l))
            r, g, b = (v * 255 for v in colorsys.hls_to_rgb(sec_h, l, s))
        elif s < 0.15 or l < 0.03 or l > 0.97:
            r, g, b = grey(l)
        else:
            return m.group(0)
        return _format_css_colour(r, g, b, a)

    css = re.sub(r"ON_SECONDARY/([\d.]+)",
                 lambda m: _format_css_colour(*rgb(values["on_secondary"]), float(m.group(1))),
                 CSS_COLOUR.sub(sub, css))
    return css, accents


def readable_accent(colour, backgrounds, minimum=3.0):
    """colour, lightened (on dark backgrounds) or darkened (on light ones) in
    small steps, keeping its hue, until it reads on all of them. For accents
    used as text; unchanged if it already reads."""
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in rgb(colour)))
    step = 0.02 if luminance(backgrounds[0]) < 0.5 else -0.02
    while min(contrast(colour, bg) for bg in backgrounds) < minimum and 0 < l < 1:
        l = min(1.0, max(0.0, l + step))
        colour = _format_css_colour(*(v * 255 for v in colorsys.hls_to_rgb(h, l, s)), 1)
    return colour


def palette(state):
    """Every value the templates can use, as strings, keyed by @name@."""
    mode = MODES[state["mode"]]
    r, g, b = mode["bg_rgb"]
    values = {k: v for k, v in mode.items() if k not in ("bg_rgb", "bg_alpha")}
    values.update(
        mode=state["mode"],
        primary=state["pair"]["primary"],
        secondary=state["pair"]["secondary"],
        on_secondary=readable_on(state["pair"]["secondary"]),
        bg=f"rgba({r}, {g}, {b}, {mode['bg_alpha']})",
        bg_rgb=f"{r}, {g}, {b}",
        bg_alpha=str(mode["bg_alpha"]),
        bg_opaque=f"#{r:02x}{g:02x}{b:02x}",
    )
    # The pair as text (clock, links, fastfetch): same hue, readable on panel and content
    for key in ("primary", "secondary"):
        values[f"{key}_text"] = readable_accent(values[key], [values["bg_opaque"], values["base"]])
    values.update(SYSTEM[state["mode"]])
    values.update({f"color{i}": c for i, c in enumerate(ANSI[state["mode"]])})
    if not any((d / values["icon_theme"]).is_dir() for d in ICON_DIRS):
        values["icon_theme"] = FALLBACK_ICON_THEME
    # Bare hex for formats like Hyprland's rgba(ff00ffee): @primary_hex@ -> ff00ff
    values.update({f"{k}_hex": v[1:] for k, v in list(values.items()) if v.startswith("#")})
    return values
