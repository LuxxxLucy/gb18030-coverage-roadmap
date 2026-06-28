use crate::Cp;
use std::collections::HashMap;
use std::io::Read;

pub const N: usize = 128;
const LEN: usize = N * N;

/// Square grayscale glyph image, row-major NxN, one antialiased coverage byte per pixel.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GlyphImage(Box<[u8; LEN]>);

impl Default for GlyphImage {
    fn default() -> Self {
        Self(Box::new([0u8; LEN]))
    }
}

impl GlyphImage {
    pub fn pixels(&self) -> &[u8; LEN] {
        &self.0
    }

    pub fn set(&mut self, x: usize, y: usize, v: u8) {
        self.0[y * N + x] = v;
    }

    pub fn is_empty(&self) -> bool {
        self.0.iter().all(|&p| p == 0)
    }

    /// Image-similarity in [0,1]: `1 - sqrt(mean((a-b)^2)) / 255`, normalized L2 distance.
    pub fn similarity(&self, other: &GlyphImage) -> f32 {
        let sse: f64 = self
            .0
            .iter()
            .zip(other.0.iter())
            .map(|(&a, &b)| {
                let d = a as f64 - b as f64;
                d * d
            })
            .sum();
        let rmse = (sse / LEN as f64).sqrt();
        1.0 - (rmse / 255.0) as f32
    }
}

/// Binary glyph table: repeated records of `[cp: u32 little-endian][N*N u8 pixels]`.
pub fn load_glyphs<R: Read>(mut reader: R) -> HashMap<Cp, GlyphImage> {
    let mut bytes = Vec::new();
    if reader.read_to_end(&mut bytes).is_err() {
        return HashMap::new();
    }
    let record = 4 + LEN;
    if bytes.len() % record != 0 {
        return HashMap::new(); // truncated / corrupt: reject rather than mis-parse
    }
    let mut out = HashMap::new();
    for chunk in bytes.chunks_exact(record) {
        let cp = u32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
        let mut img = GlyphImage::default();
        img.0.copy_from_slice(&chunk[4..]);
        out.insert(Cp(cp), img);
    }
    out
}

/// Serialize a glyph table to the binary record layout, codepoints ascending.
pub fn dump_glyphs(glyphs: &HashMap<Cp, GlyphImage>) -> Vec<u8> {
    let mut cps: Vec<&Cp> = glyphs.keys().collect();
    cps.sort();
    let mut out = Vec::with_capacity(cps.len() * (4 + LEN));
    for cp in cps {
        out.extend_from_slice(&cp.0.to_le_bytes());
        out.extend_from_slice(glyphs[cp].pixels());
    }
    out
}

/// Read `U+XXXX <freq>` lines into a frequency table.
pub fn load_freq<R: Read>(reader: R) -> HashMap<Cp, f32> {
    use std::io::{BufRead, BufReader};
    let mut out = HashMap::new();
    for line in BufReader::new(reader).lines().map_while(Result::ok) {
        let mut fields = line.split_whitespace();
        let (Some(cp), Some(freq)) = (
            fields.next().and_then(crate::parse_codepoint),
            fields.next().and_then(|f| f.parse().ok()),
        ) else {
            continue;
        };
        out.insert(cp, freq);
    }
    out
}

#[cfg(feature = "render")]
pub use render::render_glyph;

#[cfg(feature = "render")]
mod render {
    use super::{GlyphImage, N};

