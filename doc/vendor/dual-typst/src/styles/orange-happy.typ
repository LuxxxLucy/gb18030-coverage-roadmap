// orange-happy: warm Claude-like editorial UI. Public Sans carries the
// reading texture; Newsreader is reserved for the title so the page stays
// friendly rather than antique.

#import "../config.typ": merge-config
#import "_stacks.typ" as stacks
#import "_html_overlay.typ": html-overlay
#import "tufte-original.typ": tufte-original

#let _bg = "#F7F2EA"
#let _fg = "#2F2A24"
#let _link = "#A85428"
#let _heading = "#2A2018"
#let _note = "#6D6257"

#let orange-happy = merge-config(tufte-original, (
    page: (fill: rgb(_bg)),
    sizes: (body: 9.8pt, small: 0.78em),
    fonts: (
        body:   stacks.source-serif,
        sans:   stacks.public-sans,
        mono:   stacks.jetbrains-mono,
        header: stacks.newsreader,
    ),
    headings: (
        h1: (weight: "regular", size: 1.08em, style: "normal", v-before: 0.7em, v-after: 0.2em),
        h2: (weight: "regular", size: 1em, style: "normal", v-before: 0.45em, v-after: 0.15em),
        h3: (weight: "regular", style: "normal"),
    ),
    margin-note: (size: 0.76em, font: stacks.public-sans, style: "normal", leading: 0.42em),
    title-block: (font: stacks.newsreader, weight: "medium", size: 1.34em, meta-style: "normal", meta-size: 0.78em, v-after: 1.0em),
    text: (fill: rgb(_fg), leading: 0.42em),
    quote: (size: 0.9em, leading: 0.42em, inset: (left: 1.45em, right: 0.9em, top: 0.75em, bottom: 0.58em)),
    link: (fill: rgb(_link), underline: true),
    raw-block: (size: 0.82em, leading: 0.22em, inset: (left: 1.3em, right: 0.75em, top: 0.36em, bottom: 0.36em)),
    "html-color-scheme": "light",
    "html-vendor-css-only": false,
    css: ("https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",),
    "html-extra-css": html-overlay(
        import-css: "@import url('https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=Public+Sans:ital,wght@0,400;0,500;0,600;1,400&family=JetBrains+Mono:wght@400;500&family=Source+Serif+4:ital,wght@0,400;0,500;1,400&display=swap');",
        body-font: "'Source Serif 4', Georgia, serif",
        heading-font: "'Newsreader', Georgia, serif",
        mono-font: "'JetBrains Mono', ui-monospace, monospace",
        bg: _bg, fg: _fg, link: _link, heading-color: _heading, note-color: _note,
        link-underline: true,
        body-size: "1rem", body-line-height: "1.6",
        quote-size: "1.08rem", quote-line-height: "1.6rem",
        extra: " body { font-optical-sizing: auto; }"
            + " article > h1 { font-size: 2.25rem; line-height: 1.08; margin-top: 3.1rem; margin-bottom: 0.3rem; }"
            + " article p.subtitle { font-family: 'Public Sans', system-ui, sans-serif; font-size: 0.92rem; line-height: 1.3; font-style: normal; margin-top: 0.25rem; }"
            + " article section > h1, article h2, article h3 { font-family: 'Public Sans', system-ui, sans-serif; } .sidenote, .marginnote, figcaption { font-family: 'Public Sans', system-ui, sans-serif; }"
            + " article section > h1 { font-size: 1.45rem; line-height: 1.25; margin-top: 2.15rem; margin-bottom: 0.45rem; }"
            + " article .epigraph + h1 { margin-top: 1.95rem; }"
            + " article blockquote, article blockquote p { color: #625447; font-style: italic; border-left: none; }"
            + " article blockquote { padding-left: 1em; padding-right: 1em; }"
            + " hr { border: none; border-top: 1px solid #d9cdb8; width: 36%; margin: 1.8em auto; }",
    ),
))
