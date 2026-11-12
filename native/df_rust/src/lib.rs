//! df_rust — нативная логика DroneFlames Reborn (Reborn Team).
//!
//! 1) DfFlyingCandy — «Летающая конфетка»: пасхальный бонусный объект.
//!    Траектория, покачивание, отрисовка и hit-точка целиком на Rust;
//!    при отсутствии .dll/.so игра использует GDScript-фолбэк
//!    (game/flying_candy_gd.gd) — отказоустойчивость прежде всего.
//! 2) DfSpatialHash2D — пространственная сетка (spatial hash) для быстрых
//!    запросов «ближайшая цель»: фундамент для переноса горячих циклов
//!    (ПВО/артиллерия) из GDScript в Rust.

use godot::classes::{INode2D, IRefCounted, Node2D, RefCounted};
use godot::prelude::*;

use std::collections::HashMap;

struct DfRust;

#[gdextension]
unsafe impl ExtensionLibrary for DfRust {}

// ---------------------------------------------------------------------------
// Летающая конфетка
// ---------------------------------------------------------------------------

const CANDY_RX: f32 = 13.5;
const CANDY_RY: f32 = 8.5;

#[derive(GodotClass)]
#[class(base = Node2D)]
pub struct DfFlyingCandy {
    #[var]
    start: Vector2,
    #[var]
    end: Vector2,
    #[var]
    height: f32,
    #[var]
    duration: f64,
    #[var]
    phase: f64,
    vis_t: f64,
    finished: bool,
    base: Base<Node2D>,
}

#[godot_api]
impl INode2D for DfFlyingCandy {
    fn init(base: Base<Node2D>) -> Self {
        Self {
            start: Vector2::ZERO,
            end: Vector2::ZERO,
            height: 14.0,
            duration: 16.0,
            phase: 0.0,
            vis_t: 0.0,
            finished: false,
            base,
        }
    }

    fn ready(&mut self) {
        self.base_mut().set_z_index(60);
    }

    fn process(&mut self, delta: f64) {
        let ts: f64 = self
            .base()
            .get_parent()
            .map(|p| p.get("time_scale").try_to::<f64>().unwrap_or(1.0))
            .unwrap_or(1.0);
        self.vis_t += delta * ts;

        if self.vis_t > self.duration + 0.6 {
            self.finished = true;
            let mut b = self.base_mut();
            b.queue_free();
            return;
        }

        let k = (self.vis_t / self.duration).clamp(0.0, 1.0);
        let pos = self.path_point(k);
        let bob = (self.vis_t * 2.4 + self.phase).sin() as f32 * 1.8;
        let px = pos.x;
        let py = pos.y + bob - self.height;
        let mut b = self.base_mut();
        b.set_position(Vector2::new(px, py));
        b.queue_redraw();
    }

    fn draw(&mut self) {
        let t = self.vis_t;
        let tilt = (t * 1.7 + self.phase).sin() as f32 * 0.12;
        let h = self.height;

        // Тень на земле (как у авиации: смещение на высоту).
        self.ellipse(Vector2::new(h * 0.9, h * 0.9), 10.0, 4.0, 0.0, Color::from_rgba(0.0, 0.0, 0.0, 0.18));

        // Фантики-обёртки по краям (трепещут).
        let flutter = (t * 7.0 + self.phase).sin() as f32 * 0.22;
        self.wrapper(-1.0, flutter);
        self.wrapper(1.0, -flutter);

        // Тело конфеты + белые полосы + блик.
        self.ellipse(Vector2::ZERO, CANDY_RX, CANDY_RY, tilt, Color::from_rgba(1.0, 0.55, 0.72, 1.0));
        self.band(-6.0, -2.2, tilt, Color::from_rgba(1.0, 1.0, 1.0, 0.92));
        self.band(2.2, 6.0, tilt, Color::from_rgba(1.0, 1.0, 1.0, 0.92));
        self.ellipse(Vector2::new(-4.0, -3.0), 3.6, 2.2, tilt, Color::from_rgba(1.0, 1.0, 1.0, 0.55));
    }
}

