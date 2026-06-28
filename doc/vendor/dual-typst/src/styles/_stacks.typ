// Shared font stacks. Imported by individual style files so each style
// only declares the *intentional* font choice (not the fallback chain).

#let etbembo = ("ETBembo", "Palatino", "Georgia")
#let gillsans = ("Gill Sans", "Helvetica")

// Inter, bundled via assets/fonts/fetch.sh. Used by orange-happy/bluewhite
// as a free sans alternative to commercial faces (Söhne).
#let inter = ("Inter", "Helvetica Neue", "Helvetica", "Arial")
#let inter-mono = ("JetBrains Mono", "Menlo", "Monaco", "Courier")
#let jetbrains-mono = ("JetBrains Mono", "Menlo", "Monaco", "Courier")

// Public Sans (USWDS, OFL) — free humanist sans close to Colfax. Used by
// terpret. "Input" mono follows the original 2020 page; falls back to
// JetBrains Mono if not installed.
#let public-sans = ("Public Sans", "Helvetica Neue", "Helvetica", "Arial")
#let input-mono  = ("Input", "JetBrains Mono", "Menlo", "Monaco", "Courier")

// Roboto Condensed renamed in-place to "RobotoCondensed" by fetch.sh
// because Typst 0.14 strips axis-suffix words (turning "Roboto
// Condensed" into "Roboto"). The no-space form survives.
#let roboto-condensed = ("RobotoCondensed", "Roboto", "Helvetica Neue", "Helvetica", "Arial")

#let space-grotesk = ("Space Grotesk", "Inter", "Helvetica Neue", "Helvetica", "Arial")
#let newsreader   = ("Newsreader", "Source Serif 4", "Georgia", "Palatino")
#let fraunces     = ("Fraunces", "Newsreader", "Georgia", "Palatino")
#let source-serif = ("Source Serif 4", "Georgia", "Palatino")
