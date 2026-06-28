//! The greedy cover algorithm: the target set, effort costs, candidate selection, and the walk.

use crate::ids::{bfs, designable, distinct_leaves, down, Db, Designed, IdsTree};
use crate::Cp;
use std::collections::{HashMap, HashSet};

/// Unicode blocks of GB18030 L1: CJK URO and Ext A.
const L1_BLOCKS: &[(u32, u32)] = &[(0x4E00, 0x9FFF), (0x3400, 0x4DBF)];

/// Blocks added beyond L1 to reach the full (L3) set: Ext B, Ext C-F, Kangxi radicals,
/// CJK radicals supplement.
const EXT_BLOCKS: &[(u32, u32)] = &[
    (0x20000, 0x2A6DF),
    (0x2A700, 0x2EBEF),
    (0x2F00, 0x2FD5),
    (0x2E80, 0x2EFF),
];

#[derive(Clone, Debug, Default)]
pub struct Target {
    cps: HashSet<Cp>,
}

impl Target {
    pub fn empty() -> Self {
        Self::default()
    }

    pub fn from_cps(cps: impl IntoIterator<Item = Cp>) -> Self {
        Self {
            cps: cps.into_iter().collect(),
        }
    }

    pub fn demo() -> Self {
        Self::from_cps(
            [
                // few shared components (atomic), heavily reused below
                0x53e3, 0x6728, 0x65e5, 0x7acb, 0x5fc3, 0x706b, 0x56d7, 0x5341,
                // compositions: deep reuse chains and varied operators (enclosure, stacks)
                0x5405, 0x54c1, 0x55bf, 0x566a, 0x35ca, 0x6797, 0x68ee, 0x674f, 0x5446, 0x56f0,
                0x56de, 0x7530, 0x708e, 0x708f, 0x7131, 0x97f3, 0x610f, 0x6697, 0x660c, 0x5531,
                0x65e9, 0x7ae0,
            ]
            .into_iter()
            .map(Cp),
        )
    }

    /// GB18030 L1: CJK URO and Ext A, intersected with codepoints the `db` can decompose.
    pub fn gb18030_l1(db: &Db) -> Self {
        Self::in_blocks(db, L1_BLOCKS)
    }

    /// GB18030 full (L3): L1 plus Ext B-F, Kangxi radicals, and radicals supplement.
    pub fn gb18030_full(db: &Db) -> Self {
        let full: Vec<(u32, u32)> = L1_BLOCKS.iter().chain(EXT_BLOCKS).copied().collect();
        Self::in_blocks(db, &full)
    }

    fn in_blocks(db: &Db, blocks: &[(u32, u32)]) -> Self {
        db.ids
            .keys()
            .copied()
            .filter(|cp| blocks.iter().any(|&(lo, hi)| (lo..=hi).contains(&cp.0)))
            .collect()
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

    pub fn iter(&self) -> impl Iterator<Item = Cp> + '_ {
        self.cps.iter().copied()
    }
}

impl FromIterator<Cp> for Target {
    fn from_iter<T: IntoIterator<Item = Cp>>(iter: T) -> Self {
        Self::from_cps(iter)
    }
}

/// Undesigned codepoints of the target closure.
pub fn candidates<'a>(d: &'a Designed, db: &'a Db, t: &'a Target) -> impl Iterator<Item = Cp> + 'a {
    bfs(t.iter(), down(db))
        .into_iter()
        .filter(|cp| !d.contains(*cp))
}

const COMPOSE_COST: u32 = 1;
pub const DRAW_COST: u32 = 5;

/// Live greedy state over a target.
#[derive(Clone, Debug)]
pub struct Cover {
    designed: Designed,
    order: Vec<Cp>,
    need: HashMap<Cp, usize>,
    blocked: HashSet<Cp>,
    value: HashMap<Cp, usize>,
}

impl Cover {
    pub fn new(db: &Db, t: &Target) -> Self {
        let mut order: Vec<Cp> = bfs(t.iter(), down(db)).into_iter().collect();
        order.sort();

        let mut need = HashMap::new();
        let mut blocked = HashSet::new();
        for &cp in &order {
            if let Some(tree @ IdsTree::Op(_, _)) = db.ids.get(&cp) {
                if tree.has_unresolved() {
                    blocked.insert(cp);
                }
                need.insert(cp, distinct_leaves(tree).count());
            }
        }

        let mut value: HashMap<Cp, usize> = order.iter().map(|&cp| (cp, 0)).collect();
        for target in t.iter() {
            bump_closure(target, db, &mut value, true);
        }

        Self {
            designed: Designed::new(),
            order,
            need,
            blocked,
            value,
        }
    }

