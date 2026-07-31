# RefXChange

**RefXChange** is a lightweight Bash utility for converting bibliographic
reference files between popular citation formats — RIS, NBIB (PubMed), BibTeX,
BibLaTeX, EndNote, CSL-JSON, and more — straight from the command line.

It wraps the heavy lifting in a single portable script so you can batch-convert
your references without opening a reference manager, memorizing a dozen
tool-specific flags, or writing throwaway conversion scripts.

---

## Features

- Convert between **RIS, NBIB, BibTeX, BibLaTeX, EndNote (ENW/XML), CSL-JSON, MODS,** and **Word (`.docx`) bibliographies**
- Auto-detect the input format from the file extension (override when needed)
- Batch mode — convert whole directories or glob patterns in one call
- Read from `stdin` / write to `stdout` for use in pipelines
- Encoding control (UTF-8 by default) and optional key normalization for BibTeX output
- Clear, greppable error messages and non-zero exit codes for scripting

---

## Requirements

RefXChange is a thin orchestration layer. It shells out to well-established
conversion back ends, so you'll need at least one of the following installed and
on your `PATH`:

| Back end | Handles | Install |
|----------|---------|---------|
| [`bibutils`](https://sourceforge.net/p/bibutils/) | RIS, NBIB, BibTeX, EndNote, MODS, Word | `apt install bibutils` / `brew install bibutils` |
| [`pandoc`](https://pandoc.org/) | BibTeX ↔ CSL-JSON ↔ BibLaTeX | `apt install pandoc` / `brew install pandoc` |

RefXChange itself needs **Bash 3.2+** (the stock macOS bash is fine) and
standard POSIX utilities (`sed`, `awk`, `grep`, `tr`). On Windows it runs under
Git Bash or WSL. `gettext` is optional — without it, messages stay in English.

---

## Installation

Clone the repo and run the installer for your platform. Both install into a
**user-local prefix** — no `sudo`, nothing written outside your home directory.

### macOS / Linux / WSL / Git Bash

```bash
git clone https://github.com/opieeipo/RefXChange.git
cd RefXChange
./install.sh          # or: make install
```

This lays down:

| Path | Contents |
|------|----------|
| `~/.local/bin/refxchange` | the executable |
| `~/.local/share/refxchange/lib/` | sourced helper modules |
| `~/.local/share/refxchange/locale/` | message catalogs (compiled to `.mo` when `msgfmt` is available) |

If `~/.local/bin` isn't on your `PATH`, the installer prints the exact line to
add for your shell. Override the prefix with `--prefix` (or `PREFIX=`):

```bash
./install.sh --prefix /usr/local     # system-wide; needs write access
make install PREFIX=/opt/refxchange
```

### Windows (PowerShell)

RefXChange is a Bash program, so Windows needs [Git for
Windows](https://git-scm.com/download/win) (Git Bash) or WSL. The installer
finds one, then installs a `refxchange.cmd` shim and puts it on your user
`PATH`:

```powershell
git clone https://github.com/opieeipo/RefXChange.git
cd RefXChange
.\install.ps1                        # -> %LOCALAPPDATA%\Programs\RefXChange
.\install.ps1 -Prefix D:\Tools\RefXChange
```

Open a new terminal afterwards so the `PATH` change takes effect.

### Verify

```bash
refxchange --version
```

### Development installs

`--link` symlinks the command at your checkout instead of copying, so edits take
effect immediately:

```bash
./install.sh --link        # or: make link
```

### Uninstall

```bash
./install.sh --uninstall   # or: make uninstall
```

```powershell
.\install.ps1 -Uninstall
```

The command locates its own `lib/` and `locale/` relative to itself (following
symlinks), falling back to `~/.local/share/refxchange` and `/usr/local/share/refxchange`.
Set `REFXCHANGE_ROOT` to point it at a specific tree if you need to override that.

---

## Usage

```
refxchange [OPTIONS] -f <FROM> -t <TO> -i <INPUT> [-o <OUTPUT>]
```

### Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-f` | `--from`    | Source format. Auto-detected from the extension if omitted. |
| `-t` | `--to`      | Target format. **Required.** |
| `-i` | `--input`   | Input file, directory, or `-` for `stdin`. **Required.** |
| `-o` | `--output`  | Output file or directory. Defaults to `stdout` (or alongside input in batch mode). |
| `-b` | `--batch`   | Treat `--input` as a directory/glob and convert every matching file. |
| `-e` | `--encoding`| Character encoding for I/O (default: `utf-8`). |
| `-k` | `--keys`    | Normalize BibTeX citation keys (e.g. `author_year`). |
| `-F` | `--force`   | Overwrite existing output files without prompting. |
| `-q` | `--quiet`   | Suppress progress output; errors still go to `stderr`. |
| `-v` | `--verbose` | Print each back-end command as it runs. |
|      | `--version` | Print version and exit. |
| `-h` | `--help`    | Show help and exit. |

### Supported format identifiers

`ris`, `nbib`, `bibtex` (alias `bib`), `biblatex`, `endnote` (alias `enw`),
`endnote-xml`, `csljson` (alias `json`), `mods`, `word` (alias `docx`).

---

## Examples

Convert a single RIS file to BibTeX:

```bash
refxchange -f ris -t bibtex -i refs.ris -o refs.bib
```

Let RefXChange detect the input format from the extension:

```bash
refxchange -t csljson -i pubmed_export.nbib -o library.json
```

Batch-convert every RIS file in a folder to BibTeX, written next to the originals:

```bash
refxchange --batch -t bibtex -i ./exports/ -o ./bibtex/
```

Use it in a pipeline (stdin → stdout):

```bash
cat refs.ris | refxchange -f ris -t bibtex - > refs.bib
```

Convert NBIB from PubMed and normalize the citation keys:

```bash
refxchange -f nbib -t bibtex -k author_year -i search_results.nbib -o clean.bib
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success |
| `1`  | Invalid arguments or usage error |
| `2`  | Unsupported or unrecognized format |
| `3`  | Missing required back end (e.g. `bibutils` not installed) |
| `4`  | Input file not found or unreadable |
| `5`  | Conversion failed |

---

## Notes & tips

- **Round-tripping isn't lossless.** Every format models references a little
  differently, so fields with no equivalent in the target format may be dropped
  or approximated. Spot-check important entries after converting.
- **NBIB is PubMed's flavor of RIS-like tagged text** — RefXChange handles the
  MEDLINE tag set, but exotic tags from other databases may need manual cleanup.
- For large libraries, prefer **batch mode** over shell loops — it reuses the
  back-end process where possible and gives you a single summary at the end.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `error: back end 'bibutils' not found` | Missing dependency | Install `bibutils` (see Requirements) |
| Garbled accents/diacritics | Encoding mismatch | Pass `--encoding utf-8` (or the source's real encoding) |
| Empty output file | Wrong `--from` format | Set `--from` explicitly instead of relying on auto-detect |
| `permission denied` | Script not executable | `chmod +x refxchange.sh` |

---

## License

Released under the MIT License. See `LICENSE` for details.

## Contributing

Issues and pull requests are welcome. Please include a small sample input file
that reproduces any conversion bug you report.
