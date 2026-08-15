# Default sections and menus

Everything below is the built-in configuration, expressed as the
`~/.config/omarchy/pact/config.toml` that would reproduce it. Copy any
section into your config and edit — defining `[[section.N.entries]]`
replaces that section's menu wholesale (the GO TO FLOOR entry is always
kept first), and `[section.N] name` renames the floor.

```toml
[bar]
sections = 10          # floors shown (workspaces 1..N)
font-scale = 1.4       # chrome text as a multiple of the system font size

[section.1]
name = "SERVICES"
[[section.1.entries]]
label = "THEME GALLERY"
exec = ["omarchy", "menu", "summon", "style.theme"]
[[section.1.entries]]
label = "CAPTURE SCREEN"
exec = ["omarchy", "capture", "screenshot"]
[[section.1.entries]]
label = "NIGHT LIGHT"
label-on = "NIGHT LIGHT OFF"
state = "nightlight"
exec = ["omarchy", "toggle", "nightlight"]
[[section.1.entries]]
label = "SCREENSAVER"
exec = ["omarchy", "launch", "screensaver"]

[section.2]
name = "STATUS"
[[section.2.entries]]
label = "SILO STATUS"
window = "status"
[[section.2.entries]]
label = "ABOUT SILO"
exec = ["omarchy", "launch", "about"]

[section.3]
name = "SYSTEM"
[[section.3.entries]]
label = "OMARCHY MENU"
exec = ["omarchy", "menu", "toggle", "system"]
[[section.3.entries]]
label = "RESTART SHELL"
exec = ["omarchy", "restart", "shell"]
[[section.3.entries]]
label = "SWAP TO STOCK BAR"
cli = "toggle"

[section.4]
name = "MEDICAL"
[[section.4.entries]]
label = "PACT COUNTER"
window = "counter"

[section.5]
name = "SECURITY"
[[section.5.entries]]
label = "LOCK SYSTEM"
exec = ["omarchy", "system", "lock"]
[[section.5.entries]]
label = "STAY AWAKE"
label-on = "ALLOW IDLE"
state = "idle"
exec = ["omarchy", "toggle", "idle"]

[section.6]
name = "EMERGENCY"
[[section.6.entries]]
label = "RED ALERT"
window = "emergency"

[section.7]
name = "UTILITIES"
[[section.7.entries]]
label = "TERMINAL"
exec = ["omarchy", "launch", "terminal"]
[[section.7.entries]]
label = "FILES"
exec = ["omarchy", "launch", "nautilus"]

[section.8]
name = "PRIVACY"
[[section.8.entries]]
label = "SILENCE ALERTS"
label-on = "RESTORE ALERTS"
state = "dnd"
exec = ["omarchy", "toggle", "notification", "silencing"]

[section.9]
name = "RECYCLE"
# no entries — the floor jump alone

[section.10]
name = "CONTACT"
[[section.10.entries]]
label = "SILOMAIL"
exec = ["xdg-email"]
[[section.10.entries]]
label = "SIGNAL"
exec = ["omarchy", "launch", "signal"]
```

## Entry reference

| key        | meaning                                                    |
|------------|------------------------------------------------------------|
| `label`    | shown in the menu (required)                               |
| `exec`     | argv to run detached                                       |
| `window`   | open a built-in window: `status`, `counter`, `emergency`   |
| `cli`      | run `pactcli bar <value>`                                  |
| `state`    | live probe key: `idle`, `nightlight`, `dnd`, or a custom key |
| `label-on` | label shown while the probed state is on                   |

Custom probes: `[state.<key>] sh = "<command>"` — the command's exit
status is the state (0 = on). Example:

```toml
[state.rgb]
sh = "omarchy-rgb is-on"
```