    pub fn designed(&self) -> &Designed {
        &self.designed
    }

    pub fn cost(&self, cp: Cp, db: &Db) -> u32 {
        if self.composable(cp, db) {
            COMPOSE_COST
        } else {
            DRAW_COST
        }
    }

    pub fn frontier(&self, db: &Db) -> Vec<(Cp, f32)> {
        let mut ranked: Vec<_> = self.makeable_scored(db).collect();
        ranked.sort_by(|a, b| b.1.total_cmp(&a.1).then(a.0.cmp(&b.0)));
        ranked
    }

    /// Make `cp` (draw or compose), update reach, and return the effort paid.
    pub fn make(&mut self, cp: Cp, db: &Db, t: &Target) -> u32 {
        if self.designed.contains(cp) {
            return 0;
        }

        let cost = self.cost(cp, db);
        self.designed.insert(cp);

        if t.contains(cp) {
            bump_closure(cp, db, &mut self.value, false);
        }

        for &parent in db.parents.get(&cp).into_iter().flatten() {
            if let Some(n) = self.need.get_mut(&parent) {
                *n = n.saturating_sub(1);
            }
        }

        cost
    }

    pub fn coverage(&self, t: &Target) -> f32 {
        if t.is_empty() {
            return 1.0;
        }
        t.iter().filter(|&cp| self.designed.contains(cp)).count() as f32 / t.len() as f32
    }

    pub fn is_made(&self, cp: Cp) -> bool {
        self.designed.contains(cp)
    }

    fn composable(&self, cp: Cp, db: &Db) -> bool {
        !self.designed.contains(cp)
            && matches!(db.ids.get(&cp), Some(IdsTree::Op(_, _)))
            && !self.blocked.contains(&cp)
            && self.need.get(&cp).is_some_and(|&n| n == 0)
    }

    fn makeable(&self, cp: Cp, db: &Db) -> bool {
        !self.designed.contains(cp) && (designable(cp, db) || self.composable(cp, db))
    }

    fn score(&self, cp: Cp, db: &Db) -> f32 {
        self.value.get(&cp).copied().unwrap_or(0) as f32 / self.cost(cp, db) as f32
    }

    /// Makeable, not-yet-made nodes paired with their `value / cost` score.
    fn makeable_scored<'a>(&'a self, db: &'a Db) -> impl Iterator<Item = (Cp, f32)> + 'a {
        self.order
            .iter()
            .copied()
            .filter(move |&cp| self.makeable(cp, db))
            .map(move |cp| (cp, self.score(cp, db)))
    }

    fn best(&self, db: &Db) -> Option<Cp> {
        self.makeable_scored(db)
            .max_by(|a, b| a.1.total_cmp(&b.1).then(b.0.cmp(&a.0)))
            .map(|(cp, _)| cp)
    }

    fn walk_with(
        &mut self,
        db: &Db,
        t: &Target,
        mut pick: impl FnMut(&Self, &Db) -> Option<Cp>,
    ) -> Vec<(u32, f32)> {
        let total = t.len();
        if total == 0 {
            return Vec::new();
        }
        let mut effort = 0;
        let mut covered = 0;
        let mut out = Vec::new();
        while covered < total {
            let Some(cp) = pick(self, db) else {
                break;
            };
            effort += self.make(cp, db, t);
            if t.contains(cp) {
                covered += 1;
            }
            out.push((effort, covered as f32 / total as f32));
        }
        out
    }

    fn walk_best(&mut self, db: &Db, t: &Target) -> Vec<(u32, f32)> {
        self.walk_with(db, t, |s, db| s.best(db))
    }

    fn walk_random_inner(&mut self, db: &Db, t: &Target, seed: u64) -> Vec<(u32, f32)> {
        let mut rng = seed;
        self.walk_with(db, t, move |s, db| {
            let makeable: Vec<Cp> = s
                .order
                .iter()
                .copied()
                .filter(|&cp| s.makeable(cp, db))
                .collect();
            (!makeable.is_empty())
                .then(|| makeable[(lcg(&mut rng) % makeable.len() as u64) as usize])
        })
    }
}

