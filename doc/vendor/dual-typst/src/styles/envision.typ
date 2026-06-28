// envision: rstudio/tufte's "envisioned" overlay (rstudio.github.io/tufte/envisioned/).
// Roboto Condensed body on warm #fefefe page. Inherits tufte-original sizes
// and headings; only fonts and colours differ.

#import "../config.typ": merge-config
#import "_stacks.typ" as stacks
#import "_html_overlay.typ": link-rules
#import "tufte-original.typ": tufte-original

#let envision = merge-config(tufte-original, (
    // envisioned.css ships no dark-mode rules; force light so dark-OS
    // browsers don't recolor surrounding chrome over a light page.
    "html-color-scheme": "light",
    page: (fill: rgb("#fefefe")),
    fonts: (
        body:   stacks.roboto-condensed,
        sans:   stacks.roboto-condensed,
        mono:   ("Roboto Mono", "Menlo", "Monaco", "Courier New"),
        header: stacks.roboto-condensed,
    ),
    margin-note: (
        font: stacks.roboto-condensed,
        style: "normal",
    ),
    sizes: (body: 9.6pt, small: 0.78em),
    title-block: (font: stacks.roboto-condensed, size: 1.32em, meta-size: 0.8em, meta-style: "normal", v-after: 1.0em),
    text: (fill: rgb("#2B2B2B"), leading: 0.44em),
    quote: (size: 0.95em, leading: 0.44em, inset: (left: 1.7em, right: 1em, top: 0.9em, bottom: 0.75em)),
    link: (fill: rgb("#222222")),
    raw-block: (size: 0.82em, leading: 0.22em, inset: (left: 1.6em, right: 0.8em, top: 0.42em, bottom: 0.42em)),
    "html-vendor-css-only": true,
    // tufte-css underlines links with a background-gradient trick calibrated
    // for et-book; under Roboto Condensed it renders as a strikethrough.
    // Replace it with a plain font-aware underline (same shared rule the
    // overlay styles use). Emitted after the vendored CSS, so it wins.
    "html-extra-css": link-rules(link: "#222222", link-underline: true),
    css: (
        "https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",
        "https://cdn.jsdelivr.net/gh/rstudio/tufte@main/inst/rmarkdown/templates/tufte_html/resources/envisioned.css",
    )
))
