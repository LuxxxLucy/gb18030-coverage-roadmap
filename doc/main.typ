#import "vendor/dual-typst/src/lib.typ": tufte, marginnote, sidecite
#import "@preview/cetz:0.4.2"

#show: tufte.with(
  title: [Covering GB18030: computational planning with heuristics],
  author: "Jialin Lu",
  style: "envision",
  date: [2026-06-21],
  abstract: [
  ],
  bib: bibliography("refs.bib"),
)

// Han glyphs render in a CJK serif; the template's Latin fonts are untouched.
#show regex("\p{Han}"): set text(font: "Noto Serif CJK SC")
// IDS operators (⿰ ⿱ ...) are not Han-script; only BabelStone Han covers them.
#show regex("[\u{2FF0}-\u{2FFF}]"): set text(font: "BabelStone Han")

// cetz draws to a frame, which typst's HTML export drops; wrap each canvas so it
// embeds as inline SVG under HTML and passes through unchanged under PDF.
#let target = sys.inputs.at("target", default: "paged")
#let htmlframe(body) = if target == "html" { html.frame(body) } else { body }

#marginnote[Code on #link("https://github.com/LuxxxLucy/gb18030-coverage-roadmap")[Luxxxlucy/gb18030-coverage-roadmap], and the #link("./web/")[live app] running alongside this page. Or clone and run it locally with `./build.sh run-web-app`.]
_TL;DR_ Drawing a Chinese font means covering tens of thousands of characters without drawing tens of thousands of pictures.
The way out is that a character is a recipe: you draw a few hundred parts once, then compose the rest, and composing is far cheaper than drawing.
So the design becomes one ordering question, asked over and over: of everything I could make next, which buys the most coverage for the least drawing effort?
That is a plain greedy walk over the recipe graph, and a few hundred drawn parts cover the standard's level-1 core.
The interactive version is a Dasher-style web app: the characters worth drawing next stand on the right as probability-weighted boxes, and you click one to commit it.

= A planning problem, not a drawing problem

CJK fonts are not just a pain for publishing and the web, with all the workarounds and extra machinery they drag in.
The design, the making of the font itself, is the larger cost.
A Latin-based script is workable as an indie project: a few hundred glyphs, one hand, one season of evenings.
The design of a Chinese font is beyond the reach of any indie team, let alone any individual.

Suppose we are not a foundry.
We are not a team with the work already cut into sections and handed out, each designer assigned a slice.
We have what we have drawn so far, a goal, and a budget of effort.
From a planning perspective, with the single objective of spending the least effort, the question is how to organize what to design and draw next.
The work has to cover a basic requirement first and then climb toward GB18030, so the design becomes a planning and management problem.
This post formulates that problem from a computation perspective.

This is where it became real for me.
A colleague was drawing a font by hand, and a few dozen characters were done.
We kept asking one practical question: which one should he draw next?
I did the only thing I am any good at in a design problem and turned it into a boring ordering problem on paper.

= What a Chinese font has to cover

A type designer does not face one target but a ladder of them, and each rung costs far more than the one below.
Each rung is a published standard.

The floor is literacy.
The #link("https://zh.wikipedia.org/wiki/现代汉语常用字表")[现代汉语常用字表] (List of Frequently Used Characters in Modern Chinese, 1988) names 3,500 characters, 2,500 common and 1,000 less common.#marginnote[The 2,500 common characters alone cover about 99.5% of running text by frequency. A font with these is usable, not complete.]
#link("https://en.wikipedia.org/wiki/GB_2312")[GB2312], the 1980 encoding standard, names 6,763 characters in two levels, 3,755 ordered by pronunciation and 3,008 by radical, plus 682 non-Han symbols.
This is the historical floor for a real simplified font.
The #link("https://en.wikipedia.org/wiki/Table_of_General_Standard_Chinese_Characters")[通用规范汉字表] (Table of General Standard Chinese Characters, 2013) names 8,105 characters in three levels, and is the current government standard for general use.
#link("https://en.wikipedia.org/wiki/GB_18030")[GB18030], the mandatory national standard in its 2022 edition, names 87,887 Han characters, about 88,000.
This is the ceiling.

