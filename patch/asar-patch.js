const fs = require("fs")

const asarPath = process.argv[2]
if (!asarPath) {
  console.error("Usage: node asar-patch.js <path-to-app.asar>")
  process.exit(1)
}

const buf = fs.readFileSync(asarPath)
const headerSizeVal = buf.readUInt32LE(4)
const jsonStart = 16
const dataStart = 8 + headerSizeVal
const headerJSONStr = buf.slice(jsonStart, dataStart).toString("utf8").replace(/\0/g, "")

const header = JSON.parse(headerJSONStr)

let htmlEntry = null
function findEntry(obj, prefix) {
  for (const [name, entry] of Object.entries(obj)) {
    if (name === "index.html" && prefix.includes("renderer")) {
      htmlEntry = entry
      return
    }
    if (entry.files) findEntry(entry.files, prefix + name + "/")
  }
}
findEntry(header.files, "")

if (!htmlEntry) {
  console.error("Could not find index.html in renderer directory")
  process.exit(1)
}

const origHtmlSize = parseInt(htmlEntry.size)
const origHtmlOffset = parseInt(htmlEntry.offset)
const htmlContent = buf.slice(dataStart + origHtmlOffset, dataStart + origHtmlOffset + origHtmlSize).toString("utf8")

const marker = "opencode-rtl-fix"
if (htmlContent.includes(marker)) {
  console.log("Already patched! Skipping.")
  process.exit(0)
}

const rtlRegex = new RegExp("[" +
  String.fromCharCode(0x0600) + "-" + String.fromCharCode(0x06FF) +
  String.fromCharCode(0x0750) + "-" + String.fromCharCode(0x077F) +
  String.fromCharCode(0x0870) + "-" + String.fromCharCode(0x08FF) +
  String.fromCharCode(0xFB50) + "-" + String.fromCharCode(0xFDFF) +
  String.fromCharCode(0xFE70) + "-" + String.fromCharCode(0xFEFC) + "]")

const rtlScript = [
  '<script id="' + marker + '">',
  "(function() {",
  "  var rtl = " + rtlRegex.toString() + ";",
  "  var isTerminal = function(el) {",
  "    return el instanceof HTMLElement && (",
  '      el.classList.contains("xterm") ||',
  '      el.classList.contains("xterm-screen") ||',
  '      el.classList.contains("xterm-viewport") ||',
  '      el.classList.contains("terminal") ||',
  '      el.closest(".xterm,.xterm-screen,.xterm-viewport,.terminal")',
  "    )",
  "  }",
  "  var style = document.createElement('style');",
  "  style.textContent = \"@font-face{font-family:'Vazirmatn';font-style:normal;font-weight:100 900;font-display:swap;src:url(https://fonts.gstatic.com/s/vazirmatn/v16/Dxxo8j6PP2D_kU2muijlGMWWMmk.woff2) format('woff2');unicode-range:U+0600-06FF,U+0750-077F,U+0870-088E,U+0890-0891,U+0897-08E1,U+08E3-08FF,U+200C-200E,U+2010-2011,U+204F,U+2E41,U+FB50-FDFF,U+FE70-FE74,U+FE76-FEFC}\";",
  "  document.head.appendChild(style);",
  "  var selectors = [",
  '    \'[data-component="markdown"]\',',
  '    \'[data-component="text-part"]\',',
  '    \'[data-slot="text-part-body"]\',',
  '    \'[data-slot="user-message-text"]\',',
  '    \'[data-component="prompt-input"]\',',
  '    \'[data-component="markdown"] blockquote\',',
  '    \'[data-component="markdown"] blockquote p\',',
  '    \'[data-component="markdown"] p\',',
  '    \'[data-component="markdown"] li\'',
  '  ].join(",");',
  "  function fix(el) {",
  "    if (!(el instanceof HTMLElement) || isTerminal(el)) return;",
  '    var text = el.innerText || el.textContent || "";',
  "    if (!text.trim()) return;",
  "    var r = rtl.test(text);",
  '    el.setAttribute("dir", r ? "rtl" : "ltr");',
  '    el.style.textAlign = r ? "right" : "left";',
  '    el.style.unicodeBidi = "plaintext";',
  "    if (r) el.style.fontFamily = \"'Vazirmatn', sans-serif\";",
  '    if (r && el.closest("blockquote")) el.style.direction = "rtl";',
  "  }",
  "  function run() {",
  "    document.querySelectorAll(selectors).forEach(function(el) {",
  "      if (!isTerminal(el)) fix(el);",
  "    });",
  "  }",
  "  new MutationObserver(function(mutations) {",
  "    mutations.forEach(function(m) {",
  "      m.addedNodes.forEach(function(node) {",
  "        if (node instanceof HTMLElement && !isTerminal(node)) {",
  "          if (node.matches(selectors)) fix(node);",
  "          node.querySelectorAll(selectors).forEach(fix);",
  "        }",
  "      });",
  "      if (m.type === 'characterData' && m.target.parentElement) {",
  "        var p = m.target.parentElement;",
  "        if (!isTerminal(p)) {",
  "          var closest = p.closest(selectors);",
  "          if (closest) fix(closest);",
  "        }",
  "      }",
  "    });",
  "  }).observe(document.documentElement, { childList: true, subtree: true, characterData: true });",
  "  run();",
  "})();",
  "</script>"
].join("\n")

