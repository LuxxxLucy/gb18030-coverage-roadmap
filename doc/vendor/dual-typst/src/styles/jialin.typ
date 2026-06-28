// jialin: personal handout layered on `tufte-original`. The PDF is
// intentionally compact and smaller than the HTML; the HTML stays more
// open for screen reading while preserving the same personal voice.

#import "../config.typ": merge-config
#import "_stacks.typ" as stacks
#import "_html_overlay.typ": html-overlay
#import "tufte-original.typ": tufte-original

#let _bg = "#FFFFFB"
#let _fg = "#242424"
#let _link = "#2557C7"
#let _note = "#5B6370"

#let jialin = merge-config(tufte-original, (
    page: (
        margin-x: 0.68in,
        margin-y: 2cm,
        fill: rgb(_bg),
    ),
    margin-col: (
        width: 2.25in,
        sep: 0.7in,
    ),
    sizes: (body: 9pt),
    headings: (
        h1: (weight: "regular", size: 1.15em, style: "italic", v-before: 0.45em, v-after: 0.05em, lead-kern: -0.05em),
        h2: (weight: "regular", size: 1em, style: "italic", v-before: 0.35em, v-after: 0.1em, lead-kern: 0em),
        h3: (weight: "regular", size: 1em, style: "italic", v-before: 0.35em, v-after: 0.1em, lead-kern: 0em),
    ),
    margin-note: (
        size: 0.68em,
        font: stacks.gillsans,
        style: "italic",
        leading: 0.48em,
        marker-sep: 0.35em,
    ),
    fonts: (
        sans: stacks.gillsans,
        mono: ("Berkeley Mono", "Menlo", "Monaco", "Courier"),
        header: ("Berkeley Mono", "Menlo", "Monaco"),
    ),
    header: (
        size: 5pt,
        weight: "bold",
        tracking: 1.25pt,
        upper: true,
        v-after: 2.35em,
    ),
    title-block: (
        size: 1.65em,
        font: stacks.gillsans,
        meta-size: 0.8em,
        meta-style: "normal",
        meta-sep: 1.1em,
        v-after: 1.35em,
    ),
    text: (
        fill: rgb(_fg),
        first-line-indent: 0em,
        par-spacing: auto,
        leading: auto,
        justify: true,
    ),
    quote: (size: 1em, leading: 0.48em, inset: (left: 1.5em, right: 1em, top: 0.9em, bottom: 0.7em)),
    raw-block: (
        leading: 0.26em,
        inset: (left: 1.25em, right: 0.7em, top: 0.38em, bottom: 0.38em),
    ),
    link: (fill: rgb(_link), underline: true),
    "html-color-scheme": "light",
    "html-vendor-css-only": false,
    css: ("https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",),
    "html-extra-css": html-overlay(
        import-css: "",
        body-font: "et-book, Palatino, Georgia, serif",
        heading-font: "Gill Sans, Avenir Next, system-ui, sans-serif",
        mono-font: "Berkeley Mono, Menlo, Monaco, ui-monospace, monospace",
        bg: _bg, fg: _fg, link: _link, heading-color: _fg, note-color: _note,
        link-underline: true,
        body-size: "1.08rem", body-line-height: "1.58",
        quote-size: "1.12rem", quote-line-height: "1.65rem",
        extra: " article > h1 { font-size: 2.15rem; line-height: 1.12; margin-top: 3rem; margin-bottom: 0.35rem; letter-spacing: 0; }"
            + " article p.subtitle { font-size: 0.94rem; line-height: 1.3; font-style: normal; margin-top: 0.25rem; color: #505866; }"
            + " article section > h1 { font-size: 1.5rem; line-height: 1.25; margin-top: 2rem; margin-bottom: 0.45rem; font-style: italic; letter-spacing: 0; }"
            + " article .epigraph + h1 { margin-top: 1.9rem; }"
            + " article h2 { font-size: 1.16rem; line-height: 1.35; margin-top: 1.7rem; font-style: italic; }"
            + " .sidenote, .marginnote, figcaption { font-size: 1rem; line-height: 1.45; }",
    ),
))
