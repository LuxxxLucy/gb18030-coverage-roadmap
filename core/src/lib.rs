//! Coverage core for GB18030: a greedy cover over IDS decompositions.
//!
//! `ids` carries the IDS representation, parsing, structural queries, and reachability.
//! `cover` carries the greedy algorithm and its target set. This file is the public facade.

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct Cp(pub u32);

mod cover;
mod ids;

pub use cover::{candidates, walk, walk_random, Cover, Target, DRAW_COST};
pub use ids::{
    designable, load_ids, parse_codepoint, parse_ids, reachable, state, target_graph, unlocks, Db,
    Designed, GraphEdge, GraphNode, Idc, IdsTree, Reach, State,
};
