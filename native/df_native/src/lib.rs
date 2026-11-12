// DroneFlames Reborn — нативный ускоритель боевой логики (v2).
//
// Перенос горячих пассов из GDScript в Rust (godot-rust, gdext 0.5.5, api-4-7).
// Всё построено вокруг снапшота живых не-FPV юнитов + пространственной сетки
// (128 px) + дымов. Семантика каждого метода — 1:1 с GDScript-эталоном:
//
//   acquire_one  — юнит-пасс Army._acquire (поиск ближайшей цели);
//   valid_one    — юнит-ветка Army._valid (живость цели проверяет GDScript);
//   smoke_at     — Army.in_smoke (круги операций + армейские эллипсы 16x9);
//   spot_all     — ArmyFire._spot: кто кого видит (юниты + здания, лимит 60,
//                  «прячущиеся» в окопах видны только с 54 px, дым глушит);
//   rockets_step — Army._update_rockets: интегрирование полёта ракет;
//   occupy_candidates — префильтр кандидатов Army.occupy.
//
// Вызовы с «охраной» (grd) и hm == -1 (страна вне 0..63) в натив не попадают —
// их обрабатывает GDScript-путь (полная parity).

use godot::prelude::*;
use std::collections::HashMap;

const GRID_PX: f64 = 128.0;
const BLIND_D2: f64 = 784.0; // 28^2 — «в упор сквозь дым»
const ELL_RX2: f64 = 256.0; // 16^2 — армейский дым
const ELL_RY2: f64 = 81.0; // 9^2
const TRENCH_SPOT_D2: f64 = 2916.0; // 54^2 — окопанная цель видна только вблизи
const RECON_R: f64 = 170.0; // радиус сбоку дрона-разведчика (grow бокса)
const SPOT_LIMIT: i64 = 60; // лимит списка spotted на страну

// Биты flags в push_units.
const F_VEH: i32 = 1;
const F_AIR: i32 = 2;
const F_ENT: i32 = 4;
const F_NOPOST: i32 = 8; // post == null
const F_OPON: i32 = 16;
const F_REINF0: i32 = 32; // reinf == 0
const F_NOTSIEGE: i32 = 64; // state != SIEGE

const OCC_TYPES_MIN: i32 = 1; // Unit.Type.INFANTRY
const OCC_TYPES_MAX: i32 = 4; // Unit.Type.ASSAULT (кандидаты: 1,3,4)

struct UnitRow {
    id: i64,
    x: f64,
    y: f64,
    cid: i64,
    veh: bool,
    air: bool,
    ent: bool,
    nopost: bool,
    op_on: bool,
    reinf0: bool,
    not_siege: bool,
    ty: i32,
}

#[inline]
fn pack(cx: i32, cy: i32) -> i64 {
    ((cx as i64) << 32) | ((cy as i64) as u32 as i64)
}

#[inline]
fn cell_of(v: f64) -> i32 {
    (v / GRID_PX).floor() as i32
}

// Godot wrapf(value, min, max) — точная формула из ядра.
#[inline]
fn wrapf(v: f64, mn: f64, mx: f64) -> f64 {
    let range = mx - mn;
    if range == 0.0 {
        return mn;
    }
    v - range * ((v - mn) / range).floor()
}

