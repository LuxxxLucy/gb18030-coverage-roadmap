// terpret: plain, nerdy technical style. Inter body + Space Grotesk
// headings + JetBrains Mono, with a near-white page and restrained blue.

#import "../config.typ": merge-config
#import "_stacks.typ" as stacks
#import "_html_overlay.typ": html-overlay
#import "tufte-original.typ": tufte-original

#let _bg = "#FAFAF8"
#let _fg = "#1B1B1F"
#let _link = "#1F6FEB"
#let _heading = "#182338"
#let _note = "#4A4A52"

#let terpret = merge-config(tufte-original, (
    page: (fill: rgb(_bg)),
    sizes: (body: 9.4pt, small: 0.78em),
    fonts: (
        body:   stacks.inter,
        sans:   stacks.inter,
        mono:   stacks.jetbrains-mono,
        header: stacks.space-grotesk,
    ),
    headings: (
        h1: (weight: "medium", size: 1.12em, style: "normal", v-before: 0.7em, v-after: 0.2em),
        h2: (weight: "medium", size: 1em, style: "normal", v-before: 0.45em, v-after: 0.15em),
        h3: (weight: "medium", style: "normal"),
    ),
    margin-note: (size: 0.76em, font: stacks.inter, style: "normal", leading: 0.42em),
    title-block: (font: stacks.space-grotesk, weight: "medium", size: 1.24em, meta-style: "normal", meta-size: 0.76em, v-after: 1.0em),
    text: (fill: rgb(_fg), leading: 0.42em),
    quote: (size: 0.88em, leading: 0.4em, inset: (left: 1.35em, right: 0.9em, top: 0.72em, bottom: 0.58em)),
    link: (fill: rgb(_link), underline: true),
    raw-block: (size: 0.84em, leading: 0.22em, inset: (left: 1.25em, right: 0.7em, top: 0.36em, bottom: 0.36em)),
    "html-color-scheme": "light",
    "html-vendor-css-only": false,
    css: ("https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",),
    "html-extra-css": html-overlay(
        import-css: "@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500&family=Space+Grotesk:wght@500;700&family=JetBrains+Mono:wght@400;700&display=swap');",
        body-font: "'Inter', system-ui, sans-serif",
        heading-font: "'Space Grotesk', 'Inter', system-ui, sans-serif",
        mono-font: "'JetBrains Mono', ui-monospace, monospace",
        bg: _bg, fg: _fg, link: _link, heading-color: _heading, note-color: _note,
        link-underline: true,
        body-size: "1rem", body-line-height: "1.55",
        quote-size: "1.05rem", quote-line-height: "1.55rem",
        extra: " article > h1 { font-size: 2rem; line-height: 1.12; margin-top: 3.2rem; margin-bottom: 0.35rem; }"
            + " article p.subtitle { font-size: 0.92rem; line-height: 1.3; font-style: normal; margin-top: 0.25rem; }"
            + " article section > h1 { font-size: 1.48rem; line-height: 1.25; margin-top: 2.2rem; margin-bottom: 0.45rem; }"
            + " article .epigraph + h1 { margin-top: 2rem; }"
            + " article h2 { font-size: 1.15rem; line-height: 1.35; margin-top: 1.9rem; border-bottom: 1px solid #E1DED4; padding-bottom: 0.18em; }"
            + " code:not(pre code) { background: #F1F0E8; padding: 0.08em 0.28em; border-radius: 3px; font-size: 0.9em; }",
    ),
))
