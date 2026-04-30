# bookly-typst — Quarto extension for the Bookly Typst template

[![Quarto](https://img.shields.io/badge/Quarto-%3E%3D1.9.17-blue)](https://quarto.org)
[![bookly](https://img.shields.io/badge/bookly-3.1.0-cornflowerblue)](https://github.com/maucejo/bookly)
[![License: MIT](https://img.shields.io/badge/License-MIT-forestgreen)](LICENSE)

This Quarto extension lets you use the [bookly](https://github.com/maucejo/bookly) Typst package for book projects. It automatically handles parts, chapters, and appendices with chapter-based numbering.

## Installation

```bash
quarto add maucejo/quarto-bookly
```

Or use this repository directly as a template:

```bash
quarto use template maucejo/quarto-bookly
```

## Usage

In your `_quarto.yml`:

```yaml
project:
  type: book

book:
  title: "My Book"
  author: "First Last"
  chapters:
    - index.qmd
    - chapters/intro.qmd
  appendices:
    - appendices/appendixA.qmd

format:
  bookly-typst:
    lang: en
    toc: true
    lof: true
    lot: true
    fonts:
      body: "Lato"
      math: "Lete Sans Math"
    theme: modern
```

## Available options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `toc` | `true` / `false` | `false` | Show table of contents |
| `lof` | `true` / `false` | `false` | Show list of figures |
| `lot` | `true` / `false` | `false` | Show list of tables |
| `theme` | `classic`, `modern`, `fancy`, `obook`, `orly`, `pretty` | `modern` | Visual theme |
| `tufte` | `true` / `false` | `false` | Enable Tufte-style layout |
| `config-options.open-right` | `true` / `false` | `true` | Start chapters on right-hand pages |
| `config-options.alt-margins` | `true` / `false` | `false` | Alternate recto/verso margins |
| `part-numbering` | Typst numbering string (`"1"`, `"A"`, `"I"`, etc.) | bookly default | Part numbering style |
| `config-options.<key>` | Typst value | — | Generic passthrough to `config-options` |
| `colors.primary` | Typst color value | — | Primary color |
| `colors.secondary` | Typst color value | — | Secondary color |
| `fonts.body` | Typst font family name | bookly default | Body text font |
| `fonts.math` | Typst font family name | bookly default | Math font |
| `fonts.raw` | Typst font family name | bookly default | Raw/code font |

Standard Quarto/Typst options such as `margin`, `toc`, and `lang` are also supported.

Example for generic `config-options` passthrough:

```yaml
format:
  bookly-typst:
    config-options:
      open-right: true
      alt-margins: false
      part-numbering: "A"
```

## Generated book structure

```text
_quarto.yml
index.qmd
chapters/
  intro.qmd
  methods.qmd
appendices/
  appendixA.qmd
```

## Features

- Parts are transformed into native bookly `#part[...]` calls
- Appendices automatically switch to `#show: appendix` and alphabetical numbering
- Chapter-based numbering for equations, figures, and tables
- All Bookly themes are available through `theme`
- Quarto callouts are mapped to Bookly information boxes

## Requirements

- Quarto >= 1.9.17
- Typst package `bookly:3.1.0` (resolved automatically by Typst)

## Render

```bash
quarto render
```

## Split Typst file workflow

To generate a split Typst master file using `#include` directives:

```bash
just split
```

To compile the split Typst output and move the PDF into `_book`:

```bash
just compile
```

You can provide an output file name (with or without the `.pdf` extension):

```bash
just compile my-book
just compile my-book.pdf
```

The `compile-typst` recipe provides the same behavior using `typst compile` directly:

```bash
just compile-typst
just compile-typst my-book
```

The split workflow:

- Renders Quarto to `index.typ`
- Splits `index.typ` into Typst fragments following `_quarto.yml` structure
- Refactors generated Typ files to be more idiomatic for Typst, especially for equation blocks and cross-references
- Generates `_split_typ/index-split.typ` with `#include` chain
- Compiles `_split_typ/index-split.typ`
- Mirrors `*_files` resource directories for relative assets

Main outputs:

- `_split_typ/index-split.typ`
- `_split_typ/book/*.typ`
- `_book/<output-name>.pdf` (default: `_book/index-split.pdf`)

## License

MIT — Copyright © 2026 Mathieu Aucejo