#[godot_api]
impl DfFlyingCandy {
    /// Чистая математика пути (для паритет-теста с GDScript-фолбэком).
    #[func]
    pub fn path_point(&self, k: f64) -> Vector2 {
        let k = k.clamp(0.0, 1.0) as f32;
        self.start.lerp(self.end, k)
    }

    /// Мировая точка центра конфеты (для клика менеджером).
    #[func]
    pub fn visual_world_pos(&self) -> Vector2 {
        self.base().get_position() + Vector2::new(0.0, self.height)
    }

    #[func]
    pub fn flight_done(&self) -> bool {
        self.finished
    }

    fn ellipse(&mut self, at: Vector2, rx: f32, ry: f32, rot: f32, col: Color) {
        let n = 26;
        let mut pts = PackedVector2Array::new();
        for i in 0..n {
            let a = std::f32::consts::TAU * (i as f32) / (n as f32);
            let p = Vector2::new(at.x + rx * a.cos(), at.y + ry * a.sin());
            pts.push(rot_point(p, rot, at));
        }
        self.base_mut().draw_colored_polygon(&pts, col);
    }

    fn band(&mut self, x1: f32, x2: f32, rot: f32, col: Color) {
        // Полоса поперёк тела: пересечение вертикального среза с эллипсом.
        let xa = x1.min(x2).max(-CANDY_RX);
        let xb = x1.max(x2).min(CANDY_RX);
        if xa >= xb {
            return;
        }
        let steps = 8;
        let mut pts: Vec<Vector2> = Vec::with_capacity((steps + 1) * 2);
        for i in 0..=steps {
            let x = xa + (xb - xa) * (i as f32) / (steps as f32);
            let dy = CANDY_RY * (1.0 - (x / CANDY_RX).powi(2)).max(0.0).sqrt();
            pts.push(Vector2::new(x, -dy));
        }
        for i in (0..=steps).rev() {
            let x = xa + (xb - xa) * (i as f32) / (steps as f32);
            let dy = CANDY_RY * (1.0 - (x / CANDY_RX).powi(2)).max(0.0).sqrt();
            pts.push(Vector2::new(x, dy));
        }
        let mut poly = PackedVector2Array::new();
        for p in pts {
            poly.push(rot_point(p, rot, Vector2::ZERO));
        }
        self.base_mut().draw_colored_polygon(&poly, col);
    }

    fn wrapper(&mut self, side: f32, flutter: f32) {
        let tip_x = side * (CANDY_RX - 1.0);
        let spread = 9.0 + flutter * 6.0;
        let dy = 7.0 + flutter * 3.0;
        let gold = Color::from_rgba(1.0, 0.82, 0.35, 1.0);
        let mut pts = PackedVector2Array::new();
        pts.push(Vector2::new(tip_x, 0.0));
        pts.push(Vector2::new(tip_x + side * spread, -dy));
        pts.push(Vector2::new(tip_x + side * spread, dy));
        self.base_mut().draw_colored_polygon(&pts, gold);
        // Зубчики обёртки.
        let mut pts2 = PackedVector2Array::new();
        pts2.push(Vector2::new(tip_x - side * 1.5, 0.0));
        pts2.push(Vector2::new(tip_x + side * spread * 0.45, -dy * 0.45));
        pts2.push(Vector2::new(tip_x + side * spread * 0.45, dy * 0.45));
        self.base_mut().draw_colored_polygon(&pts2, gold);
    }
}

fn rot_point(p: Vector2, rot: f32, around: Vector2) -> Vector2 {
    if rot == 0.0 {
        return p;
    }
    let d = p - around;
    let (s, c) = rot.sin_cos();
    around + Vector2::new(d.x * c - d.y * s, d.x * s + d.y * c)
}

// ---------------------------------------------------------------------------
// Пространственная сетка (spatial hash) — фундамент для горячих запросов
// ---------------------------------------------------------------------------

#[derive(GodotClass)]
#[class(base = RefCounted)]
pub struct DfSpatialHash2D {
    #[var]
    cell: f32,
    items: HashMap<i64, (Vector2, i64)>,
    grid: HashMap<(i32, i32), Vec<i64>>,
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for DfSpatialHash2D {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            cell: 128.0,
            items: HashMap::new(),
            grid: HashMap::new(),
            base,
        }
    }
}

