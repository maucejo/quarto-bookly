// Chapter-based numbering for bookly
// Appendix state — updated by the Lua filter when the first appendix starts
#let _bookly-in-appendix = state("_bookly-in-appendix", false)

// Equation numbering: (1.1a) in main matter, (A.1a) in appendix
#let equation-numbering = (..n) => {
  let h1 = counter(heading).get().first()
  if _bookly-in-appendix.get() {
    numbering("(A.1a)", h1, ..n)
  } else {
    numbering("(1.1a)", h1, ..n)
  }
}

// Callout numbering: 1.1 in main matter, A.1 in appendix
#let callout-numbering = it => {
  let h1 = counter(heading).get().first()
  if _bookly-in-appendix.get() {
    numbering("A.1", h1, it)
  } else {
    numbering("1.1", h1, it)
  }
}

// Subfigure numbering: 1.1a in main matter, A.1a in appendix
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  if _bookly-in-appendix.get() {
    numbering("A.1a", chapter, n-super, subfloat-idx)
  } else {
    numbering("1.1a", chapter, n-super, subfloat-idx)
  }
}

// Theorem configuration for theorion (Quarto's default theorem package)
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if _bookly-in-appendix.at(loc) { "A.1" } else { "1.1" }
}

// Theorem render function — matches bookly's box style
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