GB18030 is itself a ladder.
Its implementation level 1 requires 27,584 characters, level 2 adds 196 to complete the general-use table, and level 3 requires all 87,887 plus the 214 Kangxi radicals.
Level 3 is mandatory for government and public-service software.

The counts are the whole problem (@ladder).
A usable font is a few thousand characters; the full standard is twenty-five times larger.
Nobody draws 88,000 pictures one at a time.
The way out is that the characters are not independent.

#figure(
  htmlframe(cetz.canvas({
    import cetz.draw: *
    let rows = (
      ([常用字表 (Frequently-Used)], 3500),
      ([GB2312], 6763),
      ([通用规范 (General Standard)], 8105),
      ([GB18030 L1], 27584),
      ([GB18030 full], 87887),
    )
    let w = 8.0
    let maxx = 87887
    let bh = 0.5
    let gap = 0.35
    for (i, r) in rows.enumerate() {
      let y = -i * (bh + gap)
      let (label, n) = r
      let bw = n / maxx * w
      rect((0, y), (bw, y - bh), fill: blue.lighten(70%), stroke: blue.darken(10%) + 0.5pt)
      content((-0.2, y - bh / 2), anchor: "east", text(size: 0.85em)[#label])
      content((bw + 0.15, y - bh / 2), anchor: "west", text(size: 0.85em)[#n])
    }
  })),
  caption: [The requirement ladder, drawn to linear scale. A usable font (常用字表, the Frequently-Used list, 3,500) and even GB2312 (6,763) are slivers against the full GB18030 ceiling of 87,887. The gap between floor and ceiling is why coverage has to be planned, not brute-forced.],
) <ladder>

== How a character is written down

A Chinese character is built from parts, and a published data format called IDS records which parts.
明, which means "bright", is 日 the sun beside 月 the moon.
#link("https://en.wikipedia.org/wiki/Ideographic_Description_Sequence")[IDS] (Ideographic Description Sequence) writes that recipe as ⿰日月: the layout operator first, then its parts.
⿰ means "left beside right".
The notation is prefix, like Polish notation, and each operator takes a fixed number of parts, so the string parses into a tree with no brackets (@decomp).
There are seventeen such operators, sixteen in one Unicode block plus one for subtraction, covering left-and-right, top-and-bottom, enclosure, overlay, and a handful of rarer layouts.

A part can itself be a recipe, so the tree recurses.
警 expands four levels deep before it bottoms out.
The leaves are atomic: a single stroke, or a radical with no smaller recipe of its own.

#figure(
  htmlframe(cetz.canvas({
    import cetz.draw: *
    let glyph(pos, body) = {
      circle(pos, radius: 0.5, fill: blue.lighten(85%), stroke: blue.darken(10%) + 0.6pt)
      content(pos, text(size: 1.4em)[#body])
    }
    let op(pos, body) = {
      circle(pos, radius: 0.5, fill: orange.lighten(80%), stroke: orange.darken(15%) + 0.7pt)
      content(pos, text(size: 1.5em)[#body])
    }
    let mei = (0, 2.5)
    let o = (0, 1.0)
    let ri = (-1.3, -0.5)
    let yue = (1.3, -0.5)
    line(mei, o, stroke: gray + 0.6pt)
    line(o, ri, stroke: gray + 0.6pt)
    line(o, yue, stroke: gray + 0.6pt)
    glyph(mei, [明])
    op(o, [⿰])
    glyph(ri, [日])
    glyph(yue, [月])
  })),
  caption: [A recipe is a tree. 明 is the operator ⿰ ("left beside right") applied to 日 and 月. A character is not one picture but an operator plus its parts, and the parts can decompose again.],
) <decomp>

The recipes are not something I invented; they are published data.
#link("https://www.babelstone.co.uk/CJK/IDS.html")[BabelStone]'s IDS file lists decompositions for about 97,000 characters, near the whole encoded repertoire, and the #link("https://www.chise.org/")[CHISE] project ships a comparable open set.
There is one catch, and the rest of the post depends on it.
An IDS can only name a part that has its own codepoint.
Some characters contain a component that was never encoded, written with a placeholder ？, and that character cannot be composed from references.
It has to be drawn whole.
Composition stops at the first part that does not exist on its own.

= The covering problem

Take the font away and a graph is left (@dag).
Write $G$ for the set of all glyphs, parts and characters alike.
Some glyphs are targets, the characters of the standard we have to produce; call that set $T subset.eq G$.
Some glyphs are roots, the primitives a designer can only draw, the strokes and the radicals with no smaller recipe; call that set $R subset.eq G$.
A recipe turns into edges: 明 `⿰日月` draws an edge up from each of 日 and 月 to 明.
A glyph can need several parts at once, so the structure is a directed hypergraph rather than a plain graph, but the picture is the same, with roots at the top and targets at the bottom.

#figure(
  htmlframe(cetz.canvas({
    import cetz.draw: *
    let node(pos, body, drawn) = {
      let fill = if drawn { blue.lighten(70%) } else { white }
      circle(pos, radius: 0.45, fill: fill, stroke: 0.7pt)
      content(pos, text(size: 1.2em)[#body])
    }
    let ri = (-1.6, 2.2)
    let yue = (1.6, 2.2)
    let yi = (3.6, 2.2)
    let mei = (-0.8, 0)
    let dan = (2.6, 0)
    line(ri, mei, stroke: gray + 0.6pt)
    line(yue, mei, stroke: gray + 0.6pt)
    line(ri, dan, stroke: gray + 0.6pt)
    line(yi, dan, stroke: gray + 0.6pt)
    node(ri, [日], true)
    node(yue, [月], false)
    node(yi, [一], true)
    node(mei, [明], false)
    node(dan, [旦], false)
    content((-3.4, 2.2), text(size: 0.8em)[roots / draw])
    content((-3.4, 0), text(size: 0.8em)[leaves / cover])
  })),
  caption: [The same recipes as a graph. Roots (日, 一, here drawn and shaded) are primitives you draw; leaves (明, 旦) are the targets. A leaf is covered once every root above it is drawn and it is composed. 月 is still missing, so 明 cannot be composed yet, but 旦 needs only 日 and 一, both present.],
) <dag>

At any moment some glyphs are made; call that set $M subset.eq G$, and it starts empty.
A glyph enters $M$ in one of two ways, and they cost different amounts.
You can draw it, paying $c = 5$, available for any glyph.
Or, once all the parts of one of its recipes are in $M$, you can compose it, paying $c = 1$.#marginnote[The two costs are a toy. The general form is $c(g) = min(d(g), 1 + sum c("missing parts"))$, the draw-whole versus build-from-parts choice, where the draw cost $d(g)$ would depend on how hard the shape is. Five and one are stand-ins for "expensive" and "cheap" so the order has something concrete to optimize.]
A target whose recipe names an unencoded part has no usable recipe, so it can only ever be drawn.

Coverage is the fraction of targets made, $"cov"(M) = (|M inter T|) / (|T|)$.
The objective is not a single number but a curve.
Order the makes $a_1, a_2, dots$ so that coverage climbs as fast as it can against the cumulative effort spent:

$ "track" quad "cov"(M_t) quad "against" quad E_t = sum_(s <= t) c(a_s). $

The x-axis of the whole problem is effort, not the number of moves.
This is a budgeted maximum-coverage problem #sidecite(<nemhauser1978analysis>): spend each unit of effort where it buys the most coverage.

= The algorithm: spend where it pays

The algorithm is one greedy loop, the simplest thing that respects the two costs.
At each step, look at every move available right now.
You can compose any glyph whose parts are all made, for effort 1.
You can draw any root, for effort 5.
Score each move by the coverage it buys per unit of effort, $v(a) / c(a)$, take the best one, and repeat until every target is made.

One quantity is left to define: how much a move buys, $v(a)$.
A composition buys the glyph it finishes, plus any glyph that finishing it now makes composable in turn.
A draw usually finishes no character on its own, because the character still waits on its other parts.
So a draw is credited with its _reach_: how many still-uncovered targets have this part somewhere in their recipe.
Reach is what tells the loop that 日 is worth drawing long before any character it sits in is done (@fan).

#figure(
  htmlframe(cetz.canvas({
    import cetz.draw: *
    let part = (0, 0)
    let tops = ((-3.3, 2.3), (-1.1, 2.3), (1.1, 2.3), (3.3, 2.3))
    let glyphs = ([明], [旦], [时], [星])
    for t in tops { line(part, t, stroke: gray + 0.6pt) }
    for (i, t) in tops.enumerate() {
      circle(t, radius: 0.45, fill: white, stroke: 0.6pt)
      content(t, text(size: 1.2em)[#glyphs.at(i)])
    }
    circle(part, radius: 0.55, fill: blue.lighten(75%), stroke: blue.darken(10%) + 0.8pt)
    content(part, text(size: 1.4em)[日])
  })),
  caption: [Why the order matters. 日 sits inside 明, 旦, 时, 星, and hundreds more. Drawing it finishes none of them by itself, but it moves every one of their recipes a step closer to done. That count of waiting targets is its reach.],
) <fan>

Put the two costs together and the loop's behaviour is plain.

+ *Compose first.* A composition costs 1 and finishes a character worth 1, so it almost always wins. The loop assembles everything it can before it spends on a draw.
+ *Then draw the part with the largest reach.* When no cheap composition is left, the loop reaches for the pen and draws the part whose 5 units open the most future compositions.
+ *Repeat* until coverage is full.

At the very start nothing is composable, so the loop draws.
The first thing it draws is whatever sits under the most of the standard: a basic stroke, then a high-reach radical.
That is the order a type foundry already works in, recovered from nothing but the two costs.
There is no search, no backtracking, no tuning.

This is not a finished story.
The greedy is a heuristic, not a proof.
A recipe is an AND: a character needs all its parts.
So coverage jumps only when a part's last sibling lands, and the usual near-optimality guarantee for covering problems does not strictly apply #sidecite(<feige1998threshold>).

= The web app <sec-app>

The method is easier to feel than to read, so the repository ships an interactive version, and it borrows Dasher's idea of choosing by pointing.#marginnote[The live app runs #link("./web/")[here], alongside this post.]
The canvas splits at a vertical line down the center.
Left of the line is the history, the characters already accepted, receding leftward as a trail.
Right of the line are the candidates, the top-scored characters to draw next, each a box whose height is its share of the total score, so the best next move is the tallest box.
Nested in each candidate, in amber, is a preview of the targets that accepting it would unlock next.
Click a box and the app makes that glyph: it joins the history on the left, the frontier recomputes, and the right half rebuilds from the new top scores.
The click order it recommends is the greedy order from the previous section, made visible.

= What is still open

The model so far is deliberately thin, and three things move it toward a real production plan.

*Frequency.*
Not every target is worth the same.
A character in the common 3,500 earns its coverage sooner than a rare one in the tail, so the value of a move should weight targets by usage frequency rather than count them equally.

*Variable effort.*
The two costs, 5 and 1, are a toy.
A real model lets the drawing cost depend on the shape, since a simple radical is cheaper to draw than a dense one.
The drawing cost can even be read off the shapes themselves: score a candidate part by its bitmap similarity to parts already drawn, so a look-alike shape costs less once one of its family exists.

*Group drawing.*
The loop draws one part at a time, but a designer does not.
Similar radicals and similar components are best drawn together in one session, where the hand is set once and reused, so the plan should cluster look-alike parts into a joint drawing job rather than schedule them singly.

These are work in progress.
The shape of the answer is already here.
When my colleague's question comes back, which character should I draw next, it is no longer a guess: draw the foundation that the most of the standard is waiting on, compose everything it lets you compose, and spend the next expensive stroke only where it pays.
