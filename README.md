---

**Niri fork** — this version is maintained exclusively for the [Niri](https://github.com/YaLTeR/niri) compositor.
All Hyprland-specific code has been stripped out.

Original work and massive thanks to:
- [jutraim](https://github.com/jutraim/niri-caelestia-shell)
- [Caelestia](https://github.com/caelestia-dots/shell)
- [end-4](https://github.com/end-4/dots-hyprland)

---



<h1 align=center>🌌 Niri-Caelestia Shell</h1>

https://github.com/user-attachments/assets/0840f496-575c-4ca6-83a8-87bb01a85c5f

## Components

-   Widgets: [`Quickshell`](https://quickshell.outfoxxed.me)
-   Window manager: [`Niri`](https://github.com/YaLTeR/niri)
-   Dots: [`caelestia`](https://github.com/caelestia-dots)

## Installation

### Manual Installation

If you are on Arch Linux or another distribution without Nix, you can install the shell manually.

#### 1. Install Dependencies

You must install [`quickshell-git`](https://quickshell.outfoxxed.me) (must be built from `git` master, not the latest release tag) and the following dependencies:

- **Core/CLI dependencies**: `caelestia-cli`, `gpu-screen-recorder`, `ddcutil`, `brightnessctl`, `app2unit`, `networkmanager`, `lm-sensors`, `wl-clipboard`, `libqalculate`, `swappy`, `fish`, `bash`
- **Audio/Visualizer dependencies**: `libcava`, `aubio`, `libpipewire`, `fftw`
- **Fonts**: `material-symbols` (Material Symbols Rounded), `rubik` (Rubik), `caskaydia-cove-nerd` (CaskaydiaCove NF)
- **Build tools**: `cmake`, `ninja`, `pkg-config`, `gcc`, `qt6-base`, `qt6-declarative`, `qt6-shadertools`

#### 2. Clone the Repository

Clone this repository to your Quickshell configuration folder under the name `niri-caelestia-shell`:

```sh
mkdir -p ~/.config/quickshell
git clone https://github.com/Cantfirmed/niri-caelestia-shell.git ~/.config/quickshell/niri-caelestia-shell
cd ~/.config/quickshell/niri-caelestia-shell
```

#### 3. Build the C++ QML Plugin & Libraries

Run CMake to build the compiled components locally:

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

---

## Usage

### Launching the Shell Manually

To run the shell, you must specify the environment variables pointing to the compiled QML plugin and libraries built in the previous step:

```sh
export CAELESTIA_LIB_DIR="$HOME/.config/quickshell/niri-caelestia-shell/build/lib"
export QML2_IMPORT_PATH="$HOME/.config/quickshell/niri-caelestia-shell/build/qml:$QML2_IMPORT_PATH"

qs -c niri-caelestia-shell
```

### Autostart with Niri

Add the following to your Niri configuration (`~/.config/niri/config.kdl`) to launch the shell automatically on startup:

```kdl
spawn-at-startup "env" "CAELESTIA_LIB_DIR=/home/YOUR_USERNAME/.config/quickshell/niri-caelestia-shell/build/lib" "QML2_IMPORT_PATH=/home/YOUR_USERNAME/.config/quickshell/niri-caelestia-shell/build/qml" "qs" "-c" "niri-caelestia-shell"
```

### Shortcuts/IPC

All keybinds are configured in the [niri config](niri/niri/caelestia.kdl) and use IPC calls
to trigger shell actions.

All IPC commands can be accessed via `qs -c niri-caelestia-shell ipc call <target> <action>`. For example

```sh
caelestia shell mpris getActive trackTitle
```

The list of IPC commands can be shown via `caelestia shell -s`:

```
$ caelestia shell -s
target drawers
  function toggle(drawer: string): void
  function list(): string
target notifs
  function clear(): void
target lock
  function lock(): void
  function unlock(): void
  function isLocked(): bool
target mpris
  function playPause(): void
  function getActive(prop: string): string
  function next(): void
  function stop(): void
  function play(): void
  function list(): string
  function pause(): void
  function previous(): void
target picker
  function openFreeze(): void
  function open(): void
target wallpaper
  function set(path: string): void
  function get(): string
  function list(): string
```

### PFP/Wallpapers

The profile picture for the dashboard is read from the file `~/.face`, so to set
it you can copy your image to there or set it via the dashboard.

The wallpapers for the wallpaper switcher are read from `~/Pictures/Wallpapers`
by default. To change it, change the wallpapers path in `~/.config/caelestia/shell.json`.

To set the wallpaper, you can use the command `caelestia wallpaper`. Use `caelestia wallpaper -h` for more info about
the command.

## Updating

If installed manually, you can update by running `git pull` in the repo directory:

```sh
cd ~/.config/quickshell/niri-caelestia-shell
git pull
```

## Configuring

All configuration options should be put in `~/.config/caelestia/shell.json`. This file is _not_ created by
default, you must create it manually. Options that you omit from the config file will use their default
values.

### Per-monitor configuration

You can configure options per-monitor in `~/.config/caelestia/monitors/<screen-name>/shell.json`. Options
set in this file will **override** the respective options in the global config. Otherwise, the options will
use their values from the global config.

For example, to disable the bar on DP-1:

**`~/.config/caelestia/monitors/DP-1/shell.json`**

```json
{
    "bar": {
        "persistent": false
    }
}
```

> [!NOTE]
> Not all options are respect per-monitor overrides. Most notably, the following options will only read
> from the global config, and ignore the respective option in per-monitor config files.
>
> <details><summary>Ignored options</summary>
>
> - `appearance` (`anim`, `transparency`)
> - `general` (`logo`, `apps`, `idle`, `battery`)
> - `bar.workspaces` (`perMonitorWorkspaces`, `specialWorkspaceIcons`, `windowIcons`)
> - `bar.tray` (`iconSubs`, `hiddenIcons`)
> - `dashboard` (`mediaUpdateInterval`, `resourceUpdateInterval`)
> - `launcher` (`specialPrefix`, `actionPrefix`, `enableDangerousActions`, `vimKeybinds`,
>   `favouriteApps`, `hiddenApps`, `actions`)
> - `launcher.useFuzzy` (`apps`, `actions`, `schemes`, `variants`, `wallpapers`)
> - `notifs` (`expire`, `fullscreen`, `defaultExpireTimeout`, `fullscreenExpireTimeout`, `actionOnClick`)
> - `lock` (`enableFprint`, `maxFprintTries`)
> - `nexus` (`networkRescanInterval`)
> - `utilities.toasts` (all except `fullscreen`)
> - `utilities.vpn` (`enabled`, `provider`)
> - `services` (`weatherLocation`, `useFahrenheit`, `useFahrenheitPerformance`, `useTwelveHourClock`,
>   `gpuType`, `visualiserBars`, `audioIncrement`, `brightnessIncrement`, `maxVolume`, `smartScheme`,
>   `defaultPlayer`, `playerAliases`, `lyricsBackend`)
> - `paths` (`wallpaperDir`, `lyricsDir`)
>
> </details>

### Example configuration

> [!NOTE]
> The example configuration includes ALL configuration options in `shell.json`. You are
> **not** recommended to copy and paste this entire configuration into `shell.json`.
> This is meant to serve as a reference of all the available options, and you should
> only add the ones you want to change to `shell.json`.

<details><summary>Example</summary>

```json
{
    "enabled": true,
    "appearance": {
        "deformScale": 1,
        "rounding": {
            "scale": 1
        },
        "spacing": {
            "scale": 1
        },
        "padding": {
            "scale": 1
        },
        "font": {
            "scale": 1,
            "clock": "Rubik",
            "headline": {
                "family": "GoogleSansFlex",
                "large": { "size": 32, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 28, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 24, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "title": {
                "family": "GoogleSansFlex",
                "large": { "size": 22, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 16, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 14, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "body": {
                "family": "GoogleSansFlex",
                "large": { "size": 16, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 14, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 12, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "label": {
                "family": "GoogleSansFlex",
                "large": { "size": 14, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "medium": { "size": 12, "weight": 500, "italic": false, "vaxes": { "ROND": 25 } },
                "small": { "size": 11, "weight": 400, "italic": false, "vaxes": { "ROND": 25 } }
            },
            "mono": {
                "family": "CaskaydiaCove NF",
                "large": { "size": 16, "weight": 400, "italic": false, "vaxes": {} },
                "medium": { "size": 14, "weight": 400, "italic": false, "vaxes": {} },
                "small": { "size": 12, "weight": 400, "italic": false, "vaxes": {} }
            },
            "icon": {
                "family": "Material Symbols Rounded",
                "extraLarge": { "size": 36, "weight": 400, "italic": false, "vaxes": {} },
                "large": { "size": 24, "weight": 400, "italic": false, "vaxes": {} },
                "medium": { "size": 18, "weight": 400, "italic": false, "vaxes": {} },
                "small": { "size": 15, "weight": 400, "italic": false, "vaxes": {} }
            }
        },
        "anim": {
            "durations": {
                "scale": 1
            }
        },
        "transparency": {
            "enabled": false,
            "base": 0.85,
            "layers": 0.4
        }
    },
    "general": {
        "logo": "",
        "showOverFullscreen": false,
        "mediaGifSpeedAdjustment": 300,
        "sessionGifSpeed": 0.7,
        "apps": {
            "terminal": ["foot"],
            "audio": ["pavucontrol"],
            "playback": ["mpv"],
            "explorer": ["thunar"]
        },
        "idle": {
            "lockBeforeSleep": true,
            "inhibitWhenAudio": true,
            "timeouts": [
                {
                    "timeout": 180,
                    "idleAction": "lock"
                },
                {
                    "timeout": 300,
                    "idleAction": "dpms off",
                    "returnAction": "dpms on"
                },
                {
                    "timeout": 600,
                    "idleAction": ["systemctl", "suspend-then-hibernate"]
                }
            ]
        },
        "battery": {
            "warnLevels": [
                {
                    "level": 20,
                    "title": "Low battery",
                    "message": "You might want to plug in a charger",
                    "icon": "battery_android_frame_2"
                },
                {
                    "level": 10,
                    "title": "Did you see the previous message?",
                    "message": "You should probably plug in a charger <b>now</b>",
                    "icon": "battery_android_frame_1"
                },
                {
                    "level": 5,
                    "title": "Critical battery level",
                    "message": "PLUG THE CHARGER RIGHT NOW!!",
                    "icon": "battery_android_alert",
                    "critical": true
                }
            ],
            "criticalLevel": 3
        }
    },
    "background": {
        "enabled": true,
        "wallpaperEnabled": true,
        "desktopClock": {
            "enabled": false,
            "scale": 1.0,
            "position": "bottom-right",
            "invertColors": false,
            "background": {
                "enabled": false,
                "opacity": 0.7,
                "blur": true
            },
            "shadow": {
                "enabled": true,
                "opacity": 0.7,
                "blur": 0.4
            }
        },
        "visualiser": {
            "enabled": false,
            "autoHide": true,
            "blur": false,
            "rounding": 1,
            "spacing": 1
        }
    },
    "bar": {
        "persistent": true,
        "showOnHover": true,
        "dragThreshold": 20,
        "scrollActions": {
            "workspaces": true,
            "volume": true,
            "brightness": true
        },
        "popouts": {
            "activeWindow": true,
            "tray": true,
            "statusIcons": true
        },
        "workspaces": {
            "shown": 5,
            "activeIndicator": true,
            "occupiedBg": false,
            "showWindows": true,
            "showWindowsOnSpecialWorkspaces": true,
            "maxWindowIcons": 5,
            "activeTrail": false,
            "perMonitorWorkspaces": true,
            "label": "  ",
            "occupiedLabel": "󰮯",
            "activeLabel": "󰮯",
            "capitalisation": "preserve",
            "specialWorkspaceIcons": [
                {
                    "name": "steam",
                    "icon": "sports_esports"
                }
            ],
            "windowIcons": [
                {
                    "regex": "steam(_app_(default|[0-9]+))?",
                    "icon": "sports_esports"
                }
            ]
        },
        "activeWindow": {
            "compact": false,
            "inverted": false,
            "showOnHover": true
        },
        "tray": {
            "background": false,
            "recolour": false,
            "compact": false,
            "iconSubs": [],
            "hiddenIcons": []
        },
        "status": {
            "showAudio": false,
            "showMicrophone": false,
            "showKbLayout": false,
            "showNetwork": true,
            "showWifi": true,
            "showBluetooth": true,
            "showBattery": true,
            "showLockStatus": true
        },
        "clock": {
            "background": false,
            "showDate": false,
            "showIcon": true
        },
        "entries": [
            {
                "id": "logo",
                "enabled": true
            },
            {
                "id": "workspaces",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "activeWindow",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "tray",
                "enabled": true
            },
            {
                "id": "clock",
                "enabled": true
            },
            {
                "id": "statusIcons",
                "enabled": true
            },
            {
                "id": "power",
                "enabled": true
            }
        ],
        "excludedScreens": []
    },
    "border": {
        "thickness": 10,
        "rounding": 25,
        "smoothing": 20
    },
    "dashboard": {
        "enabled": true,
        "showOnHover": true,
        "showDashboard": true,
        "showMedia": true,
        "showPerformance": true,
        "showWeather": true,
        "mediaUpdateInterval": 500,
        "resourceUpdateInterval": 1000,
        "dragThreshold": 50,
        "performance": {
            "showBattery": true,
            "showGpu": true,
            "showCpu": true,
            "showMemory": true,
            "showStorage": true,
            "showNetwork": true
        }
    },
    "launcher": {
        "enabled": true,
        "showOnHover": false,
        "maxShown": 7,
        "maxWallpapers": 9,
        "specialPrefix": "@",
        "actionPrefix": ">",
        "enableDangerousActions": false,
        "dragThreshold": 50,
        "vimKeybinds": false,
        "favouriteApps": [],
        "hiddenApps": [],
        "useFuzzy": {
            "apps": false,
            "actions": false,
            "schemes": false,
            "variants": false,
            "wallpapers": false
        },
        "actions": [
            {
                "name": "Calculator",
                "icon": "calculate",
                "description": "Do simple math equations (powered by Qalc)",
                "command": ["autocomplete", "calc"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Scheme",
                "icon": "palette",
                "description": "Change the current colour scheme",
                "command": ["autocomplete", "scheme"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Wallpaper",
                "icon": "image",
                "description": "Change the current wallpaper",
                "command": ["autocomplete", "wallpaper"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Variant",
                "icon": "colors",
                "description": "Change the current scheme variant",
                "command": ["autocomplete", "variant"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Random",
                "icon": "casino",
                "description": "Switch to a random wallpaper",
                "command": ["caelestia", "wallpaper", "-r"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Light",
                "icon": "light_mode",
                "description": "Change the scheme to light mode",
                "command": ["setMode", "light"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Dark",
                "icon": "dark_mode",
                "description": "Change the scheme to dark mode",
                "command": ["setMode", "dark"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Shutdown",
                "icon": "power_settings_new",
                "description": "Shutdown the system",
                "command": ["systemctl", "poweroff"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Reboot",
                "icon": "cached",
                "description": "Reboot the system",
                "command": ["systemctl", "reboot"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Logout",
                "icon": "exit_to_app",
                "description": "Log out of the current session",
                "command": ["loginctl", "terminate-user", ""],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Lock",
                "icon": "lock",
                "description": "Lock the current session",
                "command": ["loginctl", "lock-session"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Sleep",
                "icon": "bedtime",
                "description": "Suspend then hibernate",
                "command": ["systemctl", "suspend-then-hibernate"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Settings",
                "icon": "settings",
                "description": "Configure the shell",
                "command": ["caelestia", "shell", "nexus", "open"],
                "enabled": true,
                "dangerous": false
            }
        ]
    },
    "lock": {
        "recolourLogo": true,
        "enableFprint": true,
        "maxFprintTries": 3,
        "hideNotifs": false
    },
    "nexus": {
        "wallpapersPerRow": 4,
        "networkRescanInterval": 15000
    },
    "notifs": {
        "expire": true,
        "fullscreen": "on",
        "defaultExpireTimeout": 5000,
        "fullscreenExpireTimeout": 2000,
        "clearThreshold": 0.3,
        "expandThreshold": 20,
        "actionOnClick": false,
        "groupPreviewNum": 3,
        "openExpanded": false
    },
    "osd": {
        "enabled": true,
        "hideDelay": 2000,
        "enableBrightness": true,
        "enableMicrophone": false
    },
    "services": {
        "weatherLocation": "",
        "useFahrenheit": false,
        "useFahrenheitPerformance": false,
        "useTwelveHourClock": false,
        "gpuType": "",
        "visualiserBars": 60,
        "audioIncrement": 0.1,
        "brightnessIncrement": 0.1,
        "maxVolume": 1.0,
        "smartScheme": true,
        "defaultPlayer": "Spotify",
        "playerAliases": [{ "from": "com.github.th_ch.youtube_music", "to": "YT Music" }],
        "lyricsBackend": "Auto"
    },
    "session": {
        "enabled": true,
        "dragThreshold": 30,
        "vimKeybinds": false,
        "icons": {
            "logout": "logout",
            "shutdown": "power_settings_new",
            "hibernate": "downloading",
            "reboot": "cached"
        },
        "commands": {
            "logout": ["loginctl", "terminate-user", ""],
            "shutdown": ["systemctl", "poweroff"],
            "hibernate": ["systemctl", "hibernate"],
            "reboot": ["systemctl", "reboot"]
        }
    },
    "sidebar": {
        "enabled": true,
        "dragThreshold": 80
    },
    "utilities": {
        "enabled": true,
        "maxToasts": 4,
        "toasts": {
            "fullscreen": "off",
            "configLoaded": true,
            "chargingChanged": true,
            "gameModeChanged": true,
            "dndChanged": true,
            "audioOutputChanged": true,
            "audioInputChanged": true,
            "capsLockChanged": true,
            "numLockChanged": true,
            "kbLayoutChanged": true,
            "kbLimit": true,
            "vpnChanged": true,
            "nowPlaying": false
        },
        "vpn": {
            "enabled": false,
            "provider": [
                {
                    "name": "wireguard",
                    "interface": "your-connection-name",
                    "displayName": "Wireguard (Your VPN)",
                    "enabled": false
                }
            ]
        },
        "quickToggles": [
            {
                "id": "wifi",
                "enabled": true
            },
            {
                "id": "bluetooth",
                "enabled": true
            },
            {
                "id": "mic",
                "enabled": true
            },
            {
                "id": "settings",
                "enabled": true
            },
            {
                "id": "gameMode",
                "enabled": true
            },
            {
                "id": "dnd",
                "enabled": true
            },
            {
                "id": "vpn",
                "enabled": false
            }
        ]
    },
    "paths": {
        "wallpaperDir": "~/Pictures/Wallpapers",
        "lyricsDir": "~/Music/lyrics/",
        "sessionGif": "root:/assets/kurukuru.gif",
        "mediaGif": "root:/assets/bongocat.gif",
        "noNotifsPic": "root:/assets/dino.png",
        "lockNoNotifsPic": "root:/assets/dino.png"
    }
}
```

</details>

### Advanced configuration

> [!WARNING]
> Do NOT change any of these options if you do not know what you are doing. These options control the
> tokens used internally within the shell, and can cause visual issues if changed. The existence of
> the options are also not guaranteed across versions, and may change or be removed without notice.

A separate `~/.config/caelestia/shell-tokens.json` file allows editing the internal tokens without
touching the source code of the shell. These tokens affect, for example, individual rounding,
spacing, padding, font size, animation duration and easing curves tokens, and the sizes of certain
components. The appearance scale values in `shell.json` are multiplied against these base
token values to produce the final computed values.

Per-monitor token overrides are also available at
`~/.config/caelestia/monitors/<screen-name>/shell-tokens.json`.


---

## Nix / NixOS Installation

> **⚠️ Disclaimer:** I don't use Nix myself, so I can't personally vouch for this method. These instructions are inherited from upstream and may need updating. If you run into issues, contributions via PR are very welcome — I'll happily merge fixes from folks who actually use Nix.

Nix automatically builds the C++ QML plugins and libraries, resolves all fonts, packages dependencies, and handles startup configurations cleanly.

### Via Home Manager (Declarative & Autostart)

Add this repository to your flake inputs:

```nix
inputs = {
  niri-caelestia-shell.url = "github:Cantfirmed/niri-caelestia-shell";
};
```

Import the Home Manager module and enable the shell in your configuration:

```nix
{ inputs, pkgs, ... }: {
  imports = [
    inputs.niri-caelestia-shell.homeManagerModules.default
  ];

  programs.caelestia = {
    enable = true;
    systemd = {
      enable = true;
      target = "niri.service"; # Binds the shell's lifecycle to Niri starting
    };
    cli.enable = true; # Adds 'caelestia' CLI command to path
  };
}
```

When Niri starts, systemd will automatically start the Caelestia Shell service.

### Via Nix Run (Ad-hoc)

You can run the shell directly without adding it to your system packages:

```sh
nix run github:Cantfirmed/niri-caelestia-shell
```

### Home Manager Module Configuration

For NixOS users, a home manager module is also available:

<details><summary><code>home.nix</code></summary>

```nix
programs.caelestia = {
  enable = true;
  systemd = {
    enable = false; # if you prefer starting from your compositor
    target = "graphical-session.target";
    environment = [];
  };
  settings = {
    bar.status = {
      showBattery = false;
    };
    paths.wallpaperDir = "~/Images";
  };
  cli = {
    enable = true; # Also add caelestia-cli to path
    settings = {
      theme.enableGtk = false;
    };
  };
};
```

The module automatically adds Caelestia shell to the path with **full functionality**. The CLI is not required, however you have the option to enable and configure it.

</details>

---

## FAQ

### Need help or support?

You can join the community Discord server for assistance and discussion:
https://discord.gg/BGDCFCmMBk

### My screen is flickering, help pls!

Check your Niri compositor config for VRR/flickering related settings.

### How do I set up themed tmux with caelestia?

Caelestia includes a `tmux/chadmux.conf` status bar theme that reacts to wallpaper changes.

1. Make sure matugen is generating the tmux colour template (included by default):

   ```toml
   # ~/.config/matugen/config.toml
   [templates.tmux]
   input_path = '~/.config/matugen/templates/tmux/tmux.conf'
   output_path = '~/.config/tmux/matugen.conf'
   ```

2. Add these two lines to your `~/.config/tmux/tmux.conf`:

   ```tmux
   # Matugen-generated theme colours
   if-shell "test -f ~/.config/tmux/matugen.conf" "source-file ~/.config/tmux/matugen.conf"
   # Caelestia chadmux status bar
   source-file ~/.config/quickshell/niri-caelestia-shell/tmux/chadmux.conf
   ```

3. Reload tmux — the status bar now follows your wallpaper colours. The shell also
   automatically reloads tmux after every wallpaper change, so no manual steps needed.

### I want to make my own changes to the compositor config!

Edit the Niri config at `~/.config/niri/config.kdl`.

### I want to make my own changes to other stuff!

See the [manual installation](https://github.com/Cantfirmed/niri-caelestia-shell?tab=readme-ov-file#manual-installation) section
for the corresponding repo.

### I want to disable XXX feature!

Please read the [configuring](https://github.com/Cantfirmed/niri-caelestia-shell?tab=readme-ov-file#configuring) section in the readme.
If there is no corresponding option, make feature request.

### How do I make my colour scheme change with my wallpaper?

Set a wallpaper via the launcher or `caelestia wallpaper` and set the scheme to the dynamic scheme via the launcher
or `caelestia scheme set`. e.g.

```sh
caelestia wallpaper -f <path/to/file>
caelestia scheme set -n dynamic
```

### My wallpapers aren't showing up in the launcher!

The launcher pulls wallpapers from `~/Pictures/Wallpapers` by default. You can change this in the config. Additionally,
the launcher only shows an odd number of wallpapers at one time. If you only have 2 wallpapers, consider getting more
(or just putting one).

## Credits

Thanks to the original Caelestia community and all the contributors who helped make this shell what it is today!

A special thanks to [@outfoxxed](https://github.com/outfoxxed) for making Quickshell and the effort put into fixing issues
and implementing various feature requests.

Another special thanks to [@end_4](https://github.com/end-4) for his config which helped me a lot with learning how to use Quickshell.

Finally another thank you to all the configs I took inspiration from (only one for now):

-   [Axenide/Ax-Shell](https://github.com/Axenide/Ax-Shell)

## Stonks 📈

<a href="https://www.star-history.com/#Cantfirmed/niri-caelestia-shell&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Cantfirmed/niri-caelestia-shell&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Cantfirmed/niri-caelestia-shell&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Cantfirmed/niri-caelestia-shell&type=Date" />
 </picture>
</a>
