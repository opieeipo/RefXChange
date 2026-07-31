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

RefXChange itself needs **Bash 4+** and standard POSIX utilities (`sed`, `awk`,
`grep`).

---

## Installation

```bash
# Clone or download, then make it executable
chmod +x refxchange.sh

# (Optional) put it on your PATH for global use
sudo cp refxchange.sh /usr/local/bin/refxchange
```

Verify the install:

```bash
refxchange --version
```

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
