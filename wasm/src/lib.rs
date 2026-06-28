use coverage_core::{load_ids, state, target_graph, unlocks, Cover, Cp, Db, Target};
use serde::Serialize;
use wasm_bindgen::prelude::*;

const DEMO_IDS: &str = include_str!("../demo_ids.txt");

#[derive(Serialize)]
struct FrontierEntry {
    cp: u32,
    score: f32,
}

#[derive(Serialize)]
struct TargetState {
    cp: u32,
    state: u8,
}

#[derive(Serialize)]
struct GraphNode {
    cp: u32,
    state: u8,
    layer: usize,
}

#[derive(Serialize)]
struct GraphEdge {
    from_cp: u32,
    to_cp: u32,
}

#[derive(Serialize)]
struct Graph {
    nodes: Vec<GraphNode>,
    edges: Vec<GraphEdge>,
}

#[wasm_bindgen]
pub struct Roadmap {
    db: Db,
    cover: Cover,
    target: Target,
}

#[wasm_bindgen]
impl Roadmap {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        let db = load_ids(DEMO_IDS.as_bytes());
        let target = Target::demo();
        let cover = Cover::new(&db, &target);
        Self { db, cover, target }
    }

    /// Add `codepoint` to the made set so the next frontier reflects the new state.
    pub fn make(&mut self, codepoint: u32) {
        self.cover.make(Cp(codepoint), &self.db, &self.target);
    }

    pub fn frontier(&self) -> Result<JsValue, JsValue> {
        let entries: Vec<FrontierEntry> = self
            .cover
            .frontier(&self.db)
            .into_iter()
            .map(|(cp, score)| FrontierEntry { cp: cp.0, score })
            .collect();
        serde_wasm_bindgen::to_value(&entries).map_err(Into::into)
    }

    pub fn coverage(&self) -> f32 {
        self.cover.coverage(&self.target)
    }

    /// Every target codepoint sorted, tagged 0=locked, 1=reachable, 2=designed.
    pub fn target_states(&self) -> Result<JsValue, JsValue> {
        let mut cps: Vec<Cp> = self.target.iter().collect();
        cps.sort();
        let entries: Vec<TargetState> = cps
            .into_iter()
            .map(|cp| TargetState {
                cp: cp.0,
                state: state(cp, self.cover.designed(), &self.db).code(),
            })
            .collect();
        serde_wasm_bindgen::to_value(&entries).map_err(Into::into)
    }

    /// Codepoints that choosing `codepoint` helps unlock: distinct, not-yet-designed targets that
    /// directly name it as a component, excluding itself.
    pub fn unlocks(&self, codepoint: u32) -> Result<JsValue, JsValue> {
        let out: Vec<u32> = unlocks(&self.db, &self.target, Cp(codepoint), self.cover.designed())
            .into_iter()
            .map(|cp| cp.0)
            .collect();
        serde_wasm_bindgen::to_value(&out).map_err(Into::into)
    }

    /// The merged decomposition DAG of the target set: `{nodes, edges}` over the current state.
    pub fn target_graph(&self) -> Result<JsValue, JsValue> {
        let (nodes, edges) = target_graph(&self.db, &self.target, self.cover.designed());
        let graph = Graph {
            nodes: nodes
                .into_iter()
                .map(|n| GraphNode {
                    cp: n.cp.0,
                    state: n.state,
                    layer: n.layer,
                })
                .collect(),
            edges: edges
                .into_iter()
                .map(|e| GraphEdge {
                    from_cp: e.from.0,
                    to_cp: e.to.0,
                })
                .collect(),
        };
        serde_wasm_bindgen::to_value(&graph).map_err(Into::into)
    }
}

impl Default for Roadmap {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bundled_demo_db_yields_scores_and_full_coverage() {
        let db = load_ids(DEMO_IDS.as_bytes());
        assert!(!db.ids.is_empty());

        let t = Target::demo();
        let cover = Cover::new(&db, &t);
        let frontier = cover.frontier(&db);
        assert!(frontier.iter().any(|&(_, s)| s > 0.0), "no positive score");

        let walk = coverage_core::walk(&db, &Target::demo());
        assert_eq!(walk.last().map(|&(_, c)| c), Some(1.0));
    }
}
