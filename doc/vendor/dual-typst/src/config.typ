// Default config (the jialin style baseline). Other styles override on top
// via `merge-config`; pass `style:` (registry name or record) and/or
// `config:` (per-call overrides) to `tufte()`.

#import "styles/_stacks.typ" as stacks

#let default-config = (
    page: (
        paper: "us-letter",
        margin-x: 0.68in,
        margin-y: 2cm,
    ),
    margin-col: (
        width: 2.25in,
        sep: 0.7in,
    ),
    fonts: (
        body: stacks.etbembo,
        sans: stacks.gillsans,
        mono: ("Monaco", "Courier New"),
        header: ("Berkeley Mono", "Menlo", "Monaco"),
    ),
    // Body size matches the bezierlogue handout (9pt). Smaller bodies
    // (8pt) read too tight at the meta + sidenote ratios below.
    sizes: (
        body: 9pt,
        small: 0.7em,
        normal: 1em,
    ),
    headings: (
        h1: (weight: "extralight", size: 1.2em, style: "italic", v-before: 0.35em, v-after: -0.3em, lead-kern: -0.1em),
        h2: (weight: "extralight", size: 1em,   style: "italic", v-before: 0.4em,  v-after: 0.1em,  lead-kern: 0em),
        h3: (weight: "extralight", size: 1em,   style: "italic", v-before: 0.4em,  v-after: 0.1em,  lead-kern: 0em),
    ),
    margin-note: (
        size: 0.65em,
        font: stacks.gillsans,
        style: "italic",
        leading: 0.5em,
        marker-sep: 0.4em,
    ),
    // Sidenote number glyph (anchor in main text + margin-side label).
    // Body-font superscript. Anchor is visually a tiny reference mark;
    // margin-side number reads as a label on the note and benefits from
    // being slightly larger so it's legible against the smaller margin
    // text. tufte-css uses 1rem for both (≈0.71em over 1.4rem body) but
    // print conventions usually scale the margin-side label up.
    sidenote-number: (
        anchor-size: 0.7em,
        margin-size: 0.85em,
    ),
    // new-thought: tufte-css applies font-variant: small-caps at 1.2em.
    // ETBook/Palatino on macOS don't ship smcp glyphs that Typst can find,
    // so the small-caps feature silently no-ops and the result is just
    // larger uppercase. Render at body size with `upper()` + slight
    // tracking, which reads cleanly across all our fallback fonts.
    newthought: (
        size: 1em,
        tracking: 0.08em,
        lowercase-scale: 0.78,
    ),
    header: (
        size: 5pt,
        weight: "bold",
        tracking: 1.25pt,
        upper: true,
        v-after: 2.5em,
    ),
    // Title set in Gill Sans (matches the bezierlogue handout). Author /
    // email / date metadata at 0.85em (~7.7pt over 9pt body) reads as a
    // proper byline rather than fine print.
    title-block: (
        size: 1.8em,
        weight: "regular",
        font: stacks.gillsans,
        meta-size: 0.85em,
        meta-style: "normal",
        meta-sep: 1.2em,
        v-between: 0.3em,
        lead-kern: -0.1em,
        v-after: 2em,
    ),
    text: (
        fill: luma(20%),
        first-line-indent: 0em,
        par-spacing: auto,
        justify: true,
    ),
    // Block-quote inset + size. ETBembo italic at 1.25em reads right;
    // sans body fonts (Inter, etc.) look too heavy at the same multiplier
    // and styles using them override `size` to ~1em.
    quote: (
        size: 1.25em,
        leading: 0.6em,
        inset: (left: 2em, right: 1em, top: 2em, bottom: 2em),
    ),
    link: (fill: blue, underline: true),
    abstract: (v-after: 1.5em),
    toc: (title: [Contents], depth: 2, v-after: 1.5em),
    list: (indent: 1em, body-indent: 1em),
    raw-block: (
        leading: 0.25em,
        inset: (left: 2em, right: 0.9em, top: 0.5em, bottom: 0.5em),
    ),
    figure-caption: (dy: 1em),
)

#let _is-dict(v) = type(v) == dictionary

#let merge-config(base, overrides) = {
    if overrides == none or overrides == auto { return base }
    let out = base
    for (k, v) in overrides {
        if k in out and _is-dict(out.at(k)) and _is-dict(v) {
            out.insert(k, merge-config(out.at(k), v))
        } else {
            out.insert(k, v)
        }
    }
    out
}