const newHtml = htmlContent.replace("</body>", "\n" + rtlScript + "\n</body>")
const newHtmlBuf = Buffer.from(newHtml, "utf8")
const newSize = newHtmlBuf.length

console.log("Original HTML: " + origHtmlSize + " bytes, New: " + newSize + " bytes")

// Collect all files sorted by offset
function getFiles(obj, prefix) {
  var result = []
  for (var name in obj) {
    var entry = obj[name]
    if (entry.files) {
      result = result.concat(getFiles(entry.files, prefix + name + "/"))
    } else {
      result.push({ path: prefix + name, offset: parseInt(entry.offset), size: parseInt(entry.size), entry: entry })
    }
  }
  return result
}
var allFiles = getFiles(header.files, "")
allFiles.sort(function(a, b) { return a.offset - b.offset })

// Build data buffers and calculate ACTUAL new offsets based on sequential layout
var dataBuffers = []
var currentOffset = 0

for (var i = 0; i < allFiles.length; i++) {
  var f = allFiles[i]
  var isHtml = f.path.includes("index.html") && f.path.includes("renderer")
  var fileSize = isHtml ? newSize : f.size
  var paddedSize = Math.ceil(fileSize / 4) * 4

  // Update the entry's offset to the ACTUAL position in the new data section
  f.entry.offset = currentOffset.toString()
  f.entry.size = fileSize

  var dataBuf
  if (isHtml) {
    dataBuf = Buffer.alloc(paddedSize, 0)
    newHtmlBuf.copy(dataBuf)
  } else {
    var origDataOffset = dataStart + f.offset
    var origBuf = buf.slice(origDataOffset, origDataOffset + f.size)
    dataBuf = Buffer.alloc(paddedSize, 0)
    origBuf.copy(dataBuf)
  }

  dataBuffers.push(dataBuf)
  currentOffset += paddedSize
}

// Strip integrity fields (they depend on original data hashes, invalid after rebuild)
function stripIntegrity(obj) {
  for (var name in obj) {
    var entry = obj[name]
    if (entry && entry.integrity) delete entry.integrity
    if (entry && entry.files) stripIntegrity(entry.files)
  }
}
stripIntegrity(header.files)

// Serialize header
var newHeaderJSON = JSON.stringify(header)
var paddedJsonLen = Math.ceil(newHeaderJSON.length / 4) * 4

// Build asar: [4-byte type] [4-byte headerSize] [8-byte meta] [JSON padded] [data]
// headerSize = 8 (meta) + paddedJsonLen
var headerAreaSize = 8 + paddedJsonLen
var jsonByteLen = newHeaderJSON.length

var prefixBuf = Buffer.alloc(16, 0)
prefixBuf.writeUInt32LE(4, 0)                // always 4
prefixBuf.writeUInt32LE(headerAreaSize, 4)    // header area size (from byte 8)
prefixBuf.writeUInt32LE(headerAreaSize - 4, 8) // headerAreaSize - 4
prefixBuf.writeUInt32LE(jsonByteLen, 12)       // JSON string byte length

var headerBuf = Buffer.alloc(paddedJsonLen, 0)
Buffer.from(newHeaderJSON, "utf8").copy(headerBuf)

var finalBuf = Buffer.concat([prefixBuf, headerBuf].concat(dataBuffers))

var backupPath = asarPath + ".backup"
fs.writeFileSync(backupPath, buf)
fs.writeFileSync(asarPath, finalBuf)

console.log("Patched successfully!")
console.log("Backup: " + backupPath)
