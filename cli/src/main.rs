use coverage_core::{candidates, parse_codepoint, Db, Designed, Target};
use std::collections::HashSet;
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::time::Instant;

fn main() {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("dump-demo-ids") => return dump_demo_ids(Path::new("refs/IDS.TXT")),
        Some("roadmap") => return roadmap(args.next().as_deref().unwrap_or("l1"), None),
        Some("roadmap-random") => {
            let level = args.next().unwrap_or_else(|| "l1".to_string());
            let seed = args.next().and_then(|s| s.parse().ok()).unwrap_or(1);
            return roadmap(&level, Some(seed));
        }
        _ => {}
    }

    let db = Db::from_ids_file("refs/IDS.TXT").expect("refs/IDS.TXT");
    let target = Target::demo();
    let rows = coverage_core::walk(&db, &target);
    let (effort, coverage) = final_row(&rows, &target);
    println!(
        "demo: {} picks, final coverage {coverage:.6}, total effort {effort}",
        rows.len()
    );
}

/// Print the coverage curve for `l1` or `full`: greedy, or seeded-random when `seed` is set.
fn roadmap(level_arg: &str, seed: Option<u64>) {
    let db = Db::from_ids_file("refs/IDS.TXT").expect("refs/IDS.TXT");
    let (level, target) = target_for(level_arg, &db);
    let start = Instant::now();
    eprintln!("target {level}: {} codepoints", target.len());

    let rows = match seed {
        Some(s) => coverage_core::walk_random(&db, &target, s),
        None => coverage_core::walk(&db, &target),
    };
    print_curve(level, &target, &rows);
    eprintln!("done in {:.2?}", start.elapsed());
}

fn target_for<'a>(level_arg: &'a str, db: &Db) -> (&'a str, Target) {
    match level_arg {
        "full" => ("full", Target::gb18030_full(db)),
        _ => ("l1", Target::gb18030_l1(db)),
    }
}

fn final_row(rows: &[(u32, f32)], target: &Target) -> (u32, f32) {
    rows.last()
        .copied()
        .unwrap_or((0, if target.is_empty() { 1.0 } else { 0.0 }))
}

fn print_curve(level: &str, target: &Target, rows: &[(u32, f32)]) {
    println!("effort,coverage");
    for &(effort, coverage) in rows {
        println!("{effort},{coverage:.6}");
    }

    let (effort, coverage) = final_row(rows, target);
    let draw_all = coverage_core::DRAW_COST * target.len() as u32;
    let saving = if effort == 0 {
        0.0
    } else {
        draw_all as f64 / effort as f64
    };
    eprintln!(
        "# {level}: {} picks, final coverage {coverage:.6}, target {}, total effort {effort}, draw-all-whole {draw_all}, saving {saving:.2}x",
        rows.len(),
        target.len(),
    );
}

/// Emit the IDS.TXT lines covering the demo target's transitive candidate closure, in file
/// order. This regenerates wasm/demo_ids.txt, the subset bundled into the wasm build.
fn dump_demo_ids(path: &Path) {
    let db = Db::from_ids_file(path).expect("refs/IDS.TXT");
    let space: HashSet<_> = candidates(&Designed::new(), &db, &Target::demo()).collect();
    let file = std::fs::File::open(path).expect("refs/IDS.TXT");
    for line in BufReader::new(file).lines().map_while(Result::ok) {
        let cp = line
            .trim_start_matches('\u{FEFF}')
            .split('\t')
            .next()
            .and_then(parse_codepoint);
        if cp.is_some_and(|cp| space.contains(&cp)) {
            println!("{line}");
        }
    }
}
