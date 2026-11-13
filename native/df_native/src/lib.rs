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
use std::collections::{HashMap, HashSet};

const GRID_PX: f64 = 128.0;
const BLIND_D2: f64 = 784.0; // 28^2 — «в упор сквозь дым»
const ELL_RX2: f64 = 256.0; // 16^2 — армейский дым
const ELL_RY2: f64 = 81.0; // 9^2
const TRENCH_SPOT_D2: f64 = 2916.0; // 54^2 — окопанная цель видна только вблизи
const RECON_R: f64 = 170.0; // радиус сбоку дрона-разведчика (grow бокса)
const SPOT_R: f64 = 120.0; // v4: базовый радиус глаза-юнита (ArmyFire.SPOT_R)
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

// v4: бит flags «окопан или вырылся» (u.entrenched || u.dug) — для радиуса
// глаз разведки (SPOT_R * 1.3). Не путать с F_ENT (только entrenched).
const F_DUG: i32 = 128;

struct UnitRow {
    id: i64,
    x: f64,
    y: f64,
    cid: i64,
    veh: bool,
    air: bool,
    ent: bool,
    dug: bool,
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

// Hash32 (GDScript core/hash32.gd) — побитовая копия, нужна для
// детерминированных ролей боя (fire_cd, попадания, промахи, fx).
const M32: u32 = 0xFFFF_FFFF;

#[inline]
fn mix32(v: u32) -> u32 {
    let mut x = v;
    x ^= x >> 16;
    x = x.wrapping_mul(2_146_121_005);
    x ^= x >> 15;
    x = x.wrapping_mul(739_982_445);
    x ^= x >> 16;
    x
}

// Hash32.h2(x, y, s): mix(((x & 65535) | ((y & 65535) << 16) ^ mix(s & M32)) & M32)
#[inline]
fn h2_32(x: i64, y: i64, s: i64) -> u32 {
    let lo = ((x & 0xFFFF) | ((y & 0xFFFF) << 16)) as u32;
    mix32((lo ^ mix32(s as u32)) as u32)
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
    // v3: мир для wd-пассов ( Operations._wd_sweep ) — сетки заблокированных
    // (вода без моста) ячеек и владельцев территории, w*h, Cell = 4 px.
    wd_w: usize,
    wd_h: usize,
    wd_blocked: Vec<u8>,
    wd_owner: Vec<u8>,
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
            wd_w: 0,
            wd_h: 0,
            wd_blocked: Vec::new(),
            wd_owner: Vec::new(),
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

    // Владелец ячейки (v3): -1 вне карты — семантика operations._owner_at.
    fn wd_owner_at(&self, cx: i32, cy: i32) -> i64 {
        if self.wd_w == 0 || cx < 0 || cy < 0 {
            return -1;
        }
        let (w, h) = (self.wd_w, self.wd_h);
        if (cx as usize) >= w || (cy as usize) >= h {
            return -1;
        }
        self.wd_owner[(cy as usize) * w + (cx as usize)] as i64
    }

    // Ячейка «вода без моста» (v3) — эквивалент
    // Biome.is_water(...) and not has_flag(..., F_BRIDGE).
    fn wd_cell_blocked(&self, cx: i32, cy: i32) -> bool {
        if self.wd_w == 0 || cx < 0 || cy < 0 {
            return false;
        }
        let (w, h) = (self.wd_w, self.wd_h);
        if (cx as usize) >= w || (cy as usize) >= h {
            return false;
        }
        self.wd_blocked[(cy as usize) * w + (cx as usize)] != 0
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
                dug: fl & F_DUG != 0,
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
        self.acq_search(si, r, hm, at, blind)
    }

    // v4: тело поиска цели-юнита (общее для acquire_one и acquire_batch).
    // si — индекс ищущего в снапшоте. Семантика 1:1 с acquire_one.
    fn acq_search(&self, si: usize, r: f64, hm: i64, at: bool, blind: bool) -> i64 {
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

    // v4: батч-валидация текущей цели + батч-поиск новой. Один вызов заменяет
    // до ~2×N вызовов acquire_one/valid_one за scan-тик.
    //
    // Ряды (все массивы одной длины, порядок = порядок юнит-цикла):
    //   ids      — id ищущего (есть в снапшоте);
    //   rngs     — range_of(u)       (радиус поиска, как acquire_one);
    //   rvs      — range_of(u)*1.15  (радиус валидации, как valid_one);
    //   hms      — маска враждебности (hm != -1 гарантируется GDScript);
    //   ats      — флаг «только машины» (ATGM);
    //   blinds   — ищущий сам в дыму;
    //   cur_ids  — id текущей цели-юнита или -1;
    //   srch     — 1 = искать новую, если текущая невалидна/отсутствует
    //              (чётные/нечётные id — как стаггеринг _acquire).
    //
    // Ответ на ряд: >=0 — id (сохранённой или новой) цели; -1 — юнита-цели нет
    // (GDScript чистит цель и пробует здания на своей стороне); -2 — ищущего
    // нет в снапшоте (GDScript уходит в полный _acquire).
    #[func]
    fn acquire_batch(
        &self,
        ids: PackedInt32Array,
        rngs: PackedFloat64Array,
        rvs: PackedFloat64Array,
        hms: PackedInt64Array,
        ats: PackedInt32Array,
        blinds: PackedInt32Array,
        cur_ids: PackedInt32Array,
        srch: PackedInt32Array,
    ) -> PackedInt64Array {
        let n = ids
            .len()
            .min(rngs.len())
            .min(rvs.len())
            .min(hms.len())
            .min(ats.len())
            .min(blinds.len())
            .min(cur_ids.len())
            .min(srch.len());
        let mut out: Vec<i64> = Vec::with_capacity(n);
        for i in 0..n {
            let sid = ids[i] as i64;
            let r = rngs[i];
            let rv = rvs[i];
            let hm = hms[i];
            let at = ats[i] != 0;
            let blind = blinds[i] != 0;
            let cur = cur_ids[i] as i64;
            let search = srch[i] != 0;
            let si = match self.id_to_idx.get(&sid) {
                Some(&x) => x as usize,
                None => {
                    out.push(-2);
                    continue;
                }
            };
            // ——— 1) валидация текущей цели (семантика valid_one) ———
            let mut kept = false;
            if cur >= 0 {
                if let Some(&ti) = self.id_to_idx.get(&cur) {
                    let t = &self.units[ti as usize];
                    let tc = t.cid;
                    let foe = tc >= 0 && tc < 63 && (hm >> tc) & 1 == 1;
                    if foe {
                        let dx = (t.x as f32) - (self.units[si].x as f32);
                        let dy = (t.y as f32) - (self.units[si].y as f32);
                        let d2 = (dx * dx + dy * dy) as f64; // f32-дистанция
                        if d2 <= rv * rv && (d2 < BLIND_D2 || !self.in_smoke(t.x, t.y)) {
                            kept = true;
                        }
                    }
                }
            }
            if kept {
                out.push(cur);
                continue;
            }
            if !search {
                out.push(-1);
                continue;
            }
            // ——— 2) свежий поиск (семантика acquire_one) ———
            out.push(self.acq_search(si, r, hm, at, blind));
        }
        PackedInt64Array::from(out)
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
            // Точная эмуляция Rect2 (f32): expand по глазам, grow(RECON_R).
            // begin/end — точные координаты глаз; size = end - begin (f32);
            // граница has_point — position + size (f32-сложение).
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
            let grow = RECON_R as f32;
            let bpx = (bx0 as f32) - grow; // position после grow
            let bpy = (by0 as f32) - grow;
            let bsx = ((bx1 as f32) - (bx0 as f32)) + grow * 2.0f32; // size после grow
            let bsy = ((by1 as f32) - (by0 as f32)) + grow * 2.0f32;
            let brx = bpx + bsx; // правая/нижняя граница (как has_point)
            let bry = bpy + bsy;

            // ——— юниты: глаза во внешнем цикле, первый подходящий глаз фиксирует
            // recon-флаг (1:1 с GDScript: for o { for e { if ... append; break } })
            let mut best_eye: Vec<i32> = vec![-1; self.units.len()];
            for (ei, gi) in eg.clone().enumerate() {
                let b = gi * 4;
                let (ex, ey, r2, recon) = (eyes[b], eyes[b + 1], eyes[b + 2], eyes[b + 3] != 0.0);
                // супермножество кандидатов: чуть шире точного радиуса (запас
                // на f32-округление дистанции), точный фильтр ниже по f32-d2
                let rr = r2.sqrt() * 1.001 + 1.0;
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
                    // Rect2.has_point — полуоткрытый [min, max), f32-сравнение
                    if (ox as f32) < bpx || (ox as f32) >= brx || (oy as f32) < bpy || (oy as f32) >= bry {
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
                    // box.grow(ext).has_point(fc): второй grow поверх первого,
                    // f32-арифметика, полуоткрытый интервал
                    let fpx = bpx - (ext as f32);
                    let fpy = bpy - (ext as f32);
                    let fsx = bsx + (ext as f32) * 2.0f32;
                    let fsy = bsy + (ext as f32) * 2.0f32;
                    if (fx as f32) >= fpx && (fx as f32) < fpx + fsx && (fy as f32) >= fpy && (fy as f32) < fpy + fsy {
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

    // v4: _spot с построением глаз ВНУТРИ Rust из снапшота. GDScript больше не
    // материализует ~N глаз-массивов (главная стоимость _spot на пике боя).
    //
    // Глаза страны cid строятся в порядке: (1) свои живые наземные юниты
    // снапшота (r2 = (SPOT_R * (1.3 если ent||dug))^2, recon=false);
    // (2) разведчики — recon_flat по стране (RECON_R^2, recon=true); GDScript
    // передаёт только живых и не заглушенных (jam_t <= 0);
    // (3) города — city_flat по стране ((radius*CELL + CITY_SPOT_R)^2,
    // recon=false). Ровно как _spot_eyes: юниты → разведчики → города.
    //
    // data_flat — склейка по стране: разведчики (x, y), города (x, y, r2),
    // катера (x, y); counts — 3 int на страну (nr, nc, nb). Катера — landing-
    // лодки с префильтром SAIL/BOARD/враждебность/живость на стороне GDScript;
    // проверка как naval.spotted_for: первый глаз с d2 <= r2*1.7 фиксирует
    // запись (bi, ei); без бокса/дыма.
    //
    // Здания — как в v3 (fac_*). Лимит 60: cnt = n_u + n_b + n_f, брейк после
    // добавления здания (1:1 с `if list.size() > 60: break`).
    //
    // Ответ: Array из двух массивов:
    //   [0] PackedInt32Array: на страну
    //       [n_eu, n_er, n_ec, n_u, (uid, ei)*, n_b, (bi, ei)*, n_f, (fi, ei)*]
    //       n_eu/n_er/n_ec — число глаз-юнитов/разведчиков/городов (для decode
    //       recon-флага: ei в [n_eu, n_eu+n_er) — разведчик);
    //   [1] PackedFloat64Array: 2 double на здание (tpx, tpy — точка прицела,
    //       для линий — ближайшая к глазу ячейка; GDScript не пересчитывает
    //       line_point).
    #[func]
    fn spot_all_v2(
        &self,
        cids: PackedInt32Array,
        hms: PackedInt64Array,
        data_flat: PackedFloat64Array,
        counts: PackedInt32Array,
        fac_ids: PackedInt32Array,
        fac_cs: PackedInt32Array,
        fac_xy: PackedFloat64Array,
        fac_ext: PackedFloat64Array,
        fac_flags: PackedInt32Array,
        line_off: PackedInt32Array,
        line_xy: PackedFloat64Array,
    ) -> PackedFloat64Array {
        let mut out: Vec<f64> = Vec::with_capacity(64);
        let mut fac_tps: Vec<f64> = Vec::with_capacity(16);
        let ncid = cids.len().min(hms.len()).min(counts.len() / 3);
        let mut base: usize = 0;
        for ci in 0..ncid {
            let cid = cids[ci] as i64;
            let hm = hms[ci];
            let nr = counts[ci * 3] as usize;
            let nc = counts[ci * 3 + 1] as usize;
            let nb = counts[ci * 3 + 2] as usize;

            // ——— глаза: юниты снапшота → разведчики → города (порядок 1:1) ———
            let mut eyes: Vec<(f64, f64, f64, bool)> = Vec::with_capacity(64);
            let mut n_eu: i32 = 0;
            for o in &self.units {
                if o.cid != cid || o.air {
                    continue;
                }
                let r = SPOT_R * (if o.ent || o.dug { 1.3 } else { 1.0 });
                eyes.push((o.x, o.y, r * r, false));
                n_eu += 1;
            }
            let n_er: i32 = nr as i32;
            for k in 0..nr {
                let b = base + k * 2;
                eyes.push((data_flat[b], data_flat[b + 1], RECON_R * RECON_R, true));
            }
            let n_ec: i32 = nc as i32;
            let cit = base + nr * 2;
            for k in 0..nc {
                let b = cit + k * 3;
                eyes.push((data_flat[b], data_flat[b + 1], data_flat[b + 2], false));
            }

            // ——— бокс: Rect2 expand по глазам + grow(RECON_R), f32 (1:1) ———
            let mut bx0 = f64::INFINITY;
            let mut by0 = f64::INFINITY;
            let mut bx1 = f64::NEG_INFINITY;
            let mut by1 = f64::NEG_INFINITY;
            for e in &eyes {
                if e.0 < bx0 {
                    bx0 = e.0;
                }
                if e.1 < by0 {
                    by0 = e.1;
                }
                if e.0 > bx1 {
                    bx1 = e.0;
                }
                if e.1 > by1 {
                    by1 = e.1;
                }
            }
            let grow = RECON_R as f32;
            let bpx = (bx0 as f32) - grow;
            let bpy = (by0 as f32) - grow;
            let bsx = ((bx1 as f32) - (bx0 as f32)) + grow * 2.0f32;
            let bsy = ((by1 as f32) - (by0 as f32)) + grow * 2.0f32;
            let brx = bpx + bsx;
            let bry = bpy + bsy;

            // ——— юниты: первый подходящий глаз фиксирует recon-флаг ———
            let mut best_eye: Vec<i32> = vec![-1; self.units.len()];
            for (ei, e) in eyes.iter().enumerate() {
                let (ex, ey, r2, recon) = (e.0, e.1, e.2, e.3);
                let rr = r2.sqrt() * 1.001 + 1.0;
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
                    if (ox as f32) < bpx || (ox as f32) >= brx || (oy as f32) < bpy || (oy as f32) >= bry {
                        continue;
                    }
                    if self.in_smoke(ox, oy) {
                        continue;
                    }
                    let lim = if o.ent && !recon { r2.min(TRENCH_SPOT_D2) } else { r2 };
                    let dx = (ox as f32) - (ex as f32);
                    let dy = (oy as f32) - (ey as f32);
                    let d2 = (dx * dx + dy * dy) as f64;
                    if d2 <= lim {
                        best_eye[oi] = ei as i32;
                    }
                }
            }
            let mut n_u: i32 = 0;
            let mut blk: Vec<f64> = Vec::with_capacity(32);
            for (oi, o) in self.units.iter().enumerate() {
                let e = best_eye[oi];
                if e >= 0 {
                    blk.push(o.id as f64);
                    blk.push(e as f64);
                    n_u += 1;
                }
            }

            // ——— катера: первый глаз с d2 <= r2*1.7 (1:1 spotted_for) ———
            let mut n_b: i32 = 0;
            let bot = base + nr * 2 + nc * 3;
            for k in 0..nb {
                let b = bot + k * 2;
                let (px, py) = (data_flat[b], data_flat[b + 1]);
                for (ei, e) in eyes.iter().enumerate() {
                    let dx = (px as f32) - (e.0 as f32);
                    let dy = (py as f32) - (e.1 as f32);
                    let d2 = (dx * dx + dy * dy) as f64;
                    if d2 <= e.2 * 1.7 {
                        blk.push(k as f64);
                        blk.push(ei as f64);
                        n_b += 1;
                        break;
                    }
                }
            }
            base += nr * 2 + nc * 3 + nb * 2;

            // ——— здания: как в v3, лимит учитывает юнитов + катера ———
            // Брейк лимита — 1:1 с GDScript: после глаз-цикла КАЖДОГО здания,
            // прошедшего префильтры (враждебность + бокс), с матчем или без.
            let mut n_f: i32 = 0;
            let mut cnt: i64 = n_u as i64 + n_b as i64;
            let nf = fac_ids.len();
            for fi in 0..nf {
                let fc0 = fac_cs[fi] as i64;
                let foe = if fc0 >= 0 && fc0 < 63 { (hm >> fc0) & 1 == 1 } else { false };
                if foe {
                    let fx = fac_xy[fi * 2];
                    let fy = fac_xy[fi * 2 + 1];
                    let ext = fac_ext[fi];
                    let trench = fac_flags[fi] & 1 != 0;
                    let is_line = fac_flags[fi] & 2 != 0;
                    let fpx = bpx - (ext as f32);
                    let fpy = bpy - (ext as f32);
                    let fsx = bsx + (ext as f32) * 2.0f32;
                    let fsy = bsy + (ext as f32) * 2.0f32;
                    if (fx as f32) >= fpx && (fx as f32) < fpx + fsx && (fy as f32) >= fpy && (fy as f32) < fpy + fsy {
                        let mut fe: i32 = -1;
                        let mut tpx = fx;
                        let mut tpy = fy;
                        for (ei, e) in eyes.iter().enumerate() {
                            let (ex, ey, r2, recon) = (e.0, e.1, e.2, e.3);
                            let (lpx, lpy) = if is_line {
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
                            let dx = (lpx as f32) - (ex as f32);
                            let dy = (lpy as f32) - (ey as f32);
                            let d2 = (dx * dx + dy * dy) as f64;
                            if d2 <= lim {
                                fe = ei as i32;
                                tpx = lpx;
                                tpy = lpy;
                                break;
                            }
                        }
                        if fe >= 0 {
                            blk.push(fi as f64);
                            blk.push(fe as f64);
                            fac_tps.push(tpx);
                            fac_tps.push(tpy);
                            n_f += 1;
                            cnt += 1;
                        }
                        if cnt > SPOT_LIMIT {
                            break;
                        }
                    }
                }
            }
            // Блок страны: заголовок глаз + счётчики, ряды юнитов/катеров/зданий.
            out.push(n_eu as f64);
            out.push(n_er as f64);
            out.push(n_ec as f64);
            out.push(n_u as f64);
            out.extend_from_slice(&blk[..(n_u as usize) * 2]);
            out.push(n_b as f64);
            out.extend_from_slice(&blk[(n_u as usize) * 2..((n_u + n_b) as usize) * 2]);
            out.push(n_f as f64);
            out.extend_from_slice(&blk[((n_u + n_b) as usize) * 2..]);
        }
        // Ряды как f64 (i32 представим точно) + маркер -1.0 + точки зданий.
        out.push(-1.0);
        out.extend_from_slice(&fac_tps);
        PackedFloat64Array::from(out)
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

    // ArmyFire._update_shells — тайминги полёта снарядов: t += dt, свист перед
    // падением, трейл-тик РСЗО, прибытие. Возвращает 4 double на снаряд:
    //   [new_t, whistle_now(0/1), arrived(0/1), trail_tick(0/1)]
    // Эффекты/урон/pts/сброс whistle — GDScript (RNG и _impact там же).
    #[func]
    fn shells_step(
        &self,
        dt: f64,
        t: PackedFloat64Array,
        dur: PackedFloat64Array,
        kind: PackedInt32Array, // KIND_ROCKET == 2
        whistle: PackedInt32Array,
        trail: PackedFloat64Array,
    ) -> PackedFloat64Array {
        let n = t.len().min(dur.len()).min(kind.len()).min(whistle.len()).min(trail.len());
        let mut out: Vec<f64> = Vec::with_capacity(n * 4);
        for i in 0..n {
            let nt = t[i] + dt;
            let is_rocket = kind[i] == 2;
            let mut w = 0.0;
            if !is_rocket && whistle[i] == 0 && dur[i] - nt < 0.9 {
                w = 1.0;
            }
            let mut tick = 0.0;
            if is_rocket {
                let tr = trail[i] + dt;
                if tr >= 0.05 {
                    tick = 1.0;
                }
            }
            let arrived = if nt >= dur[i] { 1.0 } else { 0.0 };
            out.push(nt);
            out.push(w);
            out.push(arrived);
            out.push(tick);
        }
        PackedFloat64Array::from(out)
    }

    // ArmyFire._pick — выбор точки огня для артиллерии/миномётов/РСЗО.
    // Ветки 1:1 с GDScript: окопанные юниты (если GDScript разрешил dugin),
    // запросы огня (d*0.5 + served*60), spotted с бонусами по типу стрелка.
    // spot_flat: 7 double на запись: [x, y, is_unit, vehicle, mortar_soft,
    //   entrenched, recon]; юнит-диапазон [s0, s1) — записи его страны.
    // Возвращает 5 double на стрелка: [kind, vx, vy, recon, aux]
    //   kind 0 — цели нет (GDScript пробует осаду города),
    //   kind 1 — spotted (vx,vy — точка), kind 2 — запрос (aux — индекс).
    #[func]
    fn aim_pick(
        &self,
        u_type: PackedInt32Array,
        u_x: PackedFloat64Array,
        u_y: PackedFloat64Array,
        u_cid: PackedInt32Array,
        u_rmin: PackedFloat64Array,
        u_rmax: PackedFloat64Array,
        u_s0: PackedInt32Array,
        u_s1: PackedInt32Array,
        u_dugin: PackedInt32Array,
        u_hasreq: PackedInt32Array,
        spot_flat: PackedFloat64Array,
        req_xy: PackedFloat64Array,
        req_c: PackedInt32Array,
        req_served: PackedFloat64Array,
    ) -> PackedFloat64Array {
        const MORTAR: i32 = 6;
        const ARTY: i32 = 7;
        const MLRS: i32 = 8;
        let n = u_type
            .len()
            .min(u_x.len())
            .min(u_y.len())
            .min(u_cid.len())
            .min(u_rmin.len())
            .min(u_rmax.len())
            .min(u_s0.len())
            .min(u_s1.len())
            .min(u_dugin.len())
            .min(u_hasreq.len());
        let nent = spot_flat.len() / 7;
        let nr = (req_xy.len() / 2).min(req_c.len()).min(req_served.len());
        let req_x = |rq: usize| req_xy[rq * 2];
        let req_y = |rq: usize| req_xy[rq * 2 + 1];
        let mut out: Vec<f64> = Vec::with_capacity(n * 5);
        for i in 0..n {
            let (ux, uy) = (u_x[i], u_y[i]);
            let (rmin, rmax) = (u_rmin[i], u_rmax[i]);
            let ty = u_type[i];
            let s0 = u_s0[i] as usize;
            let s1 = (u_s1[i] as usize).min(nent);
            let mut bs = f64::INFINITY;
            let mut best_e: i64 = -1;
            let mut best_r: i64 = -1;
            // ——— ветка 1: окопанные юниты
            if u_dugin[i] == 1 {
                for e in s0..s1 {
                    let b = e * 7;
                    if spot_flat[b + 2] == 0.0 || spot_flat[b + 5] == 0.0 {
                        continue;
                    }
                    let ex = spot_flat[b];
                    let ey = spot_flat[b + 1];
                    let dx = (ex as f32) - (ux as f32);
                    let dy = (ey as f32) - (uy as f32);
                    let d0 = ((dx * dx + dy * dy).sqrt()) as f64;
                    if d0 >= rmin && d0 <= rmax && d0 < bs {
                        bs = d0;
                        best_e = e as i64;
                        best_r = -1;
                    }
                }
            }
            if best_e >= 0 {
                let b = best_e as usize * 7;
                out.push(1.0);
                out.push(spot_flat[b]);
                out.push(spot_flat[b + 1]);
                out.push(spot_flat[b + 6]);
                out.push(-1.0);
                continue;
            }
            // ——— ветка 2: запросы огня (только своей страны)
            if u_hasreq[i] == 1 {
                let mut best_rq: i64 = -1;
                for rq in 0..nr {
                    if req_c[rq] != u_cid[i] {
                        continue;
                    }
                    let dx = (req_x(rq) as f32) - (ux as f32);
                    let dy = (req_y(rq) as f32) - (uy as f32);
                    let d = ((dx * dx + dy * dy).sqrt()) as f64;
                    if d < rmin || d > rmax {
                        continue;
                    }
                    let s = d * 0.5 + req_served[rq] * 60.0;
                    if s < bs {
                        bs = s;
                        best_rq = rq as i64;
                    }
                }
                if best_rq >= 0 {
                    out.push(2.0);
                    out.push(req_x(best_rq as usize));
                    out.push(req_y(best_rq as usize));
                    out.push(0.0);
                    out.push(best_rq as f64);
                    continue;
                }
            }
            // ——— ветка 3: spotted с бонусами
            for e in s0..s1 {
                let b = e * 7;
                let (ex, ey) = (spot_flat[b], spot_flat[b + 1]);
                let dx = (ex as f32) - (ux as f32);
                let dy = (ey as f32) - (uy as f32);
                let d2 = ((dx * dx + dy * dy).sqrt()) as f64;
                if d2 < rmin || d2 > rmax {
                    continue;
                }
                let mut s2 = d2;
                if spot_flat[b + 2] != 0.0 {
                    if ty == ARTY && spot_flat[b + 3] != 0.0 {
                        s2 -= 250.0;
                    }
                    if ty == MORTAR && spot_flat[b + 4] != 0.0 {
                        s2 -= 120.0;
                    }
                    if ty == MLRS {
                        let mut near = 0i64;
                        for e2 in s0..s1 {
                            let b2 = e2 * 7;
                            let fx = spot_flat[b2];
                            let fy = spot_flat[b2 + 1];
                            let ddx = (fx as f32) - (ex as f32);
                            let ddy = (fy as f32) - (ey as f32);
                            let dd = (ddx * ddx + ddy * ddy) as f64;
                            if dd < 900.0 {
                                near += 1;
                            }
                        }
                        s2 -= (near as f64) * 120.0;
                        if near < 3 {
                            continue;
                        }
                    }
                } else if ty == MLRS {
                    continue;
                }
                if s2 < bs {
                    bs = s2;
                    best_e = e as i64;
                    best_r = -1;
                }
            }
            if best_e >= 0 {
                let b = best_e as usize * 7;
                out.push(1.0);
                out.push(spot_flat[b]);
                out.push(spot_flat[b + 1]);
                out.push(spot_flat[b + 6]);
                out.push(-1.0);
            } else {
                out.push(0.0);
                out.push(0.0);
                out.push(0.0);
                out.push(0.0);
                out.push(-1.0);
            }
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

    // v3: сетки мира для wd-пассов. blocked — ячейка «вода без моста»
    // (Biome.is_water and not F_BRIDGE, считает GDScript один раз на партию),
    // owners — снимок owners_dirty из WorldData (PackedByteArray w*h).
    #[func]
    fn push_wd_grid(&mut self, w: i32, h: i32, blocked: PackedByteArray, owners: PackedByteArray) {
        let w = w.max(0) as usize;
        let h = h.max(0) as usize;
        self.wd_w = w;
        self.wd_h = h;
        self.wd_blocked = (0..blocked.len()).map(|i| blocked[i]).collect();
        self.wd_owner = (0..owners.len()).map(|i| owners[i]).collect();
    }

    // v3: Operations._wd_sweep целиком — пары «кто>чья_земля» для вывода войск.
    //
    // Вход (юниты в порядке gw.army.units, только живые наземные):
    //   ids/xs/ys/cs — id, позиция (f32 как в Vector2), страна;
    //   hs           — id дома (Facility.id) или -1;
    //   sea          — id домов «в море» (naval/rail, stage != MARCH);
    //   retreat      — id домов с op.kind == RETREAT;
    //   truce        — закодированные пары (a<<16|b) с перемирием;
    //   wd_known     — пары уже в withdrawals (who<<16|land);
    //   cell_px      — размер ячейки мира (GameWorld.CELL = 4).
    //
    // Выход: блоки [who, land, est, n, id...] в порядке обнаружения, где
    //   est  — 1, если хотя бы один юнит пары прошёл проверки установления
    //          (не вода-без-моста, не «в море», не отступление+перемирие,
    //          пара не была известна) — семантика 1:1 с исходным циклом;
    //   ids  — ПОЛНЫЙ список юнитов пары (критерии wd_units: жив, наземный,
    //          страна who, _owner_at(pos)==land) — для withdraw без повторного
    //          скана. Пары из wd_known не возвращаются вовсе.
    #[func]
    fn wd_scan(
        &self,
        ids: PackedInt32Array,
        xs: PackedFloat32Array,
        ys: PackedFloat32Array,
        cs: PackedInt32Array,
        hs: PackedInt32Array,
        sea: PackedInt64Array,
        retreat: PackedInt64Array,
        truce: PackedInt64Array,
        wd_known: PackedInt64Array,
        cell_px: f64,
    ) -> PackedInt64Array {
        let n = ids
            .len()
            .min(xs.len())
            .min(ys.len())
            .min(cs.len())
            .min(hs.len());
        let known: HashSet<i64> = (0..wd_known.len()).map(|i| wd_known[i]).collect();
        let sea_set: HashSet<i64> = (0..sea.len()).map(|i| sea[i]).collect();
        let ret_set: HashSet<i64> = (0..retreat.len()).map(|i| retreat[i]).collect();
        let truce_set: HashSet<i64> = (0..truce.len()).map(|i| truce[i]).collect();
        // key → (who, land, established, full_ids); порядок обнаружения — order.
        let mut acc: HashMap<i64, (i64, i64, bool, Vec<i64>)> = HashMap::new();
        let mut order: Vec<i64> = Vec::new();
        let cell = if cell_px > 0.0 { cell_px } else { 4.0 };
        for i in 0..n {
            let x = xs[i] as f64;
            let y = ys[i] as f64;
            let cid = cs[i] as i64;
            let home = hs[i] as i64;
            let cx = (x / cell).floor() as i32;
            let cy = (y / cell).floor() as i32;
            let o = self.wd_owner_at(cx, cy);
            if o <= 0 || o == cid {
                continue;
            }
            let key = (cid << 16) | o;
            let entry = acc.entry(key).or_insert_with(|| {
                order.push(key);
                (cid, o, false, Vec::new())
            });
            // Полный список юнитов пары (критерии wd_units — независимо от
            // проверок установления, как исходный wd_units).
            entry.3.push(ids[i] as i64);
            if known.contains(&key) || entry.2 {
                continue;
            }
            // Проверки установления — в порядке исходного _wd_sweep.
            if self.wd_cell_blocked(cx, cy) {
                continue;
            }
            if home >= 0 && sea_set.contains(&home) {
                continue;
            }
            if home >= 0 && ret_set.contains(&home) && truce_set.contains(&key) {
                continue;
            }
            entry.2 = true;
        }
        let mut out: Vec<i64> = Vec::with_capacity(16);
        for key in order {
            let (who, land, est, full) = &acc[&key];
            if !*est || known.contains(&key) {
                continue;
            }
            out.push(*who);
            out.push(*land);
            out.push(full.len() as i64);
            out.extend_from_slice(full);
        }
        PackedInt64Array::from(out)
    }

    // v3: Operations._ai — подсчёт «соседей» для арт-цели. Вход poss — пары
    // (x, y) замеченных юнит-целей в порядке spotted; выход counts[i] — число
    // точек (включая саму точку) с дистанцией² < 2025 (45px), сетка 45px 3×3.
    // Ячейки — floor(f64(x)/45.0) как в GDScript (floori(sp0.x / 45.0));
    // дистанция — f32-арифметика Vector2.distance_squared_to, сравнение с
    // f64-литералом 2025.0.
    #[func]
    fn spot_density(&self, poss: PackedFloat64Array) -> PackedInt32Array {
        const CELLF: f64 = 45.0;
        let n = poss.len() / 2;
        let fx: Vec<f32> = (0..n).map(|i| poss[i * 2] as f32).collect();
        let fy: Vec<f32> = (0..n).map(|i| poss[i * 2 + 1] as f32).collect();
        let mut grid: HashMap<(i32, i32), Vec<usize>> = HashMap::with_capacity(n.max(1));
        let mut cell_of = vec![(0i32, 0i32); n];
        for i in 0..n {
            let c = (
                ((fx[i] as f64) / CELLF).floor() as i32,
                ((fy[i] as f64) / CELLF).floor() as i32,
            );
            cell_of[i] = c;
            grid.entry(c).or_default().push(i);
        }
        let mut out = vec![0i32; n];
        for i in 0..n {
            let (cx, cy) = cell_of[i];
            let mut c = 0i32;
            for dy in -1..=1 {
                for dx in -1..=1 {
                    if let Some(b) = grid.get(&(cx + dx, cy + dy)) {
                        for &j in b {
                            let ddx = fx[j] - fx[i];
                            let ddy = fy[j] - fy[i];
                            if ((ddx * ddx + ddy * ddy) as f64) < 2025.0 {
                                c += 1;
                            }
                        }
                    }
                }
            }
            out[i] = c;
        }
        PackedInt32Array::from(out)
    }

    // v3: армейское ядро решений боя — Army._fight + Army._shoot БЕЗ эффектов.
    // Ряды стрелков (все массивы одной длины, порядок = порядок юнит-цикла):
    //   ids/types — id и Unit.Type;
    //   pos       — 4 f32 на стрелка: x, y стрелка и x, y цели (_target_pos);
    //   state     — 4 f64: supp, fire_cd, gren_cd, rpg_cd;
    //   flags     — бит0 aimed, бит1 pinned, бит2 kit&KIT_GREN,
    //               бит3 entrenched, бит4 «цель — машина (Unit.vehicle())»;
    //   spec      — 3 f64 на тип (16 типов): cd, dmg, hit — Army.SPEC;
    //   game_time — gw.game_time (float).
    // Дымы уже запушены push_smokes — in_smoke работает.
    // Выход: на стрелка 9 float: [op, cd, xcd, dmg, hit, ok, mx, my, fx],
    //   op: 1 rifle, 2 tank, 3 grenade, 4 rocket atgm, 5 rocket rpg;
    //   cd/xcd — новые fire_cd/gren_cd|rpg_cd; hit — итоговый hit после
    //   дымов/подавления (int в float); ok — роля попадания; mx/my — смещение
    //   промаха танка; fx — роля «искры» при попадании. Роли — Hash32.h2,
    //   побитово равные GDScript.
    #[func]
    fn fight_decide(
        &self,
        ids: PackedInt32Array,
        types: PackedInt32Array,
        pos: PackedFloat32Array,
        state: PackedFloat64Array,
        flags: PackedInt32Array,
        spec: PackedFloat64Array,
        game_time: f64,
    ) -> PackedFloat64Array {
        const F_TANK: i32 = 0;
        const F_INF: i32 = 1;
        const F_ATGM: i32 = 3;
        const F_ASSAULT: i32 = 4;
        const GREN_R: f64 = 32.0;
        const GREN_CD: f64 = 9.0;
        const RPG_R: f64 = 70.0;
        const RPG_CD: f64 = 7.0;
        const RPG_DMG: f64 = 55.0;
        const PIN_SLOW: f64 = 3.3;
        const TRENCH_RANGE: f64 = 1.08;
        let n = ids
            .len()
            .min(types.len())
            .min(flags.len())
            .min(pos.len() / 4)
            .min(state.len() / 4);
        let g3 = (game_time * 3.0).trunc() as i64;
        let g5 = (game_time * 5.0).trunc() as i64;
        let g7 = (game_time * 7.0).trunc() as i64;
        let g9 = (game_time * 9.0).trunc() as i64;
        let gi = game_time.trunc() as i64;
        let mut out: Vec<f64> = Vec::with_capacity(n * 9);
        for i in 0..n {
            let id = ids[i] as i64;
            let ty = types[i];
            let fl = flags[i];
            let x = pos[i * 4] as f32;
            let y = pos[i * 4 + 1] as f32;
            let tx = pos[i * 4 + 2] as f32;
            let tyf = pos[i * 4 + 3] as f32;
            let st = i * 4;
            let sp = ((ty as usize) * 3 + 2) < spec.len();
            let sp_cd = if sp { spec[ty as usize * 3] } else { 0.0 };
            let sp_dmg = if sp { spec[ty as usize * 3 + 1] } else { 0.0 };
            let sp_hit = if sp { spec[ty as usize * 3 + 2] as i64 } else { 0 };
            let pinned = fl & 2 != 0;
            let kit_gren = fl & 4 != 0;
            let ent = fl & 8 != 0;
            let tgt_veh = fl & 16 != 0;
            let ddx = x - tx;
            let ddy = y - tyf;
            let dist = (ddx * ddx + ddy * ddy).sqrt() as f64;
            let sup = state[st];
            let mut cd = sp_cd
                * (0.8 + (h2_32(id, g3, 9) % 40) as f64 / 100.0)
                * (1.0 + sup);
            if pinned {
                cd *= PIN_SLOW;
            }
            if kit_gren && state[st + 2] <= 0.0 && dist <= GREN_R {
                out.extend_from_slice(&[3.0, cd, GREN_CD, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
                continue;
            }
            if ty == F_ATGM {
                out.extend_from_slice(&[
                    4.0,
                    cd,
                    0.0,
                    sp_dmg,
                    sp_hit as f64,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                ]);
                continue;
            }
            if (ty == F_INF || ty == F_ASSAULT)
                && tgt_veh
                && state[st + 3] <= 0.0
                && dist <= RPG_R * (if ent { TRENCH_RANGE } else { 1.0 })
            {
                out.extend_from_slice(&[
                    5.0,
                    cd,
                    RPG_CD,
                    RPG_DMG,
                    60.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                ]);
                continue;
            }
            if ty == F_TANK {
                let ok = (h2_32(id, g7, 23) % 100) < sp_hit as u32;
                let (mut mx, mut my) = (0.0f64, 0.0f64);
                if !ok {
                    mx = (h2_32(id, 1, gi) % 17) as f64 - 8.0;
                    my = (h2_32(id, 2, gi) % 17) as f64 - 8.0;
                }
                out.extend_from_slice(&[
                    2.0,
                    cd,
                    0.0,
                    sp_dmg,
                    sp_hit as f64,
                    if ok { 1.0 } else { 0.0 },
                    mx,
                    my,
                    0.0,
                ]);
                continue;
            }
            let mut hit = sp_hit;
            if self.in_smoke(tx as f64, tyf as f64) || self.in_smoke(x as f64, y as f64) {
                hit = hit * 2 / 5;
            }
            hit = (hit as f64 * (1.0 - 0.4 * sup)).trunc() as i64;
            let ok = (h2_32(id, g9, 29) % 100) < hit as u32;
            let fx = (h2_32(id, g5, 3) % 3) == 0;
            out.extend_from_slice(&[
                1.0,
                cd,
                0.0,
                sp_dmg,
                hit as f64,
                if ok { 1.0 } else { 0.0 },
                0.0,
                0.0,
                if fx { 1.0 } else { 0.0 },
            ]);
        }
        PackedFloat64Array::from(out)
    }
}

// Точка входа GDExtension (обязана быть экспортирована).
struct DfExtension;

#[gdextension]
unsafe impl ExtensionLibrary for DfExtension {}
