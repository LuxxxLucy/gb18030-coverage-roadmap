//! IDS domain: operators and trees, the parsed database, structural queries
//! (decomposition graph, unlocks, layers), and reachability.

use crate::cover::Target;
use crate::Cp;
use std::collections::{HashMap, HashSet};
use std::io::{BufRead, BufReader, Read};
use std::path::Path;

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub enum Idc {
    LeftRight,
    AboveBelow,
    LeftMiddleRight,
    AboveMiddleBelow,
    FullSurround,
    SurroundAbove,
    SurroundBelow,
    SurroundLeft,
    SurroundUpperLeft,
    SurroundUpperRight,
    SurroundLowerLeft,
    Overlaid,
    SurroundRight,
    SurroundLowerRight,
    HorizontalReflection,
    Rotation,
}

impl Idc {
    pub const ALL: [Self; 16] = [
        Self::LeftRight,
        Self::AboveBelow,
        Self::LeftMiddleRight,
        Self::AboveMiddleBelow,
        Self::FullSurround,
        Self::SurroundAbove,
        Self::SurroundBelow,
        Self::SurroundLeft,
        Self::SurroundUpperLeft,
        Self::SurroundUpperRight,
        Self::SurroundLowerLeft,
        Self::Overlaid,
        Self::SurroundRight,
        Self::SurroundLowerRight,
        Self::HorizontalReflection,
        Self::Rotation,
    ];

    pub fn arity(self) -> u8 {
        match self {
            Self::LeftMiddleRight | Self::AboveMiddleBelow => 3,
            Self::HorizontalReflection | Self::Rotation => 1,
            _ => 2,
        }
    }

    pub fn from_char(c: char) -> Option<Self> {
        let i = (c as u32).checked_sub(0x2FF0)?;
        Self::ALL.get(i as usize).copied()
    }

