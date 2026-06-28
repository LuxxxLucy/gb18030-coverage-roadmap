// HTML target. Emits canonical tufte-css markup.
// Reference: https://edwardtufte.github.io/tufte-css/ (1.8.0).

#let _CLS = (
    sidenote: "sidenote",
    marginnote: "marginnote",
    sidenote-num: "sidenote-number",
    margin-toggle: "margin-toggle",
    newthought: "newthought",
    fullwidth: "fullwidth",
    epigraph: "epigraph",
    sans: "sans",
    subtitle: "subtitle",
)

// Inner span style for newthought: explicit font-variant ensures small
// caps render even without the tufte stylesheet.
#let _NEWTHOUGHT_INNER = "font-variant-caps: small-caps"

// Single per-document counter for id uniqueness; per-kind numbering
// is not needed.
#let _id-counter = counter("dual-tufte-id")

#let _MN-GLYPH = "⊕"

// label+input wrapped in `box[...]` so Typst doesn't break the
// surrounding paragraph between the toggle and the trailing visible
// `<span>`. The span sits as a sibling outside the box.
#let _toggle(prefix, glyph: "", extra-class: "") = context {
    _id-counter.step()
    let id = prefix + str(_id-counter.get().first())
    let cls = if extra-class != "" { _CLS.margin-toggle + " " + extra-class }
              else { _CLS.margin-toggle }
    box[
        #html.elem("label", attrs: (("for"): id, ("class"): cls))[#glyph]
        #html.elem("input", attrs: (("type"): "checkbox", ("id"): id, ("class"): _CLS.margin-toggle))[]
    ]
}

#let _sidenote-triplet(body) = {
    _toggle("sn-", extra-class: _CLS.sidenote-num)
    html.elem("span", attrs: (("class"): _CLS.sidenote))[#body]
}

#let _marginnote-triplet(body) = {
    _toggle("mn-", glyph: _MN-GLYPH)
    html.elem("span", attrs: (("class"): _CLS.marginnote))[#body]
}

#let sidenote-html(numbered, body) = {
    if numbered { _sidenote-triplet(body) } else { _marginnote-triplet(body) }
}

#let main-figure-html(content, caption) = {
    html.elem("figure")[
        #if caption != none {
            _toggle("mn-fig-", glyph: _MN-GLYPH)
            html.elem("span", attrs: (("class"): _CLS.marginnote))[#caption]
        }
        #content
    ]
}

// Margin figure: image + caption live inside the marginnote span (not
// wrapped in <figure>), matching web-tufte-typst.
#let margin-figure-html(content, caption) = {
    _toggle("mn-fig-", glyph: _MN-GLYPH)
    html.elem("span", attrs: (("class"): _CLS.marginnote))[
        #box[#content]
        #if caption != none [ #caption]
    ]
}

#let full-width-figure-html(content, caption) = {
    html.elem("figure", attrs: (("class"): _CLS.fullwidth))[
        #content
        #if caption != none {
            html.elem("figcaption")[#caption]
        }
    ]
}

#let epigraph-html(quote, author) = {
    html.elem("div", attrs: (("class"): _CLS.epigraph))[
        #html.elem("blockquote")[
            #html.p(quote)
            #if author != none { html.elem("footer")[#author] }
        ]
    ]
}

#let new-thought-html(body) = {
    html.elem("span", attrs: (("class"): _CLS.newthought))[
        #html.elem("span", attrs: (("style"): _NEWTHOUGHT_INNER))[#body]
    ]
}

#let full-width-html(body) = html.elem("div", attrs: (("class"): _CLS.fullwidth))[#body]

#let sidecite-html(key) = _sidenote-triplet(cite(key, form: "full"))

#let sans-html(body) = html.elem("p", attrs: (("class"): _CLS.sans))[#body]

#let _format-meta-parts(author, email, date) = {
    let parts = ()
    if author != none { parts.push(author) }
    if email != none { parts.push(email) }
    if date != none {
        parts.push(if type(date) == datetime { date.display() } else { date })
    }
    parts
}

