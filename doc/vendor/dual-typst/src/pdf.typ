// PDF target. Handout style on top of the marginalia package.

#import "@preview/marginalia:0.3.1" as marginalia: note, notefigure, wideblock
#import "config.typ": default-config

#let _config-state = state("dual-tufte-config", default-config)
#let _cfg() = _config-state.get()

// Gate the `show figure: ...` rule. notefigure builds its own figure
// and renders its own caption; without this flag the show rule stomps
// the inner caption.
#let _in-margin-figure = state("in-margin-figure", false)

#let _dy(dy) = if dy == auto { 0pt } else { dy }

#let _margin-text-style(cfg) = (
    size: cfg.margin-note.size,
    font: cfg.margin-note.font,
    style: cfg.margin-note.style,
)
#let _margin-par-style(cfg) = (leading: cfg.margin-note.leading)

// Tufte-LaTeX `\@tufte@caption@font = \@tufte@marginfont`: caption
// inherits margin-note typography.
#let _caption-style(cfg) = (
    size: cfg.sizes.small,
    font: cfg.margin-note.font,
    style: cfg.margin-note.style,
)

// Body-font superscript glyph for sidenote numbers. Sized independently
// for the in-text anchor and the margin-side label.
#let _sn-num(size, font, i) = super(
    typographic: false,
    baseline: -0.5em,
    size: size,
    text(font: font, numbering("1", ..i)),
)
#let _sn-margin-mark(cfg) = (..i) => [#_sn-num(cfg.sidenote-number.margin-size, cfg.fonts.body, i.pos())#h(cfg.margin-note.marker-sep)]
#let _sn-anchor-mark(cfg) = (..i) => _sn-num(cfg.sidenote-number.anchor-size, cfg.fonts.body, i.pos())

#let sidenote-pdf(numbered, dy, body) = context {
    let cfg = _cfg()
    let kw = if numbered {
        (numbering: _sn-margin-mark(cfg), anchor-numbering: _sn-anchor-mark(cfg))
    } else {
        (counter: none,)
    }
    note(
        dy: _dy(dy),
        text-style: _margin-text-style(cfg),
        par-style: _margin-par-style(cfg),
        ..kw,
    )[#body]
}

#let main-figure-pdf(content, caption) = figure(content, caption: caption)

#let margin-figure-pdf(content, caption, dy) = context {
    _in-margin-figure.update(true)
    notefigure(
        content,
        caption: caption,
        dy: _dy(dy),
        counter: none,
        text-style: _caption-style(_cfg()),
    )
    _in-margin-figure.update(false)
}

// Caption hoisted into the right margin via marginalia.note (mirrors
// tufte-css `.fullwidth figcaption` floating right with margin-right: 24%).
#let full-width-figure-pdf(content, caption) = context {
    let cfg = _cfg()
    wideblock(side: "outer", content)
    if caption != none {
        note(dy: 0pt, counter: none, text-style: _caption-style(cfg))[#caption]
    }
}

#let _quote-block(cfg, body, attribution) = block(
    inset: cfg.quote.inset,
    {
        set text(style: "italic", size: cfg.quote.size)
        set par(leading: cfg.quote.leading)
        body
        if attribution != none {
            linebreak()
            align(right)[#text(style: "normal", size: cfg.sizes.small, [— ] + attribution)]
        }
    },
)

#let epigraph-pdf(quote, author) = context {
    _quote-block(_cfg(), quote, author)
}

// Synthetic small-caps. Typst's `smallcaps()` no-ops on fonts without
// smcp glyphs (typst#7009, open). Uppercase the lowercase runs and
// shrink them so original capitals retain body size.
#let new-thought-pdf(body) = context {
    let nt = _cfg().newthought
    show regex("\p{Ll}+"): m => text(size: nt.lowercase-scale * 1em, upper(m.text))
    text(size: nt.size, tracking: nt.tracking, body)
}

#let full-width-pdf(body) = wideblock(side: "outer", body)

#let sidecite-pdf(key, dy) = context {
    let cfg = _cfg()
    note(
        dy: _dy(dy),
        numbering: _sn-margin-mark(cfg),
        anchor-numbering: _sn-anchor-mark(cfg),
        text-style: _margin-text-style(cfg),
        par-style: _margin-par-style(cfg),
    )[#cite(key, form: "full")]
}

#let sans-pdf(body) = context {
    set text(font: _cfg().fonts.sans)
    body
}

#let _render-header(title, cfg) = {
    if title == none { return }
    set text(
        size: cfg.header.size,
        weight: cfg.header.weight,
        tracking: cfg.header.tracking,
        font: cfg.fonts.header,
    )
    // Push the header to the page right edge. The text frame here ends at
    // the main-column right; the margin column + sep sits between it and
    // the page edge, so a negative right pad of (sep + width) lands the
    // right-aligned content flush with the page edge.
    let push = -(cfg.margin-col.width + cfg.margin-col.sep)
    pad(right: push, align(right, if cfg.header.upper { upper(title) } else { title }))
    v(cfg.header.v-after)
}

