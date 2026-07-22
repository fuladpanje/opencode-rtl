# OpenCode-RTL

Fix broken RTL (Persian / Arabic) text rendering in **OpenCode Desktop** on Windows.

---

## What it fixes

OpenCode renders Persian and Arabic text incorrectly (wrong alignment, misplaced punctuation). This patch fixes it by:

- Aligning chat messages, markdown, blockquotes and lists to the right when they contain RTL text
- Loading the **Vazirmatn** font for Persian / Arabic characters
- Keeping English, code and file paths left-to-right
- Protecting the terminal (xterm) so it is never affected by RTL

---

## Requirements

- Windows
- OpenCode Desktop installed
- Node.js available in PATH
- Internet access on first run (loads the Vazirmatn font from Google Fonts)

---

## Install (patch)

**Option A — double-click**

Download the ZIP, extract it, then double-click `patch.bat`.

**Option B — PowerShell**

```powershell
powershell -ExecutionPolicy Bypass -File .\patch\patch.ps1
```

If OpenCode is not found automatically, the script will ask you for the path. You can also pass it directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\patch\patch.ps1 -AsarPath "C:\Path\To\OpenCode\resources\app.asar"
```

After patching, fully quit and reopen OpenCode.

---

## Restore (unpatch)

```powershell
powershell -ExecutionPolicy Bypass -File .\patch\unpatch.ps1
```

A backup of `app.asar` is created automatically before patching.

---

## How it works

The script patches the installed `app.asar` **in place** (binary patch, no extraction). It injects a small RTL script into `renderer/index.html`. OpenCode updates can overwrite the patch — just run it again.

---

## Author

**Reza Fuladpanjeh** — [fuladpanjeh.ir](https://fuladpanjeh.ir)

## License

[MIT](./LICENSE)
