# Debugging `pacman -Syu` download failures

Use this guide when an upgrade fails with `failed to retrieve some files` or
`failed to commit transaction`. When the download fails, pacman installs
nothing ("no packages were upgraded"), so your system is not left half-updated.

## 1. Read the error and find the cause

| Error text | Meaning | Fix |
|---|---|---|
| `Operation too slow. Less than 1 bytes/sec` | Mirror is overloaded or far away | Refresh the mirror list (step 2) |
| `HTTP server does not seem to support byte ranges` | Mirror can't resume a partial download | Refresh the mirror list, or delete the `.part` file (step 4) |
| `Could not resolve host` | Mirror no longer exists, or DNS/network is down | Remove the mirror; if every mirror fails, check your network |
| `The requested URL returned error: 404` | Your package database is newer or older than the mirror | Force a database refresh with `-Syy` (step 3) |
| `too many errors from <mirror>, skipping` | pacman gave up on that mirror | Remove or reorder it |
| `invalid or corrupted package (PGP signature)` / `unknown trust` | Keyring is out of date | `sudo pacman -Sy archlinux-keyring && sudo pacman -Su` |

If every mirror fails, the problem is probably your network, not the mirrors.
Check `ping archlinux.org` and `resolvectl status` before changing anything else.

## 2. Check and refresh the mirror list

```bash
# Show the active mirrors (pacman tries them top to bottom)
grep -v '^\s*#' /etc/pacman.d/mirrorlist | grep -v '^\s*$'

# Check per-mirror sync status
# https://archlinux.org/mirrors/status/
```

Generate a fresh list with reflector:

```bash
sudo pacman -S --needed reflector
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
sudo reflector --country GB,FR,DE,NL --protocol https --age 12 \
     --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
```

- `--age 12`: only mirrors that synced in the last 12 hours, which prevents 404s.
- `--sort rate`: puts the fastest mirrors first.

If installing reflector itself stalls, edit `/etc/pacman.d/mirrorlist` by hand
first. Put `#` in front of the bad mirrors, or move a known-good mirror such as
`https://geo.mirror.pkgbuild.com/$repo/os/$arch` to the top.

To keep the list fresh automatically:

```bash
sudo vim /etc/xdg/reflector/reflector.conf   # put the same flags here
sudo systemctl enable --now reflector.timer  # runs weekly
```

## 3. Force a database refresh and retry

```bash
sudo pacman -Syyu
```

`-yy` downloads the package databases again even if pacman thinks they're
current. This fixes 404s caused by syncing from one mirror and downloading from
another. Packages you already downloaded stay in `/var/cache/pacman/pkg` and are
not fetched again.

## 4. If a single file keeps failing

```bash
# Delete leftover partial downloads
sudo find /var/cache/pacman/pkg -name '*.part' -delete

# Check the package's current version upstream
pacman -Si <pkg>               # what your database says
# Compare with https://archlinux.org/packages/?q=<pkg>
```

If the upstream version is newer than your database, the package was replaced
after you synced. Run `-Syy` again. If a slow connection makes downloads time
out, set `ParallelDownloads = 2` in `/etc/pacman.conf`, or retry later.

## 5. After a successful upgrade

```bash
# Merge or remove config files the upgrade left as .pacnew
sudo pacdiff                   # from pacman-contrib

# Reboot if linux, linux-firmware or systemd was upgraded
pacman -Q linux; uname -r      # different versions mean you need to reboot
```

## Things not to do

- **Don't** run `pacman -Sy <pkg>` without also upgrading (`-u`). Updating the
  database without upgrading creates a partial upgrade, which Arch doesn't
  support.
- **Don't** use `--disable-download-timeout` as a fix. It hides a bad mirror.
- **Don't** delete the whole package cache. It doesn't help, and you lose your
  ability to downgrade packages.