/// Add one (`up`) or subtract one from `value` for every node in `seed`'s down-closure.
fn bump_closure(seed: Cp, db: &Db, value: &mut HashMap<Cp, usize>, up: bool) {
    for cp in bfs([seed], down(db)) {
        if let Some(v) = value.get_mut(&cp) {
            *v = if up { *v + 1 } else { v.saturating_sub(1) };
        }
    }
}

fn lcg(seed: &mut u64) -> u64 {
    *seed = seed
        .wrapping_mul(6364136223846793005)
        .wrapping_add(1442695040888963407);
    *seed
}

pub fn walk(db: &Db, t: &Target) -> Vec<(u32, f32)> {
    Cover::new(db, t).walk_best(db, t)
}

pub fn walk_random(db: &Db, t: &Target, seed: u64) -> Vec<(u32, f32)> {
    Cover::new(db, t).walk_random_inner(db, t, seed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ids::{load_ids, Db, Designed};
    use std::collections::HashSet;

    #[test]
    fn candidates_walk_deep_closure() {
        let db = load_ids("U+0041\tA\t⿰XB\nU+0042\tB\t⿱YZ\n".as_bytes());
        let t = Target::from_cps([Cp('A' as u32), Cp('B' as u32)]);

        let space: HashSet<Cp> = candidates(&Designed::new(), &db, &t).collect();
        for c in ['A', 'B', 'X', 'Y', 'Z'] {
            assert!(space.contains(&Cp(c as u32)), "{c} missing from candidates");
        }
    }

    #[test]
    fn cover_does_not_auto_make_zero_need_composite() {
        let db = load_ids("U+0054\tT\t⿰㇀㇁\n".as_bytes());
        let t = Target::from_cps([Cp(0x54)]);
        let cover = Cover::new(&db, &t);

        assert_eq!(cover.coverage(&t), 0.0);
        assert!(!cover.is_made(Cp(0x54)));
        assert_eq!(cover.frontier(&db), vec![(Cp(0x54), 1.0)]);
    }

    #[test]
    fn cover_make_reveals_composable_parents() {
        let db = load_ids("U+0041\tA\t⿰BC\n".as_bytes());
        let t = Target::from_cps([Cp(0x41)]);
        let mut cover = Cover::new(&db, &t);

        assert_eq!(cover.cost(Cp(0x42), &db), 5);
        assert_eq!(cover.cost(Cp(0x43), &db), 5);
        assert!(!cover.frontier(&db).iter().any(|(cp, _)| *cp == Cp(0x41)));

        assert_eq!(cover.make(Cp(0x42), &db, &t), 5);
        assert_eq!(cover.cost(Cp(0x41), &db), 5); // A still waits on C

        assert_eq!(cover.make(Cp(0x43), &db, &t), 5);
        assert_eq!(cover.cost(Cp(0x41), &db), 1); // A is now composable
    }

    #[test]
    fn cover_walk_composes_to_full_coverage() {
        let db = load_ids("U+0041\tA\t⿰BC\nU+0042\tB\t⿱XY\nU+0043\tC\t⿱YZ\n".as_bytes());
        let t = Target::from_cps([Cp('A' as u32), Cp('B' as u32), Cp('C' as u32)]);
        let path = walk(&db, &t);

        assert_eq!(path.last().map(|(_, coverage)| *coverage), Some(1.0));
    }

    #[test]
    fn cover_walk_demo_reaches_full_coverage() {
        let db = Db::from_ids_file("../refs/IDS.TXT").unwrap();
        let path = walk(&db, &Target::demo());

        assert_eq!(path.last().map(|(_, coverage)| *coverage), Some(1.0));
    }

    #[test]
    fn random_walk_is_deterministic() {
        let db = load_ids("U+0041\tA\t⿰BC\n".as_bytes());
        let t = Target::from_cps([Cp(0x41)]);

        assert_eq!(walk_random(&db, &t, 7), walk_random(&db, &t, 7));
    }

    #[test]
    fn gb18030_targets_intersect_ids_data() {
        let db = load_ids("U+4E00\t一\t一\nU+0041\tA\t⿰木木\n".as_bytes());
        let l1 = Target::gb18030_l1(&db);
        assert!(l1.contains(Cp(0x4e00)));
        assert!(!l1.contains(Cp(0x41)));
        let full = Target::gb18030_full(&db);
        assert!(full.contains(Cp(0x4e00)));
    }
}