impl DfSpatialHash2D {
    fn key(p: Vector2, cell: f32) -> (i32, i32) {
        ((p.x / cell).floor() as i32, (p.y / cell).floor() as i32)
    }

    fn grid_insert(&mut self, id: i64, p: Vector2) {
        let k = Self::key(p, self.cell);
        self.grid.entry(k).or_default().push(id);
    }
}

#[godot_api]
impl DfSpatialHash2D {
    #[func]
    pub fn setup(&mut self, cell_size: f64) {
        self.cell = if cell_size > 0.0 { cell_size as f32 } else { 128.0 };
        self.items.clear();
        self.grid.clear();
    }

    #[func]
    pub fn clear(&mut self) {
        self.items.clear();
        self.grid.clear();
    }

    #[func]
    pub fn insert(&mut self, id: i64, pos: Vector2, mask: i64) {
        if self.items.contains_key(&id) {
            self.move_item(id, pos);
            self.set_mask(id, mask);
            return;
        }
        self.items.insert(id, (pos, mask));
        self.grid_insert(id, pos);
    }

    #[func]
    pub fn remove(&mut self, id: i64) {
        if let Some((p, _)) = self.items.remove(&id) {
            let k = Self::key(p, self.cell);
            if let Some(v) = self.grid.get_mut(&k) {
                if let Some(idx) = v.iter().position(|x| *x == id) {
                    v.swap_remove(idx);
                }
            }
        }
    }

    #[func]
    pub fn move_item(&mut self, id: i64, pos: Vector2) {
        if !self.items.contains_key(&id) {
            return;
        }
        let old_k = Self::key(self.items[&id].0, self.cell);
        let new_k = Self::key(pos, self.cell);
        if old_k != new_k {
            if let Some(v) = self.grid.get_mut(&old_k) {
                if let Some(idx) = v.iter().position(|x| *x == id) {
                    v.swap_remove(idx);
                }
            }
            self.grid_insert(id, pos);
        }
        self.items.get_mut(&id).unwrap().0 = pos;
    }

    #[func]
    pub fn set_mask(&mut self, id: i64, mask: i64) {
        if let Some(entry) = self.items.get_mut(&id) {
            entry.1 = mask;
        }
    }

    /// Ближайший элемент с (mask & filter) != 0 в радиусе; exclude пропускается.
    /// Возвращает id или -1.
    #[func]
    pub fn nearest(&self, pos: Vector2, radius: f64, filter: i64, exclude: i64) -> i64 {
        let r = radius as f32;
        let r2 = r * r;
        let rings = ((r / self.cell).ceil() as i32).clamp(0, 64);
        let (cx, cy) = Self::key(pos, self.cell);
        let mut best: i64 = -1;
        let mut bd2 = r2;
        for dy in -rings..=rings {
            for dx in -rings..=rings {
                if let Some(v) = self.grid.get(&(cx + dx, cy + dy)) {
                    for id in v {
                        if *id == exclude {
                            continue;
                        }
                        if let Some((p, m)) = self.items.get(id) {
                            if filter != 0 && (m & filter) == 0 {
                                continue;
                            }
                            let d2 = p.distance_squared_to(pos);
                            if d2 < bd2 {
                                bd2 = d2;
                                best = *id;
                            }
                        }
                    }
                }
            }
        }
        best
    }

    #[func]
    pub fn count_in_radius(&self, pos: Vector2, radius: f64, filter: i64) -> i32 {
        let r = radius as f32;
        let r2 = r * r;
        let rings = ((r / self.cell).ceil() as i32).clamp(0, 64);
        let (cx, cy) = Self::key(pos, self.cell);
        let mut n: i32 = 0;
        for dy in -rings..=rings {
            for dx in -rings..=rings {
                if let Some(v) = self.grid.get(&(cx + dx, cy + dy)) {
                    for id in v {
                        if let Some((p, m)) = self.items.get(id) {
                            if filter != 0 && (m & filter) == 0 {
                                continue;
                            }
                            if p.distance_squared_to(pos) <= r2 {
                                n += 1;
                            }
                        }
                    }
                }
            }
        }
        n
    }

    #[func]
    pub fn size(&self) -> i32 {
        self.items.len() as i32
    }
}
