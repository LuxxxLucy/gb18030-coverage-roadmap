// Per-style HTML overlay on top of canonical tufte-css. The result is
// inlined into <head>; tufte-css supplies geometry, this layer paints.

// Link normalization shared by every style. tufte-css paints links with a
// background-gradient underline plus a white text-shadow mask, calibrated for
// et-book; under any other font (e.g. envision's Roboto Condensed) it renders
// as an illegible strikethrough. Strip both, restore a plain hover underline.
// Emitted after the vendored CSS so source order makes it win.
#let link-rules(link: "#0066cc", link-underline: false) = {
    let link-deco = if link-underline { "underline" } else { "none" }
    let link-hover = if link-underline { "" } else { "a:hover { text-decoration: underline; }" }
    (
        "a:link, a:visited { color: " + link + "; text-shadow: none;"
        + " background-image: none; text-decoration: " + link-deco + ";"
        + " text-decoration-skip-ink: auto; text-underline-offset: 0.15em; }"
        + link-hover
    )
}

#let html-overlay(
    import-css: "",
    body-font: "Georgia, serif",
    heading-font: none,
    mono-font: "JetBrains Mono, ui-monospace, monospace",
    bg: "#ffffff",
    fg: "#111111",
    link: "#0066cc",
    heading-color: none,
    note-color: none,
    link-underline: false,
    body-size: "1.05rem",
    body-line-height: "1.6",
    quote-size: "1.4rem",
    quote-line-height: "2rem",
    extra: "",
) = {
    let h-font = if heading-font == none { body-font } else { heading-font }
    let h-color = if heading-color == none { fg } else { heading-color }
    let n-color = if note-color == none { fg } else { note-color }
    (
        import-css
        + "html { background-color: " + bg + "; }"
        + "body { background-color: " + bg + "; color: " + fg + ";"
        + " font-family: " + body-font + ";"
        + " font-size: " + body-size + "; line-height: " + body-line-height + "; }"
        + "h1, h2, h3, h4, h5, h6, .subtitle, .newthought {"
        + " font-family: " + h-font + "; color: " + h-color + ";"
        + " font-style: normal; }"
        + ".sidenote, .marginnote, .sidenote-number, figcaption {"
        + " font-family: " + body-font + "; font-style: normal;"
        + " color: " + n-color + "; line-height: 1.35; }"
        + "article > h1 { width: 70%; } article p.subtitle { width: 65%; }"
        + "pre { overflow-x: auto; font-size: 0.88em; line-height: 1.45; padding: 0.75em 1em; }"
        + "pre code, pre code span { font-size: inherit; line-height: inherit; }"
        + "@media (max-width: 760px), (orientation: portrait) {"
        + " html, body, article, section { width: 100% !important; max-width: 100vw !important; min-width: 0 !important; overflow-x: hidden; box-sizing: border-box; }"
        + " article * { max-width: 100% !important; min-width: 0 !important; box-sizing: border-box; overflow-wrap: anywhere; word-break: normal; }"
        + " body { width: auto !important; padding: 0 !important; margin: 0 !important; } article { width: auto !important; margin: 0 !important; padding: 2rem 1.25rem !important; }"
        + " article > h1, article p.subtitle, article section > h1, article h2, article h3, article p, article ol, article ul, article blockquote, article pre { width: 100% !important; max-width: 100% !important; min-width: 0 !important; box-sizing: border-box; overflow-wrap: anywhere; }"
        + " .sidenote, .marginnote, figcaption { float: none !important; clear: both; display: block; width: 100% !important; max-width: 100% !important; margin: 0.75rem 0; box-sizing: border-box; }"
        + " article > h1 { font-size: clamp(1.65rem, 7vw, 2.2rem) !important; line-height: 1.1 !important; margin-top: 2rem !important; }"
        + " article section > h1 { font-size: clamp(1.35rem, 5vw, 1.7rem) !important; } article blockquote { margin: 2rem 0 !important; padding: 0 !important; font-size: 1rem !important; line-height: 1.5 !important; } article blockquote p { width: 100% !important; max-width: 100% !important; margin: 0 0 0.7rem 0 !important; font-size: 1rem !important; line-height: 1.5 !important; }"
        + " article blockquote footer { width: 100% !important; max-width: 100% !important; font-size: 0.92rem !important; line-height: 1.35 !important; text-align: left !important; }"
        + " label.margin-toggle, input.margin-toggle { display: inline; }"
        + "}"
        + "code, pre, .code, kbd, samp { font-family: " + mono-font + "; }"
        + link-rules(link: link, link-underline: link-underline)
        + " article blockquote footer { display: block; text-align: right; white-space: normal; overflow-wrap: anywhere; }"
        + " article blockquote, article blockquote p {"
        + " font-size: " + quote-size + "; line-height: " + quote-line-height + "; }"
        + extra
    )
}