#let _render-title-block(title, author, email, date, cfg) = {
    if title == none { return }
    set par(first-line-indent: 0em)
    let title-text-args = (
        weight: cfg.title-block.weight,
        size: cfg.title-block.size,
    )
    if cfg.title-block.font != auto {
        title-text-args.insert("font", cfg.title-block.font)
    }
    let meta-style = cfg.title-block.meta-style
    // Italic metadata uses the body serif (matches tufte-css `.subtitle`);
    // upright metadata defaults to sans Gill Sans.
    let meta-font = if meta-style == "italic" { cfg.fonts.body } else { cfg.fonts.sans }
    let meta-args = (size: cfg.title-block.meta-size, font: meta-font, style: meta-style)
    block(width: 100%)[
        #h(cfg.title-block.lead-kern)
        #text(..title-text-args, title)
        #if author != none {
            v(cfg.title-block.v-between)
            text(..meta-args, author)
        }
        #if email != none {
            text(..meta-args)[#h(cfg.title-block.meta-sep)#email]
        }
        #if date != none {
            let d = if type(date) == datetime { date.display() } else { date }
            text(..meta-args)[#h(cfg.title-block.meta-sep)#d]
        }
        #v(cfg.title-block.v-after)
    ]
}

#let _render-abstract(abstract, cfg) = {
    if abstract == none { return }
    set par(first-line-indent: 0em)
    text(font: cfg.fonts.body, size: cfg.sizes.small, style: "italic", abstract)
    v(cfg.abstract.v-after)
}

#let _render-toc(toc, cfg) = {
    if toc != true { return }
    outline(title: cfg.toc.title, indent: auto, depth: cfg.toc.depth)
    v(cfg.toc.v-after)
}

// `lead-kern` pulls the italic h1 left so it doesn't visually creep
// right of the baseline.
#let _heading-rule(spec) = it => {
    set par(first-line-indent: 0em)
    text(weight: spec.weight, size: spec.size, style: spec.style, {
        v(spec.v-before)
        if spec.lead-kern != 0em { h(spec.lead-kern) }
        it.body
        v(spec.v-after)
    })
}

#let setup-pdf(config, title, author, email, date, abstract, toc, body) = {
    let cfg = config
    _config-state.update(cfg)

    let w = cfg.page.at("width", default: none)
    let h = cfg.page.at("height", default: none)
    let scroll = h == auto
    let page-args = (fill: cfg.page.at("fill", default: none))
    if w != none { page-args.insert("width", w) }
    if h != none { page-args.insert("height", h) }
    if w == none and h == none { page-args.insert("paper", cfg.page.paper) }
    // Suppress the running header in scroll mode; it would render once on
    // the single tall page.
    if title != none and not scroll {
        page-args.insert("header", _render-header(title, cfg))
    }
    set page(..page-args)

    show: marginalia.setup.with(
        inner: (far: cfg.page.margin-x, width: 0pt, sep: 0pt),
        outer: (far: cfg.page.margin-x, width: cfg.margin-col.width, sep: cfg.margin-col.sep),
        top: cfg.page.margin-y,
        bottom: cfg.page.margin-y,
        book: false,
    )

    // Hyphenation explicit so it survives a custom `lang:`. Typst has no
    // microtype-equivalent (typst#638), so hyphenation is the only
    // available adjustment against visible inter-word stretch in
    // justified columns.
    set text(
        font: cfg.fonts.body,
        size: cfg.sizes.body,
        fill: cfg.text.fill,
        hyphenate: true,
    )
    set par(
        first-line-indent: cfg.text.first-line-indent,
        justify: cfg.text.justify,
    )
    let leading = cfg.text.at("leading", default: auto)
    if leading != auto { set par(leading: leading) }
    if cfg.text.par-spacing != auto {
        set par(spacing: cfg.text.par-spacing)
    }
    set list(indent: cfg.list.indent, body-indent: cfg.list.body-indent)
    set enum(indent: cfg.list.indent, body-indent: cfg.list.body-indent)
    show enum: set par(justify: true)
    show list: set par(justify: true)
    // `show footnote` renders margin sidenotes; suppress Typst's
    // native bottom listing so the note is not duplicated.
    set footnote.entry(separator: [], clearance: 0pt, gap: 0pt)
    show footnote.entry: hide

    show link: it => {
        set text(fill: cfg.link.fill)
        if cfg.link.underline { underline(it) } else { it }
    }

    set math.equation(numbering: "(1)")
    set raw(theme: none)

    show raw.where(block: true): it => {
        let raw-size = cfg.raw-block.at("size", default: auto)
        if raw-size == auto { set text(font: cfg.fonts.mono) }
        else { set text(font: cfg.fonts.mono, size: raw-size) }
        set par(leading: cfg.raw-block.leading)
        block(inset: cfg.raw-block.inset, it)
    }
    show raw.where(block: false): it => {
        let raw-size = cfg.raw-block.at("inline-size", default: auto)
        if raw-size == auto { text(font: cfg.fonts.mono, it) }
        else { text(font: cfg.fonts.mono, size: raw-size, it) }
    }

    show quote.where(block: true): it => _quote-block(cfg, it.body, it.attribution)

    // Hoist figure caption into the margin (matches tufte-LaTeX
    // \@tufte@caption@font), aligned ~1em below the figure top so the
    // marginalia anchor lines up with the image. Skip when inside
    // marginalia.notefigure (margin-figure-pdf), which owns its caption.
    show figure: it => context {
        if _in-margin-figure.get() { return it }
        if it.caption != none {
            note(dy: cfg.figure-caption.dy, counter: none, text-style: _caption-style(cfg))[#it.caption]
        }
        it.body
    }

    show footnote: it => sidenote-pdf(true, auto, it.body)

    show heading.where(level: 1): _heading-rule(cfg.headings.h1)
    show heading.where(level: 2): _heading-rule(cfg.headings.h2)
    show heading.where(level: 3): _heading-rule(cfg.headings.h3)

    _render-title-block(title, author, email, date, cfg)
    _render-abstract(abstract, cfg)
    _render-toc(toc, cfg)
    body
}
