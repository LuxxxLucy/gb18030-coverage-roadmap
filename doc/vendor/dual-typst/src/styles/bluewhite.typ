// bluewhite: clean OpenAI/Sakana-like ML blog style. Public Sans in
// PDF and OpenAI Sans/Public Sans/system sans on the web, with restrained
// blue accents on a mostly white page.

#import "../config.typ": merge-config
#import "_stacks.typ" as stacks
#import "_html_overlay.typ": html-overlay
#import "tufte-original.typ": tufte-original

#let _bg = "#FFFFFF"
#let _fg = "#17191F"
#let _link = "#315E9F"
#let _heading = "#111318"
#let _note = "#687385"

#let bluewhite = merge-config(tufte-original, (
    page: (fill: rgb(_bg)),
    sizes: (body: 9.5pt, small: 0.78em),
    fonts: (
        body:   stacks.inter,
        sans:   stacks.inter,
        mono:   stacks.jetbrains-mono,
        header: stacks.inter,
    ),
    headings: (
        h1: (weight: "medium", size: 1.12em, style: "normal", v-before: 0.75em, v-after: 0.2em),
        h2: (weight: "medium", size: 1em, style: "normal", v-before: 0.45em, v-after: 0.15em),
        h3: (weight: "medium", style: "normal"),
    ),
    margin-note: (size: 0.76em, font: stacks.inter, style: "normal", leading: 0.42em),
    title-block: (font: stacks.inter, weight: "semibold", size: 1.36em, meta-style: "normal", meta-size: 0.76em, v-after: 1.0em),
    text: (fill: rgb(_fg), leading: 0.42em),
    quote: (size: 0.88em, leading: 0.42em, inset: (left: 1.45em, right: 0.9em, top: 0.75em, bottom: 0.58em)),
    link: (fill: rgb(_link), underline: false),
    raw-block: (size: 0.82em, leading: 0.22em, inset: (left: 1.3em, right: 0.75em, top: 0.36em, bottom: 0.36em)),
    "html-color-scheme": "light",
    "html-vendor-css-only": false,
    css: ("https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",),
    "html-extra-css": html-overlay(
        import-css: "@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap');",
        body-font: "Inter, 'OpenAI Sans', 'Public Sans', system-ui, sans-serif",
        heading-font: "Inter, 'OpenAI Sans', 'Public Sans', system-ui, sans-serif",
        mono-font: "'JetBrains Mono', ui-monospace, monospace",
        bg: _bg, fg: _fg, link: _link, heading-color: _heading, note-color: _note,
        link-underline: false,
        body-size: "1.02rem", body-line-height: "1.62",
        quote-size: "1.08rem", quote-line-height: "1.6rem",
        extra: " body { font-optical-sizing: auto; }"
            + " article > h1 { font-size: 2.18rem; line-height: 1.1; margin-top: 3.1rem; margin-bottom: 0.3rem; letter-spacing: 0; }"
            + " article p.subtitle { font-size: 0.9rem; line-height: 1.3; font-style: normal; margin-top: 0.25rem; color: #596273; }"
            + " article section > h1 { font-size: 1.5rem; line-height: 1.25; margin-top: 2.1rem; margin-bottom: 0.45rem; letter-spacing: 0; }"
            + " article .epigraph + h1 { margin-top: 1.95rem; }"
            + " article h2 { font-size: 1.15rem; line-height: 1.35; margin-top: 1.9rem; }"
            + " article blockquote, article blockquote p { color: " + _note + "; font-style: italic; }",
    ),
))