    pub fn to_char(self) -> char {
        let i = Self::ALL.iter().position(|&o| o == self).unwrap() as u32;
        char::from_u32(0x2FF0 + i).unwrap()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum IdsTree {
    Leaf(Cp),
    Stroke(u16),
    Unresolved,
    Op(Idc, Vec<IdsTree>),
}

impl IdsTree {
    /// Codepoints named directly in this tree, at any nesting depth.
    pub fn leaves(&self) -> Vec<Cp> {
        let mut out = Vec::new();
        self.collect_leaves(&mut out);
        out
    }

    fn collect_leaves(&self, out: &mut Vec<Cp>) {
        match self {
            Self::Leaf(cp) => out.push(*cp),
            Self::Op(_, operands) => operands.iter().for_each(|o| o.collect_leaves(out)),
            Self::Stroke(_) | Self::Unresolved => {}
        }
    }

    /// Whether an `Unresolved` (`?`) node appears anywhere in this tree.
    pub fn has_unresolved(&self) -> bool {
        match self {
            Self::Unresolved => true,
            Self::Op(_, operands) => operands.iter().any(Self::has_unresolved),
            _ => false,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct Db {
    pub ids: HashMap<Cp, IdsTree>,
    pub parents: HashMap<Cp, Vec<Cp>>,
    pub renderable: HashSet<Cp>,
}

impl Db {
    pub fn empty() -> Self {
        Self::default()
    }

    pub fn from_ids_file<P: AsRef<Path>>(path: P) -> std::io::Result<Self> {
        Ok(load_ids(std::fs::File::open(path)?))
    }
}

const PLACEHOLDER: char = '\u{FF1F}';
const STROKE_LO: u32 = 0x31C0;
const STROKE_HI: u32 = 0x31EF;

pub fn parse_ids(s: &str) -> Option<IdsTree> {
    let mut chars = s.chars();
    let tree = parse_node(&mut chars)?;
    chars.next().is_none().then_some(tree)
}

fn parse_node(chars: &mut std::str::Chars) -> Option<IdsTree> {
    let c = chars.next()?;
    let Some(op) = Idc::from_char(c) else {
        return Some(leaf(c));
    };
    let operands = (0..op.arity())
        .map(|_| parse_node(chars))
        .collect::<Option<Vec<_>>>()?;
    Some(IdsTree::Op(op, operands))
}

fn leaf(c: char) -> IdsTree {
    let cp = c as u32;
    if c == PLACEHOLDER {
        IdsTree::Unresolved
    } else if (STROKE_LO..=STROKE_HI).contains(&cp) {
        IdsTree::Stroke((cp - STROKE_LO) as u16)
    } else {
        IdsTree::Leaf(Cp(cp))
    }
}

pub fn load_ids<R: Read>(reader: R) -> Db {
    let mut db = Db::empty();
    for line in BufReader::new(reader).lines().map_while(Result::ok) {
        let line = line.trim_start_matches('\u{FEFF}');
        if line.starts_with('#') || line.is_empty() {
            continue;
        }
        let mut fields = line.split('\t');
        let (Some(cp_field), Some(_), Some(seq_field)) =
            (fields.next(), fields.next(), fields.next())
        else {
            continue;
        };
        let Some(cp) = parse_codepoint(cp_field) else {
            continue;
        };
        let Some(tree) = parse_ids(strip_tags(seq_field)) else {
            continue;
        };
        // parents lists, for each codepoint, the glyphs naming it anywhere in their IDS tree,
        // once per glyph (林 = ⿰木木 lists 木 a single time).
        let mut seen = HashSet::new();
        for child in tree.leaves() {
            if seen.insert(child) {
                db.parents.entry(child).or_default().push(cp);
            }
        }
        db.ids.insert(cp, tree);
    }
    db
}

pub fn parse_codepoint(field: &str) -> Option<Cp> {
    let hex = field.strip_prefix("U+")?;
    u32::from_str_radix(hex, 16).ok().map(Cp)
}

fn strip_tags(seq: &str) -> &str {
    let seq = seq.trim();
    let seq = seq.strip_prefix('^').unwrap_or(seq);
    &seq[..seq.find(['$', '(', '[']).unwrap_or(seq.len())]
}

#[derive(Clone, Debug, Default)]
pub struct Designed {
    cps: HashSet<Cp>,
}

impl Designed {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn insert(&mut self, cp: Cp) {
        self.cps.insert(cp);
    }

    pub fn contains(&self, cp: Cp) -> bool {
        self.cps.contains(&cp)
    }

    pub fn len(&self) -> usize {
        self.cps.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cps.is_empty()
    }
}

/// A glyph is reachable when it is in `D`, or its IDS decomposition's operands are reachable.
fn reachable_tree(
    tree: &IdsTree,
    d: &Designed,
    db: &Db,
    seen: &mut HashMap<Cp, bool>,
    stack: &mut HashSet<Cp>,
) -> bool {
    match tree {
        IdsTree::Stroke(_) => true,
        IdsTree::Unresolved => false,
        IdsTree::Leaf(cp) => reachable_cp(*cp, d, db, seen, stack),
        IdsTree::Op(_, operands) => operands
            .iter()
            .all(|o| reachable_tree(o, d, db, seen, stack)),
    }
}

fn reachable_cp(
    cp: Cp,
    d: &Designed,
    db: &Db,
    seen: &mut HashMap<Cp, bool>,
    stack: &mut HashSet<Cp>,
) -> bool {
    if d.contains(cp) {
        return true;
    }
    if let Some(&r) = seen.get(&cp) {
        return r;
    }
    if !stack.insert(cp) {
        return false;
    }
    let r = match db.ids.get(&cp) {
        Some(tree) => reachable_tree(tree, d, db, seen, stack),
        None => false,
    };
    stack.remove(&cp);
    seen.insert(cp, r);
    r
}

/// Whether `cp` is reachable given `d` and `db`, with a fresh memo.
pub fn reachable(cp: Cp, d: &Designed, db: &Db) -> bool {
    reachable_cp(cp, d, db, &mut HashMap::new(), &mut HashSet::new())
}

/// Incremental reachability: the monotone Dowling-Gallier counter engine.
#[derive(Clone, Debug)]
pub struct Reach {
    reach: HashSet<Cp>,
    /// Count of still-unreachable distinct real-leaf cps per glyph.
    need: HashMap<Cp, usize>,
    /// Glyphs whose tree holds an `Unresolved` part.
    blocked: HashSet<Cp>,
}

impl Reach {
    /// Build from `db`, seeding glyphs whose tree needs no real leaf as reachable.
    pub fn new(db: &Db) -> Self {
        let mut r = Self {
            reach: HashSet::new(),
            need: HashMap::new(),
            blocked: HashSet::new(),
        };
        let mut ready = Vec::new();
        for (&cp, tree) in &db.ids {
            if tree.has_unresolved() {
                r.blocked.insert(cp);
            }
            let n = distinct_leaves(tree).count();
            r.need.insert(cp, n);
            if n == 0 && !r.blocked.contains(&cp) {
                ready.push(cp);
            }
        }
        for cp in ready {
            r.design(cp, db);
        }
        r
    }

    /// A `Reach` seeded with every cp of `d` designed.
    pub fn from_designed(d: &Designed, db: &Db) -> Self {
        let mut r = Self::new(db);
        for &cp in &d.cps {
            r.design(cp, db);
        }
        r
    }

    pub fn contains(&self, cp: Cp) -> bool {
        self.reach.contains(&cp)
    }

    /// Assert `cp` reachable and cascade; returns newly reachable glyphs.
    pub fn design(&mut self, cp: Cp, db: &Db) -> Vec<Cp> {
        let mut delta = Vec::new();
        self.mark(cp, db, &mut delta);
        delta
    }

    fn mark(&mut self, cp: Cp, db: &Db, delta: &mut Vec<Cp>) {
        if !self.reach.insert(cp) {
            return;
        }
        self.need.remove(&cp);
        delta.push(cp);
        for &parent in db.parents.get(&cp).into_iter().flatten() {
            let Some(n) = self.need.get_mut(&parent) else {
                continue;
            };
            *n -= 1;
            if *n == 0 && !self.blocked.contains(&parent) {
                self.mark(parent, db, delta);
            }
        }
    }
}

/// Distinct real-leaf codepoints of a tree.
pub(crate) fn distinct_leaves(tree: &IdsTree) -> impl Iterator<Item = Cp> {
    tree.leaves()
        .into_iter()
        .collect::<HashSet<_>>()
        .into_iter()
}

/// BFS from `seeds`, visiting each cp once.
pub(crate) fn bfs(
    seeds: impl IntoIterator<Item = Cp>,
    mut neighbors: impl FnMut(Cp, &mut dyn FnMut(Cp)),
) -> HashSet<Cp> {
    let mut seen: HashSet<Cp> = seeds.into_iter().collect();
    let mut work: Vec<Cp> = seen.iter().copied().collect();
    while let Some(cp) = work.pop() {
        let mut next = Vec::new();
        neighbors(cp, &mut |n| next.push(n));
        for n in next {
            if seen.insert(n) {
                work.push(n);
            }
        }
    }
    seen
}

/// Walk DOWN through IDS leaves from `cp`.
pub(crate) fn down(db: &Db) -> impl Fn(Cp, &mut dyn FnMut(Cp)) + '_ {
    move |cp, push| {
        if let Some(tree) = db.ids.get(&cp) {
            tree.leaves().into_iter().for_each(push);
        }
    }
}

/// Coverage state of a target codepoint.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum State {
    Locked,
    Reachable,
    Designed,
}

impl State {
    /// Wire code: 0 locked, 1 reachable, 2 designed.
    pub fn code(self) -> u8 {
        match self {
            Self::Locked => 0,
            Self::Reachable => 1,
            Self::Designed => 2,
        }
    }
}

/// Classify `cp`: designed if in `d`, reachable if buildable now, else locked.
pub fn state(cp: Cp, d: &Designed, db: &Db) -> State {
    if d.contains(cp) {
        State::Designed
    } else if reachable(cp, d, db) {
        State::Reachable
    } else {
        State::Locked
    }
}

/// Whether `cp` must be drawn by hand.
pub fn designable(cp: Cp, db: &Db) -> bool {
    match db.ids.get(&cp) {
        Some(tree @ IdsTree::Op(_, _)) => tree.has_unresolved(),
        _ => true,
    }
}

/// A node of the merged decomposition DAG.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct GraphNode {
    pub cp: Cp,
    pub state: u8,
    pub layer: usize,
}

/// A "is composed of" edge, drawn upward.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct GraphEdge {
    pub from: Cp,
    pub to: Cp,
}

/// The merged decomposition DAG over `t`'s closure.
pub fn target_graph(db: &Db, t: &Target, d: &Designed) -> (Vec<GraphNode>, Vec<GraphEdge>) {
    let mut edges = Vec::new();
    let closure = bfs(t.iter(), |cp, push| {
        if let Some(tree) = db.ids.get(&cp) {
            for leaf in tree.leaves() {
                edges.push(GraphEdge { from: leaf, to: cp });
                push(leaf);
            }
        }
    });
    let reach = Reach::from_designed(d, db);
    let mut layer_memo = HashMap::new();
    let mut stack = HashSet::new();
    let nodes = closure
        .iter()
        .map(|&cp| GraphNode {
            cp,
            state: node_state(cp, d, &reach).code(),
            layer: layer_of(cp, db, &mut layer_memo, &mut stack),
        })
        .collect();
    (nodes, edges)
}

/// Distinct, not-yet-designed targets that directly name `cp` as a component, excluding `cp`.
/// The glyphs choosing `cp` helps unlock, one IDS level up.
pub fn unlocks(db: &Db, t: &Target, cp: Cp, d: &Designed) -> Vec<Cp> {
    let closure = bfs(t.iter(), down(db));
    let mut out: Vec<Cp> = closure
        .into_iter()
        .filter(|&node| node != cp && !d.contains(node))
        .filter(|&node| {
            db.ids
                .get(&node)
                .map(|tree| tree.leaves().contains(&cp))
                .unwrap_or(false)
        })
        .collect();
    out.sort();
    out
}

fn node_state(cp: Cp, d: &Designed, reach: &Reach) -> State {
    if d.contains(cp) {
        State::Designed
    } else if reach.contains(cp) {
        State::Reachable
    } else {
        State::Locked
    }
}

fn layer_of(cp: Cp, db: &Db, memo: &mut HashMap<Cp, usize>, stack: &mut HashSet<Cp>) -> usize {
    if let Some(&l) = memo.get(&cp) {
        return l;
    }
    if !stack.insert(cp) {
        return 0;
    }
    let layer = match db.ids.get(&cp).map(IdsTree::leaves) {
        Some(leaves) if !leaves.is_empty() => leaves
            .iter()
            .map(|&leaf| 1 + layer_of(leaf, db, memo, stack))
            .max()
            .unwrap_or(0),
        _ => 0,
    };
    stack.remove(&cp);
    memo.insert(cp, layer);
    layer
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn idc_char_round_trip() {
        for op in Idc::ALL {
            assert_eq!(Idc::from_char(op.to_char()), Some(op));
        }
    }

    #[test]
    fn idc_from_char_rejects_non_idc() {
        assert_eq!(Idc::from_char('木'), None);
        assert_eq!(Idc::from_char('\u{2FEF}'), None);
        assert_eq!(Idc::from_char('\u{3000}'), None);
    }

    #[test]
    fn idc_arity_covers_all_operators() {
        let expected = [
            (Idc::LeftRight, 2),
            (Idc::AboveBelow, 2),
            (Idc::LeftMiddleRight, 3),
            (Idc::AboveMiddleBelow, 3),
            (Idc::FullSurround, 2),
            (Idc::SurroundAbove, 2),
            (Idc::SurroundBelow, 2),
            (Idc::SurroundLeft, 2),
            (Idc::SurroundUpperLeft, 2),
            (Idc::SurroundUpperRight, 2),
            (Idc::SurroundLowerLeft, 2),
            (Idc::Overlaid, 2),
            (Idc::SurroundRight, 2),
            (Idc::SurroundLowerRight, 2),
            (Idc::HorizontalReflection, 1),
            (Idc::Rotation, 1),
        ];

        assert_eq!(Idc::ALL.len(), expected.len());
        for (idc, arity) in expected {
            assert_eq!(idc.arity(), arity);
        }
    }

    #[test]
    fn parse_left_right() {
        assert_eq!(
            parse_ids("⿰木木"),
            Some(IdsTree::Op(
                Idc::LeftRight,
                vec![
                    IdsTree::Leaf(Cp('木' as u32)),
                    IdsTree::Leaf(Cp('木' as u32))
                ],
            ))
        );
    }

    #[test]
    fn parse_nested() {
        assert_eq!(
            parse_ids("⿰木⿱田木"),
            Some(IdsTree::Op(
                Idc::LeftRight,
                vec![
                    IdsTree::Leaf(Cp('木' as u32)),
                    IdsTree::Op(
                        Idc::AboveBelow,
                        vec![
                            IdsTree::Leaf(Cp('田' as u32)),
                            IdsTree::Leaf(Cp('木' as u32))
                        ],
                    ),
                ],
            ))
        );
    }

    #[test]
    fn parse_placeholder_and_stroke() {
        assert_eq!(
            parse_ids("⿰木？"),
            Some(IdsTree::Op(
                Idc::LeftRight,
                vec![IdsTree::Leaf(Cp('木' as u32)), IdsTree::Unresolved],
            ))
        );
        assert_eq!(parse_ids("\u{31C0}"), Some(IdsTree::Stroke(0)));
    }

    #[test]
    fn parse_rejects_malformed() {
        assert_eq!(parse_ids("⿰木"), None); // truncated
        assert_eq!(parse_ids("木木"), None); // trailing junk
        assert_eq!(parse_ids("⿰木木木"), None); // extra operand
        assert_eq!(parse_ids(""), None);
    }

    #[test]
    fn strip_tags_handles_anchors_and_sources() {
        assert_eq!(strip_tags("^⿰木木$(GHTJKPV)"), "⿰木木");
        assert_eq!(strip_tags("⿰木木[GTV]"), "⿰木木");
    }

    #[test]
    fn load_builds_ids_and_parents() {
        let data = "# comment\nU+6797\t林\t^⿰木木$(GHTJKPV)\nU+660E\t明\t^⿰日月$(GHTJKPV)\n";
        let db = load_ids(data.as_bytes());
        assert!(db.ids.contains_key(&Cp('林' as u32)));
        // 木 appears twice in 林 = ⿰木木 but is listed once.
        assert_eq!(db.parents[&Cp('木' as u32)], vec![Cp('林' as u32)]);
    }

    #[test]
    fn parents_cover_nested_leaves() {
        let db = load_ids("U+0001\t.\t⿰木⿱田火\n".as_bytes());
        let p = Cp(1);
        // every leaf names its glyph, nested or not.
        assert_eq!(db.parents[&Cp('木' as u32)], vec![p]);
        assert_eq!(db.parents[&Cp('田' as u32)], vec![p]);
        assert_eq!(db.parents[&Cp('火' as u32)], vec![p]);
    }

    #[test]
    fn designed_insert_contains_by_codepoint() {
        let mut designed = Designed::new();
        assert!(designed.is_empty());
        assert!(!designed.contains(Cp(0x6728)));

        designed.insert(Cp(0x6728));
        designed.insert(Cp(0x65e5));

        assert!(designed.contains(Cp(0x6728)));
        assert!(designed.contains(Cp(0x65e5)));
        assert!(!designed.contains(Cp(0x6708)));
        assert_eq!(designed.len(), 2);
    }

    #[test]
    fn composite_reachable_once_parts_designed() {
        let db = load_ids("U+660E\t明\t⿰日月\n".as_bytes());
        let mut d = Designed::new();
        assert!(!reachable(Cp(0x660e), &d, &db));

        d.insert(Cp(0x65e5));
        assert!(!reachable(Cp(0x660e), &d, &db));

        d.insert(Cp(0x6708));
        assert!(reachable(Cp(0x660e), &d, &db));
    }

    #[test]
    fn state_moves_locked_reachable_designed() {
        let db = load_ids("U+660E\t明\t⿰日月\n".as_bytes());
        let mut d = Designed::new();
        assert_eq!(state(Cp(0x660e), &d, &db), State::Locked);

        d.insert(Cp(0x65e5));
        d.insert(Cp(0x6708));
        assert_eq!(state(Cp(0x660e), &d, &db), State::Reachable);

        d.insert(Cp(0x660e));
        assert_eq!(state(Cp(0x660e), &d, &db), State::Designed);
    }

    #[test]
    fn unresolved_and_atomic_unreachable() {
        let db = load_ids("U+0001\t.\t⿰木？\n".as_bytes());
        let mut d = Designed::new();
        d.insert(Cp(0x6728));
        assert!(!reachable(Cp(1), &d, &db));
        assert!(!reachable(Cp(0x9fff), &d, &db));
    }

    #[test]
    fn designable_offers_primitives_and_irreducibles_only() {
        let db = load_ids("U+0043\tC\t⿰AB\nU+0049\tI\t⿰木？\n".as_bytes());
        let (a, b, c, i, mu) = (Cp(0x41), Cp(0x42), Cp(0x43), Cp(0x49), Cp(0x6728));

        assert!(designable(a, &db));
        assert!(designable(b, &db));
        assert!(designable(mu, &db));
        assert!(designable(i, &db)); // holds a `?`, so it is drawn whole
        assert!(!designable(c, &db)); // composable from A and B
    }

    #[test]
    fn reach_parity_on_synthetic() {
        let db = load_ids(
            "U+0041\tA\t⿰XB\nU+0042\tB\t⿱XY\nU+0050\tP\t⿰Q木\nU+0051\tQ\t⿰P火\n\
             U+0053\tS\tS\nU+0049\tI\t⿰木？\nU+0054\tT\t㇀\n"
                .as_bytes(),
        );
        let universe = [
            0x41, 0x42, 0x50, 0x51, 0x53, 0x49, 0x54, 0x58, 0x59, 0x6728, 0x706b,
        ];
        let seqs: &[&[u32]] = &[
            &[0x58, 0x59],
            &[0x59, 0x58],
            &[0x6728, 0x706b],
            &[0x53],
            &[0x6728, 0x49],
            &[0x58, 0x59, 0x6728],
        ];
        for seq in seqs {
            let mut d = Designed::new();
            let mut r = Reach::new(&db);
            for &cp in *seq {
                d.insert(Cp(cp));
                r.design(Cp(cp), &db);
            }
            for &cp in &universe {
                assert_eq!(
                    r.contains(Cp(cp)),
                    reachable(Cp(cp), &d, &db),
                    "seq {seq:?} cp U+{cp:04X}"
                );
            }
        }
        assert!(Reach::new(&db).contains(Cp(0x54)));
        assert!(reachable(Cp(0x54), &Designed::new(), &db));
    }

    #[test]
    fn target_graph_nodes_edges_layers() {
        let db = load_ids("U+0041\tA\t⿰B日\nU+0042\tB\t⿱XY\n".as_bytes());
        let t = Target::from_cps([Cp('A' as u32)]);
        let (nodes, edges) = target_graph(&db, &t, &Designed::new());

        let cps: HashSet<Cp> = nodes.iter().map(|n| n.cp).collect();
        let want: HashSet<Cp> = ['A', 'B', 'X', 'Y']
            .map(|c| Cp(c as u32))
            .into_iter()
            .collect();
        assert!(want.is_subset(&cps));
        assert!(cps.contains(&Cp(0x65e5)));
        assert_eq!(nodes.len(), 5);

        let layer = |c: char| nodes.iter().find(|n| n.cp == Cp(c as u32)).unwrap().layer;
        assert_eq!(layer('X'), 0);
        assert_eq!(layer('B'), 1);
        assert_eq!(layer('A'), 2);

        let edge = |f: char, tt: char| {
            edges.contains(&GraphEdge {
                from: Cp(f as u32),
                to: Cp(tt as u32),
            })
        };
        assert!(edge('B', 'A'));
        assert!(edge('X', 'B'));
        assert!(edge('Y', 'B'));
        assert!(!edge('A', 'B'));
    }

    #[test]
    fn unlocks_lists_dependents_excluding_self() {
        // B is named by A and C; A is also named by C. B never names itself.
        let db = load_ids("U+0041\tA\t⿰B木\nU+0043\tC\t⿱AB\n".as_bytes());
        let t = Target::from_cps([Cp('C' as u32)]);
        let got: HashSet<Cp> = unlocks(&db, &t, Cp('B' as u32), &Designed::new())
            .into_iter()
            .collect();
        let want: HashSet<Cp> = ['A', 'C'].map(|c| Cp(c as u32)).into_iter().collect();
        assert_eq!(got, want);
        assert!(!got.contains(&Cp('B' as u32)));
    }

    #[test]
    fn target_graph_handles_cycle() {
        let db = load_ids("U+0050\tP\t⿰Q木\nU+0051\tQ\t⿰P火\n".as_bytes());
        let t = Target::from_cps([Cp('P' as u32)]);
        let (nodes, _) = target_graph(&db, &t, &Designed::new());
        let cps: HashSet<Cp> = nodes.iter().map(|n| n.cp).collect();
        assert!(cps.contains(&Cp('P' as u32)));
        assert!(cps.contains(&Cp('Q' as u32)));
        assert!(nodes.iter().all(|n| n.layer < 1000));
    }
}