#let _render-title-block-html(title, author, email, date) = {
    if title != none { html.elem("h1")[#title] }
    let parts = _format-meta-parts(author, email, date)
    if parts.len() > 0 {
        html.elem("p", attrs: (("class"): _CLS.subtitle))[#parts.join(", ")]
    }
}

// CDN by default. For offline / pinned builds pass `html-css: "tufte.min.css"`.
#let _default-css = ("https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",)

// Inline overrides on top of tufte-css: subtitle margin, h1..h3 width
// (so heading-embedded sidenotes float into the right margin), full-width
// scoping for div.fullwidth + nested table, and h4/h5 styling that
// tufte-css doesn't cover.
#let _INLINE_STYLE = ".subtitle + p { margin-top: 2.5em; }
p + h2 { margin-top: 5.5rem; }
article h1, article h2, article h3 { max-width: 55%; }
div.fullwidth { font-size: 1.4rem; line-height: 2rem; }
div.fullwidth > table { width: 100%; }
h4 { font-style: italic; font-weight: 400; font-size: 1.4rem; line-height: 2rem; margin-top: 2rem; margin-bottom: 0; }
h5 { font-style: italic; font-weight: 400; font-size: 1.2rem; line-height: 2rem; margin-top: 2rem; margin-bottom: 0; }
pre code, pre code span { color: inherit !important; background: transparent !important; }
.typst-frame use { fill: currentColor; }"

#let _heading-slug(idx) = "h-" + str(idx + 1)

#let toc-html-block() = context {
    let hs = query(heading)
    if hs.len() == 0 { return }
    html.elem("nav", attrs: (("class"): "toc"))[
        #html.elem("h2")[Contents]
        #html.elem("ul", attrs: (("style"): "list-style: none; padding-left: 0;"))[
            #for (i, h) in hs.enumerate() {
                let indent = str((h.level - 1) * 1.2) + "rem"
                html.elem("li", attrs: (("style"): "margin-left: " + indent))[
                    #html.elem("a", attrs: (("href"): "#" + _heading-slug(i)))[#h.body]
                ]
            }
        ]
    ]
}

#let setup-html(cfg, title, author, email, date, abstract, toc, lang, css-urls, head-extra, body) = {
    let doc-title = if title != none { title } else { "Document" }
    let html-css = if css-urls == auto { _default-css }
                   else if type(css-urls) == str { (css-urls,) }
                   else { css-urls }

    _id-counter.update(0)

    let html-text-fill = cfg.at("html-text-fill", default: cfg.text.fill)
    let html-par-spacing = cfg.at("html-par-spacing", default: 1.4em)
    let body-section = html.elem("section")[
        #set text(fill: html-text-fill)
        #set par(spacing: html-par-spacing)
        #set math.equation(numbering: "(1)")
        #set raw(theme: none)
        #show heading: it => context {
            let idx = query(heading).position(h => h.location() == it.location())
            let tag = "h" + str(it.level)
            html.elem(tag, attrs: (("id"): _heading-slug(idx)))[#it.body]
        }
        // typst/typst#5512: no native MathML emit; inline SVG via html.frame.
        #show math.equation: it => {
            show: if it.block { x => x } else { box }
            html.frame(it)
        }
        #show link: set text(fill: cfg.at("html-link-fill", default: html-text-fill))
        #show list: set block(width: 50%)

        // Raw `#figure(...)` → main-figure (caption in margin). Render
        // full caption (supplement + counter + body) so "Figure N: ..."
        // numbering is visible.
        #show figure: it => {
            let cap = if it.has("caption") and it.caption != none {
                {
                    it.caption.supplement
                    sym.space.nobreak
                    it.caption.counter.display()
                    it.caption.separator
                    it.caption.body
                }
            } else { none }
            main-figure-html(it.body, cap)
        }
        #show footnote: it => _sidenote-triplet(it.body)
        // Typst's `line()` is a page-geometry primitive (invisible in
        // HTML by default). Map to <hr/>.
        #show line: it => html.elem("hr")[]
        #show quote: it => html.elem("blockquote")[
            #html.p(it.body)
            #if it.attribution != none { html.elem("footer")[#it.attribution] }
        ]

        #body
    ]

    let article-body = {
        _render-title-block-html(title, author, email, date)
        if abstract != none { html.elem("p")[#abstract] }
        if toc { toc-html-block() }
        body-section
    }

    html.elem("html", attrs: (("lang"): lang))[
        #html.elem("head")[
            #html.elem("meta", attrs: (("charset"): "utf-8"))[]
            #html.elem("meta", attrs: (("name"): "viewport", ("content"): "width=device-width, initial-scale=1"))[]
            // Per-style default via `cfg.html-color-scheme`; CLI override
            // via `--input color-scheme=light` wins for deterministic refs.
            #let scheme = sys.inputs.at(
                "color-scheme",
                default: cfg.at("html-color-scheme", default: "light dark"),
            )
            #html.elem("meta", attrs: (("name"): "color-scheme", ("content"): scheme))[]
            #html.elem("title")[#doc-title]
            // Caller-supplied head injection: any extra `<meta>`, `<link>`,
            // `<script>`, or other head-level content. Construct with
            // `html.elem` so Typst emits real elements rather than escaped
            // text.
            #if head-extra != none { head-extra }
            #for css-link in html-css {
                html.elem("link", attrs: (
                    ("rel"): "stylesheet",
                    ("href"): css-link,
                ))[]
            }
            #let vendor-only = cfg.at("html-vendor-css-only", default: false)
            #if not vendor-only {
                html.elem("style")[#_INLINE_STYLE]
            }
            // Per-style escape hatch, applied even in vendor-css-only mode so a
            // style can patch the vendored CSS. Emitted last to win on order.
            #let extra = cfg.at("html-extra-css", default: none)
            #if extra != none and extra != "" { html.elem("style")[#extra] }
        ]
        #html.elem("body")[
            #html.elem("article")[#article-body]
        ]
    ]
}
