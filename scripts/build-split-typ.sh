#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/_split_typ"
BOOK_DIR="$OUT_DIR/book"
INDEX_TYP="$ROOT_DIR/index.typ"
MASTER_TYP="$OUT_DIR/index-split.typ"
MASTER_PDF="$OUT_DIR/index-split.pdf"
QUARTO_CONFIG="$ROOT_DIR/_quarto.yml"

if [[ ! -f "$QUARTO_CONFIG" && -f "$ROOT_DIR/_quarto.yaml" ]]; then
  QUARTO_CONFIG="$ROOT_DIR/_quarto.yaml"
fi

if [[ ! -f "$QUARTO_CONFIG" ]]; then
  echo "Error: _quarto.yml or _quarto.yaml not found." >&2
  exit 1
fi

rm -rf "$BOOK_DIR"
mkdir -p "$BOOK_DIR"

cd "$ROOT_DIR"

echo "[1/6] Render Quarto to index.typ (keep-typ=true)"
quarto render --to bookly-typst -M keep-typ:true >/dev/null

if [[ ! -f "$INDEX_TYP" ]]; then
  echo "Error: index.typ not found after render." >&2
  exit 1
fi

normalize_typst_idioms() {
  local file="$1"

  # Add automatic reference supplement behavior after the full bookly.with(...) block.
  # We inject this once, only when not already present.
  if /usr/bin/grep -q '^#show: bookly\.with(' "$file" && ! /usr/bin/grep -q '^#set ref(supplement: auto)' "$file"; then
    local tmp="$file.tmp"
    awk '
      {
        print $0
        if ($0 ~ /^#show: bookly\.with\(/ && inserted == 0) {
          in_bookly = 1
          next
        }
        if (in_bookly == 1 && $0 ~ /^\)$/ && inserted == 0) {
          print "#set ref(supplement: auto)"
          inserted = 1
          in_bookly = 0
        }
      }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  fi

  # Convert Quarto's verbose display-equation form to idiomatic Typst math.
  # Example:
  #   #math.equation(..., [ $ E = mc^2 $ ])<eq-einstein>
  # becomes:
  #   $ E = mc^2 $<eq-einstein>
  perl -i -pe 's/#math\.equation\(block: true, numbering: equation-numbering, \[ \$ (.*?) \$ \]\)<([^>]+)>/\$ $1 \$<$2>/g; s/#math\.equation\(block: true, numbering: equation-numbering, \[ \$ (.*?) \$ \]\)/\$ $1 \$/g' "$file"

  # Convert verbose cross-references to Typst shorthand.
  # Example: #ref(<eq-einstein>, supplement: [Equation]) -> @eq-einstein
  perl -i -pe 's/#ref\(<([^>]+)>,\s*supplement:\s*\[[^\]]+\]\)/\@$1/g' "$file"
}

echo "[2/6] Normalize Typst idioms in index.typ"
normalize_typst_idioms "$INDEX_TYP"

tmp_entries="$OUT_DIR/.entries.tsv"
tmp_starts="$OUT_DIR/.starts.tsv"
: > "$tmp_entries"
: > "$tmp_starts"

echo "[3/6] Read structure (_quarto.yml + qmd titles)"

part_idx=0
while IFS= read -r line; do
  part_title=$(printf "%s" "$line" | sed -E 's/^.*part:[[:space:]]*"(.*)"[[:space:]]*$/\1/')
  [[ -z "$part_title" ]] && continue
  part_idx=$((part_idx + 1))
  part_file=$(printf "part-%02d.typ" "$part_idx")
  printf "PART\t%s\t%s\n" "$part_title" "$part_file" >> "$tmp_entries"
done < <(grep -E '^[[:space:]]*-[[:space:]]*part:[[:space:]]*"' "$QUARTO_CONFIG" || true)

