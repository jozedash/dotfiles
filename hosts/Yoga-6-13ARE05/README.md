# Lenovo Yoga 6 13ARE05 (product name 82FN)

AMD Ryzen 4000 / amdgpu, 16 GB RAM, systemd-boot, ext4.

`link.sh` links `~/.config/dotfiles-host` to this folder when
`/sys/class/dmi/id/product_version` is "Yoga 6 13ARE05", and `setup.sh`
copies `etc/` into `/etc` after the generic `etc/`.

| File | What's specific to this laptop |
|---|---|
| `host.sh` | Laptop screen `eDP-1` at `1920x1080@60` (for `toggle_layout.sh`), battery `BAT1` (for waybar's `battery.sh`) |
| `waybar.jsonc` | Backlight device `amdgpu_bl1` (not `intel_backlight`); CPU temperature from `k10temp` Tctl, because the default thermal zone is `acpitz` |
| `etc/udev/rules.d/90-charge-types.rules` | Lets the `wheel` group write `/sys/class/power_supply/BAT1/charge_types`, so clicking the battery icon can switch Long Life mode |
| `etc/tlp.conf` | The charge thresholds are left commented out. This battery has no `charge_control_end_threshold`, only `charge_types` (`Standard` / `Long_Life`, which holds about 60%), and TLP would reset it at every boot and every time the charger is plugged in |
