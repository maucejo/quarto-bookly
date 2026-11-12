#import "@preview/bookly:5.3.0": *

#show: bookly.with(
$if(title)$
  title: [$title$],
$endif$
$if(by-author)$
  author: "$for(by-author)$$it.name.literal$$sep$, $endfor$",
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
  theme: $if(theme)$$theme$$else$$if(bookly-theme)$$bookly-theme$$else$modern$endif$$endif$,
  tufte: $if(tufte)$$tufte$$else$$if(bookly-tufte)$$bookly-tufte$$else$false$endif$$endif$,
$if(colors)$
  colors: (
$if(colors.primary)$
    primary: $colors.primary$,
$endif$
$if(colors.secondary)$
    secondary: $colors.secondary$,
$endif$
  ),
$else$
$if(bookly-colors)$
  colors: (
$if(bookly-colors.primary)$
    primary: $bookly-colors.primary$,
$endif$
$if(bookly-colors.secondary)$
    secondary: $bookly-colors.secondary$,
$endif$
  ),
$endif$
$endif$
$if(fonts)$
  fonts: (
$if(fonts.body)$
    body: "$fonts.body$",
$endif$
$if(fonts.math)$
    math: "$fonts.math$",
$endif$
$if(fonts.raw)$
    raw: "$fonts.raw$",
$endif$
  ),
$else$
$if(bookly-fonts)$
  fonts: (
$if(bookly-fonts.body)$
    body: "$bookly-fonts.body$",
$endif$
$if(bookly-fonts.math)$
    math: "$bookly-fonts.math$",
$endif$
$if(bookly-fonts.raw)$
    raw: "$bookly-fonts.raw$",
$endif$
  ),
$endif$
$endif$
$if(title-page)$
$if(title-page.thesis)$
  title-page: thesis-title-page(
$if(title-page.type)$
    type: "$title-page.type$",
$endif$
$if(title-page.school)$
    school: [$title-page.school$],
$endif$
$if(title-page.doctoral-school)$
    doctoral-school: [$title-page.doctoral-school$],
$endif$
$if(title-page.supervisor)$
    supervisor: ($for(title-page.supervisor)$[$it$],$endfor$),
$endif$
$if(title-page.cosupervisor)$
    cosupervisor: ($for(title-page.cosupervisor)$[$it$],$endfor$),
$endif$
$if(title-page.laboratory)$
    laboratory: [$title-page.laboratory$],
$endif$
$if(title-page.defense-date)$
    defense-date: [$title-page.defense-date$],
$endif$
$if(title-page.discipline)$
    discipline: [$title-page.discipline$],
$endif$
$if(title-page.specialty)$
    specialty: [$title-page.specialty$],
$endif$
$if(title-page.committee)$
    committee: (
$for(title-page.committee)$
      ([$it.name$], [$it.position$], [$it.affiliation$], [$it.role$]),
$endfor$
    ),
$endif$
$if(title-page.logo)$
    logo: image("$title-page.logo$"),
$endif$
  ),
$else$
  title-page: book-title-page(
$if(title-page.subtitle)$
    subtitle: [$title-page.subtitle$],
$endif$
$if(title-page.edition)$
    edition: [$title-page.edition$],
$endif$
$if(title-page.institution)$
    institution: [$title-page.institution$],
$endif$
$if(title-page.series)$
    series: [$title-page.series$],
$endif$
$if(title-page.year)$
    year: [$title-page.year$],
$endif$
$if(title-page.cover)$
    cover: image("$title-page.cover$"),
$endif$
$if(title-page.logo)$
    logo: image("$title-page.logo$"),
$endif$
$if(title-page.version-usage)$
    version-usage: [$title-page.version-usage$],
$endif$
$if(title-page.copyright)$
    copyright: [$title-page.copyright$],
$endif$
$if(title-page.show-cover-author)$
    show-cover-author: $title-page.show-cover-author$,
$endif$
  ),
$endif$
$endif$
  config-options: (
$if(config-options)$
$for(config-options/pairs)$
    $config-options.key$: $config-options.value$,
$endfor$
$else$
$if(bookly-config-options)$
$for(bookly-config-options/pairs)$
    $bookly-config-options.key$: $bookly-config-options.value$,
$endfor$
$else$
    open-right: $if(open-right)$$open-right$$else$$if(bookly-open-right)$$bookly-open-right$$else$true$endif$$endif$,
    alt-margins: $if(alt-margins)$$alt-margins$$else$$if(bookly-alt-margins)$$bookly-alt-margins$$else$false$endif$$endif$,
$endif$
$endif$
$if(part-numbering)$
    part-numbering: "$part-numbering$",
$else$
$if(bookly-part-numbering)$
    part-numbering: "$bookly-part-numbering$",
$endif$
$endif$
  )
)

// Start in main matter — the Lua filter handles parts and appendix transitions
#show: main-matter

// Redirect Quarto callouts to native bookly boxes.
// Quarto emits #callout(...) in Typst, so overriding this function provides
// a robust mapping to info-box / tip-box / warning-box / important-box / question-box.
#let callout(body: [], title: "Callout", ..args) = {
  let t = lower(content-to-string(title))
  if t.contains("note") {
    info-box(body)
  } else if t.contains("tip") {
    tip-box(body)
  } else if t.contains("warning") or t.contains("caution") {
    warning-box(body)
  } else if t.contains("important") {
    important-box(body)
  } else if t.contains("question") {
    question-box(body)
  } else {
    info-box(body)
  }
}

// Quarto uses custom figure kinds for crossref floats. Force chapter-based
// numbering and switch to appendix style (A.1) once appendix mode starts.
#let quarto-float-numbering = (..n) => {
  let h1 = counter(heading).get().first()
  if _bookly-in-appendix.get() {
    numbering("A.1", h1, ..n)
  } else {
    numbering("1.1", h1, ..n)
  }
}

// Images never exceed the text area: scale down (never up) when too large.
// Inside figures, images are often wrapped in an auto-sized box (e.g. Mermaid
// diagrams), so the fitting box spans the full width; inline images elsewhere
// (callout icons...) are left alone.
#let fit-image(it) = layout(size => {
  // Natural size (explicit absolute sizes are not clamped without a width).
  // Relative widths (e.g. 30%) resolve to 0 or infinity here: they already fit.
  let m = measure(it)
  if m.width <= 0pt or m.height <= 0pt or m.width > 1e5pt or m.height > 1e5pt { return it }
  let r = calc.min(1, size.width / m.width, size.height * 0.9 / m.height)
  if r < 1 { scale(r * 100%, reflow: true, it) } else { it }
})
#show figure: it => {
  show image: img => box(width: 100%, fit-image(img))
  it
}

#show figure.where(kind: "quarto-float-fig"): set figure(numbering: quarto-float-numbering)
#show figure.where(kind: "quarto-float-tbl"): set figure(numbering: quarto-float-numbering)

$if(toc)$
#outline(
  title: [$if(toc-title)$$toc-title$$else$Table of Contents$endif$],
  depth: 3,
)
$endif$

$if(lof)$
#outline(
  title: [$if(crossref.lof-title)$$crossref.lof-title$$else$$if(crossref-lof-title)$$crossref-lof-title$$else$List of Figures$endif$$endif$],
  target: figure.where(kind: "quarto-float-fig"),
)
$endif$

$if(lot)$
#outline(
  title: [$if(crossref.lot-title)$$crossref.lot-title$$else$$if(crossref-lot-title)$$crossref-lot-title$$else$List of Tables$endif$$endif$],
  target: figure.where(kind: "quarto-float-tbl"),
)
$endif$
