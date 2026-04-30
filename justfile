set shell := ["bash", "-cu"]

split:
    ./scripts/build-split-typ.sh

compile-typst:
    test -f _split_typ/index-split.typ || (echo "_split_typ/index-split.typ not found. Run: just split" && exit 1)
    quarto typst compile _split_typ/index-split.typ _split_typ/index-split.pdf
    mkdir -p _book
    rm -f _book/*.pdf
    mv -f _split_typ/index-split.pdf _book/index-split.pdf
    echo "Split PDF moved to _book/index-split.pdf"
