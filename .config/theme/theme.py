"""Shared code for the theme switcher: the state file, the per-mode palettes
and the colour maths. Used by theme-apply (and later the popup)."""

import json
import os
import re
import tempfile
from pathlib import Path

STATE_FILE = (Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
              / "dotfiles-theme/state.json")
MAX_FAVOURITES = 3
DEFAULT_PAIR = {"primary": "#ff00ff", "secondary": "#8800ff"}

# Everything except the accent pair. Dark is the original hand-written look;
# its surface colours (hover, darker, focus, close_*) are swaync's defaults.
MODES = {
    "dark": {
        "bg_rgb": (63, 63, 63), "bg_alpha": 0.7,
        "base": "#2b2b2b",
        "fg": "#d8dee9", "fg_disabled": "#969696",
        "muted": "#595959",
        "hover": "#383838", "darker": "#262626", "focus": "rgba(68, 68, 68, 0.6)",
        "close_bg": "#4e4e4e", "close_bg_hover": "#5e5e5e",
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


def write_atomic(path, text):
    """Write via a temp file and rename, so readers never see half a file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
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


def readable_on(colour, light="#ffffff", dark="#1a1a1a"):
    """Whichever of light/dark text reads better on this background."""
    return light if contrast(colour, light) >= contrast(colour, dark) else dark


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
    return values
