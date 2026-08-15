// PACT bar section config. Section i maps to Hyprland workspace i+1.
// Users can rename sections and replace their submenus via
// ~/.config/omarchy/pact/config.toml — see that file for the entry schema.
// Entry shapes:
//   { label, exec: ["argv", ...] }    — detached command
//   { label, window: "status" }       — built-in PACT overlay window
//   { label, cli: "toggle" }          — `pactcli bar <value>`
//   plus optional state: "idle|nightlight|dnd" and "label-on" for the
//   inverse label while that state is on.
var SECTIONS = [
  { name: "SERVICES", entries: [
    { label: "THEME GALLERY", exec: ["omarchy", "menu", "summon", "style.theme"] },
    { label: "CAPTURE SCREEN", exec: ["omarchy", "capture", "screenshot"] },
    { label: "NIGHT LIGHT", "label-on": "NIGHT LIGHT OFF", state: "nightlight",
      exec: ["omarchy", "toggle", "nightlight"] },
    { label: "SCREENSAVER", exec: ["omarchy", "launch", "screensaver"] },
  ] },
  { name: "STATUS", entries: [
    { label: "SILO STATUS", window: "status" },
    { label: "ABOUT SILO", exec: ["omarchy", "launch", "about"] },
  ] },
  { name: "SYSTEM", entries: [
    { label: "OMARCHY MENU", exec: ["omarchy", "menu", "toggle", "system"] },
    { label: "RESTART SHELL", exec: ["omarchy", "restart", "shell"] },
    { label: "SWAP TO STOCK BAR", cli: "toggle" },
  ] },
  { name: "MEDICAL", entries: [
    { label: "PACT COUNTER", window: "counter" },
  ] },
  { name: "SECURITY", entries: [
    { label: "LOCK SYSTEM", exec: ["omarchy", "system", "lock"] },
    { label: "STAY AWAKE", "label-on": "ALLOW IDLE", state: "idle",
      exec: ["omarchy", "toggle", "idle"] },
  ] },
  { name: "EMERGENCY", entries: [
    { label: "RED ALERT", window: "emergency" },
  ] },
  { name: "UTILITIES", entries: [
    { label: "TERMINAL", exec: ["omarchy", "launch", "terminal"] },
    { label: "FILES", exec: ["omarchy", "launch", "nautilus"] },
  ] },
  { name: "PRIVACY", entries: [
    { label: "SILENCE ALERTS", "label-on": "RESTORE ALERTS", state: "dnd",
      exec: ["omarchy", "toggle", "notification", "silencing"] },
  ] },
  { name: "RECYCLE", entries: [] },
  { name: "CONTACT", entries: [
    { label: "SILOMAIL", exec: ["xdg-email"] },
    { label: "SIGNAL", exec: ["omarchy", "launch", "signal"] },
  ] },
]

function sectionCount() { return SECTIONS.length }

// config is the parsed pact config.toml (or {}): overrides live under
// config.section[N] with optional `name` and `entries`.
function sectionOverride(config, i) {
  var sections = config && config.section
  return sections ? sections[String(i + 1)] || null : null
}

function sectionName(i, config) {
  var override = sectionOverride(config, i)
  if (override && typeof override.name === "string" && override.name) return override.name
  return SECTIONS[i] ? SECTIONS[i].name : ""
}

// Full menu for a section: floor jump first, then the configured entries
// (user-supplied entries replace the defaults wholesale).
function menuEntries(i, config) {
  var floor = (i + 1 < 10 ? "0" : "") + (i + 1)
  var list = [{ label: "GO TO FLOOR " + floor, floor: i + 1 }]
  var override = sectionOverride(config, i)
  var extra = override && Array.isArray(override.entries) && override.entries.length
    ? override.entries
    : (SECTIONS[i] ? SECTIONS[i].entries : [])
  for (var j = 0; j < extra.length; j++) {
    if (extra[j] && typeof extra[j].label === "string") list.push(extra[j])
  }
  return list
}

// One shell round-trip refreshing every live state the menus can show.
// Emits "key 0|1" lines. Built-ins (idle/nightlight/dnd) plus any custom
// probes from config [state.<key>] sh = "<command>" — the command's exit
// status is the state (0 = on).
function stateProbeScript(config) {
  var script =
    'i=$(omarchy toggle idle status 2>/dev/null); case "$i" in *\'"enabled":true\'*) echo "idle 1";; *) echo "idle 0";; esac; ' +
    'n=$(omarchy toggle nightlight --status 2>/dev/null); case "$n" in *\'"enabled":true\'*) echo "nightlight 1";; *) echo "nightlight 0";; esac; ' +
    'd=$(omarchy-shell notifications dndState 2>/dev/null); if [ "$d" = "on" ]; then echo "dnd 1"; else echo "dnd 0"; fi'
  var custom = config && config.state ? config.state : null
  if (custom) {
    for (var key in custom) {
      if (!/^[A-Za-z0-9_-]+$/.test(key)) continue
      var probe = custom[key] && typeof custom[key].sh === "string" ? custom[key].sh : ""
      if (!probe) continue
      var quoted = probe.replace(/'/g, "'\\''")
      script += "; if sh -c '" + quoted + "' >/dev/null 2>&1; then echo \"" + key + " 1\"; else echo \"" + key + " 0\"; fi"
    }
  }
  return script
}

function entryLabel(entry, states) {
  if (entry && entry.state && states && states[entry.state] === true) {
    return entry["label-on"] || entry.labelOn || entry.label
  }
  return entry ? entry.label : ""
}