    /// Rasterize `cp` from `font` into an NxN image sharing one em-box frame across all glyphs:
    /// the font is scaled so one em spans N pixels, and each glyph's tight bitmap is offset by its
    /// bearing (`xmin`) and baseline (`ymin`, `height`, ascent) so a shape's position is its real
    /// position in the em, not the bitmap origin. So an L2 distance measures shape, not placement.
    /// `None` for uncovered glyphs and glyphs falling wholly outside the field.
    pub fn render_glyph(font: &fontdue::Font, cp: u32) -> Option<GlyphImage> {
        let ch = char::from_u32(cp)?;
        if font.lookup_glyph_index(ch) == 0 {
            return None;
        }
        let (m, coverage) = font.rasterize(ch, N as f32);
        let ascent = font
            .horizontal_line_metrics(N as f32)
            .map_or(N as f32, |lm| lm.ascent)
            .round() as i32;
        let (ox, oy) = (m.xmin, ascent - (m.ymin + m.height as i32));
        let mut img = GlyphImage::default();
        for (i, &px) in coverage.iter().enumerate() {
            let (x, y) = (ox + (i % m.width) as i32, oy + (i / m.width) as i32);
            if (0..N as i32).contains(&x) && (0..N as i32).contains(&y) {
                img.set(x as usize, y as usize, px);
            }
        }
        (!img.is_empty()).then_some(img)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn solid(v: u8) -> GlyphImage {
        let mut g = GlyphImage::default();
        for y in 0..N {
            for x in 0..N {
                g.set(x, y, v);
            }
        }
        g
    }

    #[test]
    fn similarity_identical_different_partial() {
        let a = solid(255);
        assert_eq!(a.similarity(&a), 1.0);

        // black vs white: maximally different, similarity 0.
        let black = GlyphImage::default();
        assert!((black.similarity(&a) - 0.0).abs() < 1e-6);

        // partial overlap is monotone: a half-gray image sits between identical and opposite.
        let gray = solid(128);
        let near = gray.similarity(&solid(120));
        let far = gray.similarity(&solid(0));
        assert!(near > far);
        assert!(near < 1.0 && far < near);
    }

    #[test]
    fn empty_pair_is_one() {
        let e = GlyphImage::default();
        assert_eq!(e.similarity(&e), 1.0);
    }

    #[test]
    fn binary_round_trip() {
        let mut table = HashMap::new();
        table.insert(Cp(0x4e00), solid(200));
        table.insert(Cp(0x4e8c), solid(50));
        let bytes = dump_glyphs(&table);
        assert_eq!(bytes.len(), 2 * (4 + N * N));
        assert_eq!(load_glyphs(bytes.as_slice()), table);
    }

    #[test]
    fn truncated_file_is_rejected() {
        let mut table = HashMap::new();
        table.insert(Cp(0x4e00), solid(200));
        let mut bytes = dump_glyphs(&table);
        bytes.pop(); // one short of a whole record
        assert!(load_glyphs(bytes.as_slice()).is_empty());
        assert!(load_glyphs([0u8; 5].as_slice()).is_empty()); // odd length
    }

    /// The em-box frame is shared: a wide short glyph (一) and a tall narrow one (丨) both land
    /// centered in the field, not slammed into the top-left corner, so an L2 distance between any
    /// two glyphs reflects shape rather than where fontdue's tight bitmap happened to start.
    #[cfg(feature = "render")]
    #[test]
    fn glyphs_share_one_frame() {
        let path = std::path::Path::new("../refs/font.ttf");
        if !path.exists() {
            return;
        }
        let bytes = std::fs::read(path).unwrap();
        let font =
            fontdue::Font::from_bytes(bytes.as_slice(), fontdue::FontSettings::default()).unwrap();
        let one = render_glyph(&font, 0x4e00).expect("一"); // horizontal stroke
        let gun = render_glyph(&font, 0x4e28).expect("丨"); // vertical stroke

        // ink centroid of each glyph
        let centroid = |g: &GlyphImage| {
            let (mut sx, mut sy, mut w) = (0f64, 0f64, 0f64);
            for (i, &p) in g.pixels().iter().enumerate() {
                let p = p as f64;
                sx += (i % N) as f64 * p;
                sy += (i / N) as f64 * p;
                w += p;
            }
            (sx / w, sy / w)
        };
        let (ox, oy) = centroid(&one);
        let (gx, gy) = centroid(&gun);
        // 一 sits on the baseline (lower half); 丨 spans the column (mid-field). Both well inside
        // the field, neither pinned to the corner.
        for (cx, cy) in [(ox, oy), (gx, gy)] {
            assert!(cx > 8.0 && cx < (N - 8) as f64, "x centroid {cx} near edge");
            assert!(cy > 8.0 && cy < (N - 8) as f64, "y centroid {cy} near edge");
        }
        // Distinct strokes render to distinct images in the shared frame.
        assert!(one.similarity(&gun) < 1.0);
    }
}
