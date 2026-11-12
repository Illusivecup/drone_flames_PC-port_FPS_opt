// DroneFlames Reborn — нативный ускоритель боевой логики.
//
// Перенос горячей части Army._acquire (поиск целей через пространственную
// сетку) из GDScript в Rust. Семантика 1:1:
//   * обход ячеек: cy от gy0 до gy1 (внешний), cx от gx0 до gx1 (внутренний);
//   * внутри ячейки — порядок добавления в сетку (порядок массива units);
//   * строгое улучшение (bd = d2 только при d2 < bd) — при равенстве
//     побеждает первый найденный;
//   * пропуск ячейки целиком, если маска стран ячейки не пересекается с
//     маской враждебных стран ищущего (_gmask/_hmask);
//   * ATGM видит только технику; FPV и мёртвые в сетке отсутствуют;
//   * дым: ищущий в дыму видит только в радиусе 28 px (d2 < 784), цель в
//     дыму не видна (армейские дымы — эллипс 16x9, дымы операций — круг r).
//
// Вызовы с "охраной" (grd) и hm == -1 (страна вне 0..63) в натив не
// попадают — их обрабатывает GDScript-путь (полная parity).

use godot::prelude::*;
use std::collections::HashMap;

const GRID_PX: f64 = 128.0;
const BLIND_D2: f64 = 784.0; // 28^2 — «в упор сквозь дым»
const ELL_RX2: f64 = 256.0; // 16^2 — армейский дым
const ELL_RY2: f64 = 81.0; // 9^2

struct UnitRow {
    id: i64,
    x: f64,
    y: f64,
    cid: i64,
    veh: bool,
}

#[inline]
fn pack(cx: i32, cy: i32) -> i64 {
    ((cx as i64) << 32) | ((cy as i64) as u32 as i64)
}

#[inline]
fn cell_of(v: f64) -> i32 {
    (v / GRID_PX).floor() as i32
}

#[derive(GodotClass)]
#[class(base=Object, init)]
struct DfNative {
    units: Vec<UnitRow>,
    id_to_idx: HashMap<i64, u32>,
    grid: HashMap<i64, Vec<u32>>,
    gmask: HashMap<i64, i64>,
    // дымы: операции (круг x,y,r) и армия (эллипс x,y)
    smoke_circ: Vec<(f64, f64, f64)>,
    smoke_ell: Vec<(f64, f64)>,
}

impl Default for DfNative {
    fn default() -> Self {
        Self {
            units: Vec::with_capacity(1024),
            id_to_idx: HashMap::with_capacity(1024),
            grid: HashMap::with_capacity(256),
            gmask: HashMap::with_capacity(256),
            smoke_circ: Vec::new(),
            smoke_ell: Vec::new(),
        }
    }
}

#[godot_api]
impl DfNative {
    // Обновление таблицы юнитов: только живые, не FPV (так же фильтрует
    // Army._build_grid). Порядок вызова = порядок массива units.
    #[func]
    fn push_units(
        &mut self,
        ids: PackedInt32Array,
        xs: PackedFloat32Array,
        ys: PackedFloat32Array,
        countries: PackedInt32Array,
        vehicles: PackedInt32Array,
    ) {
        self.units.clear();
        self.id_to_idx.clear();
        self.grid.clear();
        self.gmask.clear();
        let n = ids.len().min(xs.len()).min(ys.len()).min(countries.len()).min(vehicles.len());
        self.units.reserve(n);
        for i in 0..n {
            let id = ids[i] as i64;
            let x = xs[i] as f64;
            let y = ys[i] as f64;
            let cid = countries[i] as i64;
            let veh = vehicles[i] != 0;
            let idx = self.units.len() as u32;
            self.units.push(UnitRow { id, x, y, cid, veh });
            self.id_to_idx.insert(id, idx);
            let key = pack(cell_of(x), cell_of(y));
            self.grid.entry(key).or_default().push(idx);
            // маска стран ячейки: cid вне 0..63 => -1 (как в GDScript)
            let add = if cid >= 0 && cid < 63 { 1i64 << cid } else { -1i64 };
            *self.gmask.entry(key).or_insert(0) |= add;
        }
    }

    // Дымы: circles = (x, y, r) * n; ellipses = (x, y) * m.
    #[func]
    fn push_smokes(&mut self, circles: PackedFloat64Array, ellipses: PackedFloat64Array) {
        self.smoke_circ.clear();
        self.smoke_ell.clear();
        let nc = circles.len() / 3;
        for i in 0..nc {
            self.smoke_circ
                .push((circles[i * 3] as f64, circles[i * 3 + 1] as f64, circles[i * 3 + 2] as f64));
        }
        let ne = ellipses.len() / 2;
        for i in 0..ne {
            self.smoke_ell.push((ellipses[i * 2] as f64, ellipses[i * 2 + 1] as f64));
        }
    }

    fn in_smoke(&self, x: f64, y: f64) -> bool {
        for s in &self.smoke_circ {
            let dx = x - s.0;
            let dy = y - s.1;
            if dx * dx + dy * dy <= s.2 * s.2 {
                return true;
            }
        }
        for s in &self.smoke_ell {
            let dx = x - s.0;
            let dy = y - s.1;
            if dx * dx / ELL_RX2 + dy * dy / ELL_RY2 <= 1.0 {
                return true;
            }
        }
        false
    }

    // Быстрый нативный поиск цели-юнита. Возвращает id цели или -1.
    // Гарантии caller-сайта (army.gd): hm != -1 (стран < 63), «охрана»
    // отключена, self жив и есть в таблице.
    #[func]
    fn acquire_one(&mut self, self_id: i64, r: f64, hm: i64, at: bool, blind: bool) -> i64 {
        let si = match self.id_to_idx.get(&self_id) {
            Some(&i) => i as usize,
            None => return -2, // ищущего нет в снапшоте => caller уходит в GDScript
        };
        let (ux, uy, ucid) = {
            let u = &self.units[si];
            (u.x, u.y, u.cid)
        };
        let mut bd = r * r;
        let mut best: i64 = -1;
        let gx0 = cell_of(ux - r);
        let gx1 = cell_of(ux + r);
        let gy0 = cell_of(uy - r);
        let gy1 = cell_of(uy + r);
        for cy in gy0..=gy1 {
            for cx in gx0..=gx1 {
                let key = pack(cx, cy);
                if self.gmask.get(&key).copied().unwrap_or(0) & hm == 0 {
                    continue;
                }
                if let Some(bucket) = self.grid.get(&key) {
                    for &oi in bucket.iter() {
                        let o = &self.units[oi as usize];
                        if o.cid == ucid {
                            continue;
                        }
                        if at && !o.veh {
                            continue;
                        }
                        let dx = o.x - ux;
                        let dy = o.y - uy;
                        let d2 = dx * dx + dy * dy;
                        if d2 >= bd {
                            continue;
                        }
                        let oc = o.cid;
                        // oc вне 0..63 => в GDScript было _hostile() => false
                        // (страна не существует); caller гарантирует hm != -1.
                        let foe = if oc >= 0 && oc < 63 { (hm >> oc) & 1 == 1 } else { false };
                        if foe && (d2 < BLIND_D2 || !(blind || self.in_smoke(o.x, o.y))) {
                            bd = d2;
                            best = o.id;
                        }
                    }
                }
            }
        }
        best
    }
}

// Точка входа GDExtension (обязана быть экспортирована).
struct DfExtension;

#[gdextension]
unsafe impl ExtensionLibrary for DfExtension {}