while IFS= read -r line; do
  qmd_path=$(printf "%s" "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*"?([^#"]+\.qmd)"?[[:space:]]*$/\1/')
  [[ -z "$qmd_path" ]] && continue
  [[ ! -f "$ROOT_DIR/$qmd_path" ]] && continue

  heading=$(awk '
    /^#[[:space:]]+/ {
      line=$0
      sub(/^#[[:space:]]+/, "", line)
      sub(/[[:space:]]+\{[^}]+\}[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$ROOT_DIR/$qmd_path")

  [[ -z "$heading" ]] && continue

  qmd_file="${qmd_path%.qmd}.typ"
  printf "QMD\t%s\t%s\t%s\n" "$qmd_path" "$heading" "$qmd_file" >> "$tmp_entries"
done < <(grep -E '^[[:space:]]*-[[:space:]]*"?[^#"]+\.qmd"?[[:space:]]*$' "$QUARTO_CONFIG" || true)

echo "[4/6] Locate content blocks in index.typ"

while IFS=$'\t' read -r kind a b c; do
  case "$kind" in
    PART)
      title="$a"
      out_file="$b"
      line_no=$(grep -nF "#part[$title]" "$INDEX_TYP" | head -1 | cut -d: -f1 || true)
      [[ -n "$line_no" ]] && printf "%s\t%s\t%s\n" "$line_no" "$kind" "$out_file" >> "$tmp_starts"
      ;;
    QMD)
      qmd_path="$a"
      heading="$b"
      out_file="$c"
      if [[ "$qmd_path" == "index.qmd" ]]; then
        pat="#heading(level: 1, numbering: none)[$heading]"
      else
        pat="= $heading"
      fi
      line_no=$(grep -nF "$pat" "$INDEX_TYP" | head -1 | cut -d: -f1 || true)
      [[ -n "$line_no" ]] && printf "%s\t%s\t%s\n" "$line_no" "$kind" "$out_file" >> "$tmp_starts"
      ;;
  esac
done < "$tmp_entries"

appendix_line=$(grep -nF "#_bookly-in-appendix.update(true)" "$INDEX_TYP" | head -1 | cut -d: -f1 || true)
if [[ -n "$appendix_line" ]]; then
  printf "%s\tAPPENDIX\t_appendix-start.typ\n" "$appendix_line" >> "$tmp_starts"
fi

if [[ ! -s "$tmp_starts" ]]; then
  echo "Error: no blocks could be located in index.typ." >&2
  exit 1
fi

sort -n "$tmp_starts" -o "$tmp_starts"

first_line=$(awk 'NR==1 { print $1 }' "$tmp_starts")
last_line_total=$(wc -l < "$INDEX_TYP")

sed -n "1,$((first_line - 1))p" "$INDEX_TYP" > "$BOOK_DIR/_preamble.typ"

reorder_imports_top() {
  local file="$1"
  local tmp="$file.tmp"
  awk '
    /^[[:space:]]*#import[[:space:]]/ {
      imports[++ni] = $0
      next
    }
    {
      body[++nb] = $0
    }
    END {
      for (i = 1; i <= ni; i++) print imports[i]
      if (ni > 0 && nb > 0) print ""
      for (i = 1; i <= nb; i++) print body[i]
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

reorder_imports_top "$BOOK_DIR/_preamble.typ"

write_slice() {
  local start_line="$1"
  local end_line="$2"
  local rel_file="$3"
  local out_file="$BOOK_DIR/$rel_file"

  mkdir -p "$(dirname "$out_file")"
  sed -n "${start_line},${end_line}p" "$INDEX_TYP" > "$out_file"
}

prev_line=""
prev_file=""
while IFS=$'\t' read -r start_line _kind out_file; do
  if [[ -n "$prev_line" ]]; then
    end_line=$((start_line - 1))
    write_slice "$prev_line" "$end_line" "$prev_file"
  fi
  prev_line="$start_line"
  prev_file="$out_file"
done < "$tmp_starts"

if [[ -n "$prev_line" && -n "$prev_file" ]]; then
  write_slice "$prev_line" "$last_line_total" "$prev_file"
fi

# Each included fragment is evaluated in its own module scope.
# Inject a lightweight shim so fragments can see preamble definitions
# (e.g., equation-numbering, NormalTok, callout helpers, fontawesome symbols).
while IFS= read -r frag; do
  base="$(basename "$frag")"
  if [[ "$base" == "_preamble.typ" ]]; then
    continue
  fi

  rel_path="${frag#$BOOK_DIR/}"
  rel_dir="$(dirname "$rel_path")"
  if [[ "$rel_dir" == "." ]]; then
    preamble_import="_preamble.typ"
  else
    up_path=""
    IFS='/' read -r -a parts <<< "$rel_dir"
    for _ in "${parts[@]}"; do
      up_path+="../"
    done
    preamble_import="${up_path}_preamble.typ"
  fi

  tmpf="$frag.tmp"
  {
    echo "#import \"$preamble_import\": *"
    echo ""
    cat "$frag"
  } > "$tmpf"
  mv "$tmpf" "$frag"
done < <(find "$BOOK_DIR" -type f -name '*.typ' | sort)

# Mirror Quarto resource folders (e.g., index_files/) so relative asset paths
# from split fragments remain valid when compiling from _split_typ/book/.
for res_dir in "$ROOT_DIR"/*_files; do
  [[ -d "$res_dir" ]] || continue
  res_base="$(basename "$res_dir")"

  # Root-level fragments expect resources at book/<name>_files/
  cp -R "$res_dir" "$BOOK_DIR/"

  # Nested fragments (e.g., chapters/intro.typ) resolve relative paths from
  # their own directory, so mirror resources there as well.
  while IFS= read -r frag_dir; do
    [[ "$frag_dir" == "$BOOK_DIR" ]] && continue
    mkdir -p "$frag_dir"
    rm -rf "$frag_dir/$res_base"
    cp -R "$res_dir" "$frag_dir/"
  done < <(find "$BOOK_DIR" -type f -name '*.typ' -exec dirname {} \; | sort -u)
done

echo "[5/6] Generate index-split.typ master with includes"
cat "$BOOK_DIR/_preamble.typ" > "$MASTER_TYP"
{
  echo ""
  echo "// Auto-generated include chain by scripts/build-split-typ.sh"
  awk -F '\t' '{ print "#include \"book/" $3 "\"" }' "$tmp_starts"
} >> "$MASTER_TYP"

echo "[6/6] Compile split master with Typst"
rm -f "$MASTER_PDF"
quarto typst compile "$MASTER_TYP" "$MASTER_PDF" >/dev/null
echo "Compilation index-split.pdf: OK"

echo "Workflow completed."
echo "- Master Typ: $MASTER_TYP"
echo "- Master PDF: $MASTER_PDF"
echo "- Fragments: $BOOK_DIR"
