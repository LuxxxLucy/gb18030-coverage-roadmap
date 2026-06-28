// Dual-format Tufte template. One .typ source compiles to PDF (marginalia
// handout) or HTML (tufte-css). All configuration in `config.typ`.
//
// Author: Jialin Lu <luxxxlucy@gmail.com>
// License: MIT
//
// References:
//   Tufte LaTeX:        https://github.com/Tufte-LaTeX/tufte-latex
//   Tufte CSS:          https://github.com/edwardtufte/tufte-css
//   marginalia (Typst): https://typst.app/universe/package/marginalia

#import "config.typ": default-config, merge-config
#import "styles/registry.typ" as styles
#import "pdf.typ"
#import "html.typ"

// Resolved once per compile so the dispatch helpers below need no `context`.
#let _IS-HTML = sys.inputs.at("target", default: "pdf") == "html"

#let sidenote(numbered: true, dy: auto, body) = {
    if _IS-HTML { html.sidenote-html(numbered, body) }
    else        { pdf.sidenote-pdf(numbered, dy, body) }
}

#let marginnote(dy: auto, body) = sidenote(numbered: false, dy: dy, body)

#let main-figure(content, caption: none) = {
    if _IS-HTML { html.main-figure-html(content, caption) }
    else        { pdf.main-figure-pdf(content, caption) }
}

#let margin-figure(content, caption: none, dy: auto) = {
    if _IS-HTML { html.margin-figure-html(content, caption) }
    else        { pdf.margin-figure-pdf(content, caption, dy) }
}

#let full-width-figure(content, caption: none) = {
    if _IS-HTML { html.full-width-figure-html(content, caption) }
    else        { pdf.full-width-figure-pdf(content, caption) }
}

#let epigraph(quote, author: none) = {
    if _IS-HTML { html.epigraph-html(quote, author) }
    else        { pdf.epigraph-pdf(quote, author) }
}

#let new-thought(body) = {
    if _IS-HTML { html.new-thought-html(body) }
    else        { pdf.new-thought-pdf(body) }
}

#let full-width(body) = {
    if _IS-HTML { html.full-width-html(body) }
    else        { pdf.full-width-pdf(body) }
}

#let sidecite(key, dy: auto) = {
    if _IS-HTML { html.sidecite-html(key) }
    else        { pdf.sidecite-pdf(key, dy) }
}

#let sans(body) = {
    if _IS-HTML { html.sans-html(body) }
    else        { pdf.sans-pdf(body) }
}

// Wrap CeTZ / arbitrary drawable content so HTML output gets inline SVG.
// HTML target drops raw frames; `html.frame` lays the body out and embeds
// the SVG. PDF target needs no wrapper. Use: `#diagram(cetz.canvas(...))`.
#let diagram(body) = {
    if _IS-HTML { html.frame(body) }
    else        { body }
}

// `style` selects a record from `src/styles/registry.typ` (string name) or
// uses a passed record literal directly. `config` further overrides on top
// of the resolved style. Merge order: default-config → style → config.
#let tufte(
    title: none,
    author: none,
    email: none,
    date: none,
    abstract: none,
    lang: "en",
    toc: false,
    bib: none,
    html-css: auto,
    style: "tufte-original",
    config: auto,
    head-extra: none,
    body,
) = {
    set text(lang: lang)
    let style-rec = if type(style) == str { styles.resolve(style) } else { style }
    let cfg = merge-config(default-config, style-rec)
    cfg = merge-config(cfg, if config == auto { (:) } else { config })
    // Per-style CSS for HTML target; overridden by explicit html-css= arg.
    let css = if html-css != auto { html-css }
              else if "css" in cfg and cfg.css != auto { cfg.css }
              else { auto }

    let body-with-bib = {
        body
        if bib != none { bib }
    }

    if _IS-HTML {
        html.setup-html(cfg, title, author, email, date, abstract, toc, lang, css, head-extra, body-with-bib)
    } else {
        pdf.setup-pdf(cfg, title, author, email, date, abstract, toc, body-with-bib)
    }
}
