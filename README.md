# coverage-roadmap

A Dasher-style web app whose zoomer steers and commits which Chinese codepoint to design next to cover GB18030.
Given the components you have already designed, it shows which one unlocks the most of the
standard next, played as a tech-tree. A companion CLI emits the full coverage curve.

## Run

    ./build.sh run-web-app    # serve the web app (bundled demo set, works out of the box)
    ./build.sh build          # build the Rust core and the static web bundle into app/dist/
    ./build.sh roadmap l1     # print the GB18030 coverage curve as CSV (l1 | full)
    ./build.sh curves         # write doc/curve_l1.csv and doc/curve_l1_random.csv
    ./build.sh test           # run the test suite

`run-web-app` needs Node. `roadmap` needs the BabelStone IDS file at `refs/IDS.TXT`.

The method, the algorithm, and the data sources are written up in `doc/`; `doc/build.sh`
emits `main.pdf` and `main.html`.
