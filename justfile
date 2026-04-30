set shell := ["bash", "-cu"]

split:
    ./scripts/build-split-typ.sh

compile-typst output_name="index-split.pdf":
    test -f _split_typ/index-split.typ || (echo "_split_typ/index-split.typ not found. Run: just split" && exit 1)
    out="{{output_name}}"; [[ "$out" == *.pdf ]] || out="$out.pdf"; \
    mkdir -p _book; \
    rm -f _book/*.pdf; \
    typst compile _split_typ/index-split.typ "_split_typ/$out"; \
    mv -f "_split_typ/$out" "_book/$out"; \
    echo "Split PDF moved to _book/$out"

compile output_name="index-split.pdf":
    test -f _split_typ/index-split.typ || (echo "_split_typ/index-split.typ not found. Run: just split" && exit 1)
    out="{{output_name}}"; [[ "$out" == *.pdf ]] || out="$out.pdf"; \
    mkdir -p _book; \
    rm -f _book/*.pdf; \
    quarto typst compile _split_typ/index-split.typ "_split_typ/$out"; \
    mv -f "_split_typ/$out" "_book/$out"; \
    echo "Split PDF moved to _book/$out"
