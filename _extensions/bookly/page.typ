// Page geometry — bookly applies its own page settings per section
// (front-matter, main-matter, appendix), so we only set the paper size here
#set page(
  paper: $if(papersize)$"$papersize$"$else$"a4"$endif$,
$if(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$),
$endif$
  columns: $if(columns)$$columns$$else$1$endif$,
)