#[inline]
fn clampf(v: f64, mn: f64, mx: f64) -> f64 {
    if v < mn {
        mn
    } else if v > mx {
        mx
    } else {
        v
    }
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

impl DfNative {
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

    // Кандидаты в ячейках вокруг точки (радиус r) — по снапшот-сетке.
    fn near_candidates(&self, x: f64, y: f64, r: f64) -> Vec<u32> {
        let mut out = Vec::new();
        let gx0 = cell_of(x - r);
        let gx1 = cell_of(x + r);
        let gy0 = cell_of(y - r);
        let gy1 = cell_of(y + r);
        for cy in gy0..=gy1 {
            for cx in gx0..=gx1 {
                if let Some(bucket) = self.grid.get(&pack(cx, cy)) {
                    out.extend_from_slice(bucket);
                }
            }
        }
        out
    }
}

#[godot_api]
impl DfNative {
    // Обновление таблицы юнитов: только живые, не FPV (так же фильтрует
    // Army._build_grid). Порядок вызова = порядок массива units.
    // flags: биты F_*; types: Unit.Type (int).
    #[func]
    fn push_units(
        &mut self,
        ids: PackedInt32Array,
        xs: PackedFloat32Array,
        ys: PackedFloat32Array,
        countries: PackedInt32Array,
        flags: PackedInt32Array,
        types: PackedInt32Array,
    ) {
        self.units.clear();
        self.id_to_idx.clear();
        self.grid.clear();
        self.gmask.clear();
        let n = ids
            .len()
            .min(xs.len())
            .min(ys.len())
            .min(countries.len())
            .min(flags.len())
            .min(types.len());
        self.units.reserve(n);
        for i in 0..n {
            let id = ids[i] as i64;
            let x = xs[i] as f64;
            let y = ys[i] as f64;
            let cid = countries[i] as i64;
            let fl = flags[i];
            let ty = types[i];
            let idx = self.units.len() as u32;
            self.units.push(UnitRow {
                id,
                x,
                y,
                cid,
                veh: fl & F_VEH != 0,
                air: fl & F_AIR != 0,
                ent: fl & F_ENT != 0,
                nopost: fl & F_NOPOST != 0,
                op_on: fl & F_OPON != 0,
                reinf0: fl & F_REINF0 != 0,
                not_siege: fl & F_NOTSIEGE != 0,
                ty,
            });
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

    // Быстрый нативный поиск цели-юнита. Возвращает id цели или -1.
    // Гарантии caller-сайта (army.gd): hm != -1 (стран < 63), «охрана»
    // отключена, self жив и есть в таблице. -2 — ищущего нет в снапшоте.
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
                        let dx = (o.x as f32) - (ux as f32);
                        let dy = (o.y as f32) - (uy as f32);
                        let d2 = (dx * dx + dy * dy) as f64; // f32, как Vector2.distance_squared_to
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

    // Юнит-ветка Army._valid: живость цели и «охрана» — на стороне GDScript.
    // ux/uy/tx/ty — живые координаты (свежесть 1:1), tc — страна цели,
    // rr — range_of(u) * 1.15. hm != -1 гарантируется caller-ом.
    #[func]
    fn valid_one(&self, ux: f64, uy: f64, tx: f64, ty: f64, tc: i64, rr: f64, hm: i64) -> bool {
        if tc < 0 || tc >= 63 || (hm >> tc) & 1 == 0 {
            return false; // _hostile(u.country_id, tu.country_id)
        }
        let dx = (tx as f32) - (ux as f32);
        let dy = (ty as f32) - (uy as f32);
        let d2 = (dx * dx + dy * dy) as f64; // f32, как Vector2.distance_squared_to
        if d2 > rr * rr {
            return false;
        }
        d2 < BLIND_D2 || !self.in_smoke(tx, ty)
    }

    // Army.in_smoke (круги операций + армейские эллипсы).
    #[func]
    fn smoke_at(&self, x: f64, y: f64) -> bool {
        self.in_smoke(x, y)
    }

    // ArmyFire._spot целиком: возвращает плоский массив
    //   [для каждой страны: n_u, (unit_id, eye_idx)*, n_f, (fac_id, eye_idx)*]
    // в порядке стран из cids. Юниты — в порядке снапшота, здания — в порядке
    // fac_ids; eye_idx — индекс глаза (внутри страны), по которому GDScript
    // восстановит recon-флаг и точку line_point.
    //
    // eyes: группы (x, y, r2, recon) по eye_g_per_country на страну;
    // fac_*: префильтрованные GDScript-ом здания (MIL_KINDS, parent==null,
    // !moving, alive); line_xy — ячейки линий (x, y) с офсетами line_off.
    // naval_n — сколько записей уже добавит naval.spotted_for (для лимита 60).
    #[func]
    fn spot_all(
        &self,
        cids: PackedInt32Array,
        hms: PackedInt64Array,
        eyes: PackedFloat64Array,
        eye_groups_per_country: PackedInt32Array,
        fac_ids: PackedInt32Array,
        fac_cs: PackedInt32Array,
        fac_x: PackedFloat64Array,
        fac_y: PackedFloat64Array,
        fac_ext: PackedFloat64Array,
        fac_flags: PackedInt32Array, // бит0: окоп (is_trench), бит1: линия
        line_off: PackedInt32Array,
        line_xy: PackedFloat64Array,
        naval_n: PackedInt32Array,
    ) -> PackedInt32Array {
        let mut out: Vec<i32> = Vec::with_capacity(64);
        let ncid = cids.len().min(hms.len()).min(eye_groups_per_country.len()).min(naval_n.len());
        let mut eye_base: usize = 0;
        for ci in 0..ncid {
            let cid = cids[ci] as i64;
            let hm = hms[ci];
            let ng = eye_groups_per_country[ci] as usize;
            let naval = naval_n[ci] as i64;
            // бокс: Rect2 по позициям глаз + grow(RECON_R)
            let mut bx0 = f64::INFINITY;
            let mut by0 = f64::INFINITY;
            let mut bx1 = f64::NEG_INFINITY;
            let mut by1 = f64::NEG_INFINITY;
            let eg = eye_base..eye_base + ng;
            for gi in eg.clone() {
                let b = gi * 4;
                let (ex, ey) = (eyes[b], eyes[b + 1]);
                if ex < bx0 {
                    bx0 = ex;
                }
                if ey < by0 {
                    by0 = ey;
                }
                if ex > bx1 {
                    bx1 = ex;
                }
                if ey > by1 {
                    by1 = ey;
                }
            }
            bx0 -= RECON_R;
            by0 -= RECON_R;
            bx1 += RECON_R;
            by1 += RECON_R;

            // ——— юниты: глаза во внешнем цикле, первый подходящий глаз фиксирует
            // recon-флаг (1:1 с GDScript: for o { for e { if ... append; break } })
            let mut best_eye: Vec<i32> = vec![-1; self.units.len()];
            for (ei, gi) in eg.clone().enumerate() {
                let b = gi * 4;
                let (ex, ey, r2, recon) = (eyes[b], eyes[b + 1], eyes[b + 2], eyes[b + 3] != 0.0);
                let rr = r2.sqrt();
                for oi in self.near_candidates(ex, ey, rr) {
                    let oi = oi as usize;
                    if best_eye[oi] >= 0 {
                        continue;
                    }
                    let o = &self.units[oi];
                    if o.air || o.cid == cid {
                        continue;
                    }
                    let foe = if o.cid >= 0 && o.cid < 63 { (hm >> o.cid) & 1 == 1 } else { false };
                    if !foe {
                        continue;
                    }
                    let ox = o.x;
                    let oy = o.y;
                    // Rect2.has_point — полуоткрытый интервал [min, max)
                    if ox < bx0 || ox >= bx1 || oy < by0 || oy >= by1 {
                        continue;
                    }
                    if self.in_smoke(ox, oy) {
                        continue;
                    }
                    // окопанный юнит виден только с TRENCH_SPOT_R (если глаз — не разведчик)
                    let lim = if o.ent && !recon { r2.min(TRENCH_SPOT_D2) } else { r2 };
                    let dx = (ox as f32) - (ex as f32);
                    let dy = (oy as f32) - (ey as f32);
                    let d2 = (dx * dx + dy * dy) as f64; // f32, как Vector2.distance_squared_to
                    if d2 <= lim {
                        best_eye[oi] = ei as i32;
                    }
                }
            }
            let mut n_u: i32 = 0;
            for (oi, o) in self.units.iter().enumerate() {
                let e = best_eye[oi];
                if e >= 0 {
                    out.push(o.id as i32);
                    out.push(e);
                    n_u += 1;
                }
            }

            // ——— здания: порядок fac_ids, лимит 60 учитывает юнитов + naval
            let mut n_f: i32 = 0;
            let mut cnt: i64 = n_u as i64 + naval;
            let nf = fac_ids.len();
            for fi in 0..nf {
                let fc0 = fac_cs[fi] as i64;
                let foe = if fc0 >= 0 && fc0 < 63 { (hm >> fc0) & 1 == 1 } else { false };
                if foe {
                    let fx = fac_x[fi];
                    let fy = fac_y[fi];
                    let ext = fac_ext[fi];
                    let trench = fac_flags[fi] & 1 != 0;
                    let is_line = fac_flags[fi] & 2 != 0;
                    // box.grow(ext).has_point(fc) — полуоткрытый интервал
                    if fx >= bx0 - ext && fx < bx1 + ext && fy >= by0 - ext && fy < by1 + ext {
                        let mut fe: i32 = -1;
                        for (ei, gi) in eg.clone().enumerate() {
                            let b = gi * 4;
                            let (ex, ey, r2, recon) =
                                (eyes[b], eyes[b + 1], eyes[b + 2], eyes[b + 3] != 0.0);
                            let (tpx, tpy) = if is_line {
                                // line_point: ближайшая ячейка линии к точке глаза
                                // (дистанции f32 — как Vector2.distance_squared_to)
                                let lo = line_off[fi] as usize;
                                let hi = line_off[fi + 1] as usize;
                                let mut bd = f64::INFINITY;
                                let mut px = fx;
                                let mut py = fy;
                                for li in lo..hi {
                                    let cx = line_xy[li * 2];
                                    let cy = line_xy[li * 2 + 1];
                                    let ddx = (cx as f32) - (ex as f32);
                                    let ddy = (cy as f32) - (ey as f32);
                                    let dd = ((ddx * ddx + ddy * ddy) as f64);
                                    if dd < bd {
                                        bd = dd;
                                        px = cx;
                                        py = cy;
                                    }
                                }
                                (px, py)
                            } else {
                                (fx, fy)
                            };
                            let lim = if trench && !recon { r2.min(TRENCH_SPOT_D2) } else { r2 };
                            let dx = (tpx as f32) - (ex as f32);
                            let dy = (tpy as f32) - (ey as f32);
                            let d2 = (dx * dx + dy * dy) as f64;
                            if d2 <= lim {
                                fe = ei as i32;
                                break;
                            }
                        }
                        if fe >= 0 {
                            out.push(fi as i32);
                            out.push(fe);
                            n_f += 1;
                            cnt += 1;
                        }
                    }
                }
                if cnt > SPOT_LIMIT {
                    break;
                }
            }
            out.insert(out.len() - ((n_u + n_f) * 2) as usize, n_u);
            out.insert(out.len() - (n_f * 2) as usize, n_f);
            eye_base += ng;
        }
        PackedInt32Array::from(out)
    }

    // Army._update_rockets — интегрирование полёта: разворот к цели, шаг,
    // трейл. status: 0 = летит, 1 = прибыла (to.length() <= step + 2), 2 = жизнь
    // кончилась. Возвращает 8 double на ракету:
    //   [status, heading, pos_x, pos_y, trail, trail_spawn, arr_x, arr_y]
    #[func]
    fn rockets_step(
        &self,
        dt: f64,
        pos_x: PackedFloat64Array,
        pos_y: PackedFloat64Array,
        heading: PackedFloat64Array,
        life: PackedFloat64Array,
        speed: PackedFloat64Array,
        turn_rate: PackedFloat64Array,
        tgt_x: PackedFloat64Array,
        tgt_y: PackedFloat64Array,
        trail: PackedFloat64Array,
    ) -> PackedFloat64Array {
        let n = pos_x
            .len()
            .min(pos_y.len())
            .min(heading.len())
            .min(life.len())
            .min(speed.len())
            .min(turn_rate.len())
            .min(tgt_x.len())
            .min(tgt_y.len())
            .min(trail.len());
        let mut out: Vec<f64> = Vec::with_capacity(n * 8);
        let pi = std::f64::consts::PI;
        for i in 0..n {
            let lf = life[i] - dt;
            if lf <= 0.0 {
                out.push(2.0);
                out.push(heading[i]);
                out.push(pos_x[i]);
                out.push(pos_y[i]);
                out.push(trail[i]);
                out.push(0.0);
                out.push(pos_x[i]);
                out.push(pos_y[i]);
                continue;
            }
            // to = tp - pos; угол цели — как Vector2.angle() (f32 внутри Godot)
            let dx = (tgt_x[i] - pos_x[i]) as f32;
            let dy = (tgt_y[i] - pos_y[i]) as f32;
            let want = (dy as f64).atan2(dx as f64);
            let turn = turn_rate[i] * dt;
            let dh = wrapf(want - heading[i], -pi, pi);
            let nh = wrapf(heading[i] + clampf(dh, -turn, turn), -pi, pi);
            let step = speed[i] * dt;
            let dist = ((dx * dx + dy * dy) as f64).sqrt();
            if dist <= step + 2.0 {
                out.push(1.0);
                out.push(nh);
                out.push(pos_x[i]);
                out.push(pos_y[i]);
                out.push(trail[i]);
                out.push(0.0);
                out.push(tgt_x[i]);
                out.push(tgt_y[i]);
                continue;
            }
            let (vx, vy) = (nh.cos(), nh.sin());
            // Vector2 * float и сложение — f32, как в Godot
            let nx = (pos_x[i] as f32 + (vx as f32) * (step as f32)) as f64;
            let ny = (pos_y[i] as f32 + (vy as f32) * (step as f32)) as f64;
            let mut tr = trail[i] + step;
            let mut spawn = 0.0;
            if tr >= 5.0 {
                tr = 0.0;
                spawn = 1.0;
            }
            out.push(0.0);
            out.push(nh);
            out.push(nx);
            out.push(ny);
            out.push(tr);
            out.push(spawn);
            out.push(tgt_x[i]);
            out.push(tgt_y[i]);
        }
        PackedFloat64Array::from(out)
    }

    // Префильтр кандидатов Army.occupy: страна, жив (по построению снапшота),
    // без поста, тип INFANTRY/ATGM/ASSAULT, не в осаде, не подкрепление.
    // Возвращает [posted, id...], где posted — число юнитов страны с постом
    // (для only == null; иначе GDScript пересчитает сам). Остальные условия
    // (op_on/no_post_until/дистанции) — GDScript.
    #[func]
    fn occupy_candidates(&self, country_id: i64) -> PackedInt32Array {
        let mut out: Vec<i32> = Vec::with_capacity(16);
        let mut posted: i32 = 0;
        for o in &self.units {
            if o.cid != country_id {
                continue;
            }
            if !o.nopost {
                posted += 1;
                continue;
            }
            if o.ty < OCC_TYPES_MIN
                || o.ty > OCC_TYPES_MAX
                || o.ty == 2
                || !o.not_siege
                || !o.reinf0
            {
                continue;
            }
            out.push(o.id as i32);
        }
        let mut all: Vec<i32> = Vec::with_capacity(out.len() + 1);
        all.push(posted);
        all.extend(out);
        PackedInt32Array::from(all)
    }
}

// Точка входа GDExtension (обязана быть экспортирована).
struct DfExtension;

#[gdextension]
unsafe impl ExtensionLibrary for DfExtension {}
