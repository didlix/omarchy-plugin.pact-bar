// Minimal TOML parser for pact.bar's config. Supports the subset the config
// uses: comments, [section.path], [[array.of.tables]], dotted keys, basic
// strings ("..." with \\ \" \n \t escapes), literal strings ('...'),
// integers, floats, booleans, and single-line arrays of scalars. Not
// supported (documented in config.toml): dates, inline tables, multi-line
// strings/arrays. Parse errors skip the offending line rather than throwing.
.pragma library

function parse(text) {
  var root = {}
  var current = root
  var lines = String(text || "").split("\n")

  for (var i = 0; i < lines.length; i++) {
    var line = stripComment(lines[i]).trim()
    if (!line) continue

    var arrayHeader = line.match(/^\[\[\s*([A-Za-z0-9_.-]+)\s*\]\]$/)
    if (arrayHeader) {
      var arr = ensurePath(root, arrayHeader[1].split("."), true)
      var table = {}
      arr.push(table)
      current = table
      continue
    }

    var header = line.match(/^\[\s*([A-Za-z0-9_.-]+)\s*\]$/)
    if (header) {
      current = ensurePath(root, header[1].split("."), false)
      continue
    }

    var kv = line.match(/^([A-Za-z0-9_.-]+|"[^"]+")\s*=\s*(.+)$/)
    if (!kv) continue
    var keyPath = kv[1].charAt(0) === '"'
      ? [kv[1].slice(1, -1)]
      : kv[1].split(".")
    var value = parseValue(kv[2].trim())
    if (value === undefined) continue
    var host = current
    for (var k = 0; k < keyPath.length - 1; k++) {
      var seg = keyPath[k]
      if (typeof host[seg] !== "object" || host[seg] === null || Array.isArray(host[seg])) host[seg] = {}
      host = host[seg]
    }
    host[keyPath[keyPath.length - 1]] = value
  }
  return root
}

function ensurePath(root, segments, asArray) {
  var host = root
  for (var i = 0; i < segments.length; i++) {
    var seg = segments[i]
    var last = i === segments.length - 1
    if (last && asArray) {
      if (!Array.isArray(host[seg])) host[seg] = []
      return host[seg]
    }
    var existing = host[seg]
    if (Array.isArray(existing)) {
      // [a.b] after [[a.b]] targets the newest element.
      if (existing.length === 0) existing.push({})
      host = existing[existing.length - 1]
    } else {
      if (typeof existing !== "object" || existing === null) host[seg] = {}
      host = host[seg]
    }
  }
  return host
}

function stripComment(line) {
  var out = ""
  var inBasic = false
  var inLiteral = false
  for (var i = 0; i < line.length; i++) {
    var ch = line.charAt(i)
    if (inBasic) {
      if (ch === "\\") { out += ch + (line.charAt(i + 1) || ""); i++; continue }
      if (ch === '"') inBasic = false
    } else if (inLiteral) {
      if (ch === "'") inLiteral = false
    } else {
      if (ch === '"') inBasic = true
      else if (ch === "'") inLiteral = true
      else if (ch === "#") break
    }
    out += ch
  }
  return out
}

function parseValue(raw) {
  if (raw === "true") return true
  if (raw === "false") return false

  if (raw.charAt(0) === '"' && raw.charAt(raw.length - 1) === '"') {
    return raw.slice(1, -1)
      .replace(/\\n/g, "\n").replace(/\\t/g, "\t")
      .replace(/\\"/g, '"').replace(/\\\\/g, "\\")
  }
  if (raw.charAt(0) === "'" && raw.charAt(raw.length - 1) === "'") {
    return raw.slice(1, -1)
  }

  if (raw.charAt(0) === "[") {
    if (raw.charAt(raw.length - 1) !== "]") return undefined
    var inner = raw.slice(1, -1).trim()
    if (!inner) return []
    var items = splitTopLevel(inner)
    var out = []
    for (var i = 0; i < items.length; i++) {
      var v = parseValue(items[i].trim())
      if (v !== undefined) out.push(v)
    }
    return out
  }

  if (/^[+-]?\d+$/.test(raw)) return parseInt(raw, 10)
  if (/^[+-]?\d*\.\d+$/.test(raw)) return parseFloat(raw)
  return undefined
}

// Split "a", "b, c", 'd' on top-level commas, respecting quotes.
function splitTopLevel(text) {
  var parts = []
  var buf = ""
  var inBasic = false
  var inLiteral = false
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (inBasic) {
      if (ch === "\\") { buf += ch + (text.charAt(i + 1) || ""); i++; continue }
      if (ch === '"') inBasic = false
      buf += ch
    } else if (inLiteral) {
      if (ch === "'") inLiteral = false
      buf += ch
    } else if (ch === '"') { inBasic = true; buf += ch }
    else if (ch === "'") { inLiteral = true; buf += ch }
    else if (ch === ",") { parts.push(buf); buf = "" }
    else buf += ch
  }
  if (buf.trim()) parts.push(buf)
  return parts
}
