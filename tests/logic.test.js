// Unit tests for the pure-JS layers, run under node by tests/run.
// The QML files import these with `.pragma library`, which node doesn't
// understand — strip it and eval in a shared scope.
const fs = require("fs")
const path = require("path")
const assert = require("assert")

function loadLibrary(file) {
  const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8")
    .replace(/^\.pragma library$/m, "")
  const module = {}
  new Function("exports", `${src}
    exports.parse = typeof parse === "function" ? parse : undefined
    exports.sectionCount = typeof sectionCount === "function" ? sectionCount : undefined
    exports.sectionName = typeof sectionName === "function" ? sectionName : undefined
    exports.menuEntries = typeof menuEntries === "function" ? menuEntries : undefined
    exports.stateProbeScript = typeof stateProbeScript === "function" ? stateProbeScript : undefined
    exports.entryLabel = typeof entryLabel === "function" ? entryLabel : undefined
  `)(module)
  return module
}

// ---- Toml.js
const Toml = loadLibrary("Toml.js")

const parsed = Toml.parse(`
# comment
[bar]
replace = "on"
unit = 12
[counter]
label = "TIME REMAINING"   # trailing comment
[sections]
names = ["A", "B"]
[[section.4.entries]]
label = "X # not a comment"
exec = ["a", "b"]
[[section.4.entries]]
label = "Y"
window = "counter"
[section.4]
name = "MEDICAL"
`)
assert.strictEqual(parsed.bar.replace, "on")
assert.strictEqual(parsed.bar.unit, 12)
assert.strictEqual(parsed.counter.label, "TIME REMAINING")
assert.deepStrictEqual(parsed.sections.names, ["A", "B"])
assert.strictEqual(parsed.section["4"].entries.length, 2)
assert.strictEqual(parsed.section["4"].entries[0].label, "X # not a comment")
assert.deepStrictEqual(parsed.section["4"].entries[0].exec, ["a", "b"])
assert.strictEqual(parsed.section["4"].name, "MEDICAL")
assert.deepStrictEqual(Toml.parse(""), {})
assert.deepStrictEqual(Toml.parse("garbage without equals\n[x]\nk = 1"), { x: { k: 1 } })
console.log("Toml.js ok")

// ---- PactModel.js
const Model = loadLibrary("PactModel.js")

assert.strictEqual(Model.sectionCount(), 10)
assert.strictEqual(Model.sectionName(0, null), "SERVICES")
assert.strictEqual(Model.sectionName(3, { section: { "4": { name: "WORKSHOP" } } }), "WORKSHOP")

const defaults = Model.menuEntries(3, null)
assert.strictEqual(defaults[0].label, "GO TO FLOOR 04")
assert.strictEqual(defaults[0].floor, 4)
assert.ok(defaults.length > 1)

const overridden = Model.menuEntries(3, { section: { "4": { entries: [{ label: "ONLY", exec: ["true"] }] } } })
assert.strictEqual(overridden.length, 2)
assert.strictEqual(overridden[1].label, "ONLY")

const script = Model.stateProbeScript({ state: { rgb: { sh: "exit 0" }, "bad key!": { sh: "x" } } })
assert.ok(script.includes('echo "idle'))
assert.ok(script.includes('echo "rgb 1"'))
assert.ok(!script.includes("bad key"), "unsafe state keys must be dropped")

assert.strictEqual(Model.entryLabel({ label: "A", "label-on": "B", state: "s" }, { s: true }), "B")
assert.strictEqual(Model.entryLabel({ label: "A", "label-on": "B", state: "s" }, { s: false }), "A")
assert.strictEqual(Model.entryLabel({ label: "A" }, {}), "A")
console.log("PactModel.js ok")
