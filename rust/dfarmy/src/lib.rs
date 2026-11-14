//! DroneFlames Reborn — армейские действия на Rust.
//!
//! Движок форсирования рек: замедление в воде, запрет входа в море,
//! прерывание огнём, выбор места переправы, детерминированные слоты.
//! Все расчёты детерминированы (одинаковые входы -> одинаковые выходы на всех
//! пирах), float-математика совпадает с GDScript (Vector2 = f32, как в Godot).

use godot::init::*;
use godot::prelude::*;

struct DfArmyExt;
#[gdextension(entry_symbol = dfarmy_init)]
unsafe impl ExtensionLibrary for DfArmyExt {}

/// Коды terrain-сетки (заполняется GDScript-ом при старте мира / смене версии навигации):
const CODE_LAND: u8 = 0; // суша или мост — обычная скорость
const CODE_FORD: u8 = 1; // река (Biome.RIVER) — проходимо вброд
const CODE_SEA: u8 = 2; // море/озеро — непроходимо для колёсных/гусеничных

/// Множители скорости в воде: вброд пехота идёт быстрее, техника заметно медленнее.
const FORD_SPD_FOOT: f32 = 0.38;
const FORD_SPD_VEH: f32 = 0.24;

#[derive(GodotClass)]
#[class(base=Object, init)]
struct DFArmy {
    w: i32,
    h: i32,
    cell: f32,
    grid: Vec<u8>,
}

#[godot_api]
impl DFArmy {
    fn init(_base: Base<Object>) -> Self {
        DFArmy { w: 0, h: 0, cell: 4.0, grid: Vec::new() }
    }

    /// Загрузить codes-сетку мира: w*h байт, CODE_LAND / CODE_FORD / CODE_SEA.
    #[func]
    fn grid_set(&mut self, w: i32, h: i32, cell: f32, codes: PackedByteArray) {
        self.w = w.max(0);
        self.h = h.max(0);
        self.cell = if cell > 0.0 { cell } else { 4.0 };
        let n = (self.w * self.h).max(0) as usize;
        let mut g = vec![CODE_LAND; n];
        let src = codes.as_slice();
        let take = src.len().min(n);
        g[..take].copy_from_slice(&src[..take]);
        self.grid = g;
    }

    /// Загрузить сетку прямо из WorldData (нулевое копирование biome + flags):
    /// biome > river_id -> CODE_LAND; biome == river_id и без моста -> CODE_FORD;
    /// прочая вода без моста -> CODE_SEA; клетки мостов -> CODE_LAND.
    #[func]
    fn grid_set_biome(&mut self, w: i32, h: i32, cell: f32, biome: PackedByteArray, flags: PackedByteArray, river_id: i32, flag_bridge: i32) {
        self.w = w.max(0);
        self.h = h.max(0);
        self.cell = if cell > 0.0 { cell } else { 4.0 };
        let n = (self.w * self.h).max(0) as usize;
        let mut g = vec![CODE_LAND; n];
        let bio = biome.as_slice();
        let flg = flags.as_slice();
        let river = river_id.max(0) as u8;
        let fb = flag_bridge as u8;
        let take = bio.len().min(n);
        let ftake = flg.len().min(take);
        for i in 0..take {
            let b = bio[i];
            if b > river {
                continue; // суша
            }
            let mut code = CODE_SEA;
            if b == river {
                code = CODE_FORD;
            }
            if i < ftake && (flg[i] & fb) != 0 {
                code = CODE_LAND; // мост
            }
            g[i] = code;
        }
        self.grid = g;
    }

    /// Частичное обновление клеток (мосты построены/разрушены): idx PackedInt32Array, code байты.
    #[func]
    fn grid_patch(&mut self, idx: PackedInt32Array, codes: PackedByteArray) {
        let ii = idx.as_slice();
        let cc = codes.as_slice();
        let n = ii.len().min(cc.len());
        for k in 0..n {
            let i = ii[k] as usize;
            if i < self.grid.len() {
                self.grid[i] = cc[k];
            }
        }
    }

    fn code_at(&self, x: i32, y: i32) -> u8 {
        if x < 0 || y < 0 || x >= self.w || y >= self.h {
            return CODE_SEA;
        }
        self.grid[(y * self.w + x) as usize]
    }

    fn code_at_px(&self, p: Vector2) -> u8 {
        if self.cell <= 0.0 || !p.is_finite() {
            return CODE_LAND;
        }
        let x = (p.x / self.cell).floor() as i32;
        let y = (p.y / self.cell).floor() as i32;
        self.code_at(x, y)
    }

    /// Ширина водной полосы (px) в точке: максимум пробега по четырём осям.
    fn band_width_px(&self, p: Vector2) -> f32 {
        let cx = (p.x / self.cell).floor() as i32;
        let cy = (p.y / self.cell).floor() as i32;
        let mut best = 0.0_f32;
        for d in [Vector2::new(1.0, 0.0), Vector2::new(-1.0, 0.0), Vector2::new(0.0, 1.0), Vector2::new(0.0, -1.0)] {
            let mut run: i32 = 0;
            let mut qx = cx;
            let mut qy = cy;
            while self.code_at(qx, qy) == CODE_FORD && run < 96 {
                qx += d.x as i32;
                qy += d.y as i32;
                run += 1;
            }
            if run as f32 > best {
                best = run as f32;
            }
        }
        best * self.cell
    }

    /// Выбор места форсирования: узкая полоса реки рядом с линией «от -> цель».
    /// Перебор клеток детерминирован (по строкам), оценка = ширина + штраф расстояния.
    #[func]
    fn ford_pick(&self, from: Vector2, goal: Vector2, radius: f32) -> Dictionary<GString, Variant> {
        let mut res: Dictionary<GString, Variant> = Dictionary::new();
        if self.grid.is_empty() || self.cell <= 0.0 {
            res.set("ok", &false.to_variant());
            return res;
        }
        let line = goal - from;
        let len2 = line.x * line.x + line.y * line.y;
        let mut best_score = f32::INFINITY;
        let mut best_site = Vector2::INF;
        for y in 0..self.h {
            for x in 0..self.w {
                if self.code_at(x, y) != CODE_FORD {
                    continue;
                }
                let p = Vector2::new((x as f32 + 0.5) * self.cell, (y as f32 + 0.5) * self.cell);
                let mut t = if len2 > 0.0 { (p - from).dot(line) / len2 } else { 0.0 };
                if t < 0.0 {
                    t = 0.0;
                }
                if t > 1.0 {
                    t = 1.0;
                }
                let proj = from + line * t;
                let dl = p.distance_to(proj);
                if dl > radius {
                    continue;
                }
                let wpx = self.band_width_px(p);
                let score = wpx * 1.6 + dl + x as f32 * 0.013 + y as f32 * 0.007;
                if score < best_score {
                    best_score = score;
                    best_site = p;
                }
            }
        }
        res.set("ok", &best_site.is_finite().to_variant());
        res.set("site", &best_site.to_variant());
        res.set("width", &self.band_width_px(best_site).to_variant());
        res
    }

    /// Степпинг пачки юнитов вдоль их путей с учётом форсирования.
    ///
    /// pos/pi/spd/ford/veh/int/back — по элементу на юнита. paths — плоский список
    /// точек путей, starts[i] — индекс первой точки пути юнита i (путь юнита i:
    /// paths[starts[i]..starts[i+1]]).
    ///
    /// Возврат: {pos, pi, water, arrived, blocked} — новые позиции, число съеденных
    /// точек пути, «в воде», «дошёл», «упёрся в непроходимое (море)».
    #[func]
    fn step(
        &self,
        dt: f32,
        pos: PackedVector2Array,
        paths: PackedVector2Array,
        starts: PackedInt32Array,
        pi: PackedInt32Array,
        spd: PackedFloat32Array,
        ford: PackedByteArray,
        veh: PackedByteArray,
        interrupt: PackedByteArray,
        back_out: PackedByteArray,
    ) -> Dictionary<GString, Variant> {
        let mut res: Dictionary<GString, Variant> = Dictionary::new();
        let n = pos.len().min(pi.len()).min(spd.len()).min(starts.len().saturating_sub(1));
        let mut new_pos = PackedVector2Array::new();
        let mut new_pi = PackedInt32Array::new();
        let mut water = PackedByteArray::new();
        let mut arrived = PackedByteArray::new();
        let mut blocked = PackedByteArray::new();
        new_pos.resize(n);
        new_pi.resize(n);
        water.resize(n);
        arrived.resize(n);
        blocked.resize(n);
        let pth = paths.as_slice();
        let starts_s = starts.as_slice();
        let ford_s = ford.as_slice();
        let veh_s = veh.as_slice();
        let int_s = interrupt.as_slice();
        let back_s = back_out.as_slice();
        let mut pos_v: Vec<Vector2> = pos.as_slice().to_vec();
        let pi_v: Vec<i32> = pi.as_slice().to_vec();
        let spd_v: Vec<f32> = spd.as_slice().to_vec();

        for i in 0..n {
            let mut p = pos_v[i];
            let mut idx = pi_v[i];
            let s0 = starts_s[i] as usize;
            let s1 = starts_s[i + 1] as usize;
            let ford_on = ford_s.get(i).copied().unwrap_or(0) != 0;
            let is_veh = veh_s.get(i).copied().unwrap_or(0) != 0;
            let hit = int_s.get(i).copied().unwrap_or(0) != 0;
            let retreat = back_s.get(i).copied().unwrap_or(0) != 0;
            let base = spd_v[i].max(0.0);

            let in_water_now = self.code_at_px(p) == CODE_FORD;
            if in_water_now && hit {
                // Юнит в воде под огнём: замирает (GDScript уведёт его на свой берег).
                new_pos[i] = p;
                new_pi[i] = idx;
                water[i] = 1;
                continue;
            }

            let fmul = if ford_on {
                if is_veh { FORD_SPD_VEH } else { FORD_SPD_FOOT }
            } else {
                1.0
            };

            // Бюджет — «сухие» пиксели кадра; в воде каждый пиксель стоит 1/fmul бюджета.
            let mut budget = dt * base;
            let mut in_water = false;
            let mut gave_up = false;
            let mut guard: u32 = 0;
            while budget > 0.0 {
                guard += 1;
                if guard > 4096 {
                    break;
                }
                let rem = (s1 - s0) as i32 - idx;
                if rem <= 0 {
                    break;
                }
                let q = pth[s0 + idx as usize];
                let to = q - p;
                let dist = (to.x * to.x + to.y * to.y).sqrt().max(1e-6);
                let nxt = p + to * ((budget.min(dist)) / dist);
                let code_next = self.code_at_px(nxt);
                let code_now = self.code_at_px(p);
                if code_next == CODE_SEA && code_now != CODE_SEA && !retreat {
                    // Море вперёди — стоп, пусть GDScript перестраивает маршрут.
                    gave_up = true;
                    break;
                }
                let wet = code_next == CODE_FORD || code_now == CODE_FORD;
                if wet {
                    in_water = true;
                }
                let fm = if wet { fmul } else { 1.0 };
                let step = budget * fm;
                if dist <= step + 0.5 {
                    p = q;
                    idx += 1;
                    budget -= dist / fm;
                } else {
                    p = nxt;
                    budget = 0.0;
                }
            }
            // Подавление численного дрейфа: привязка к сетке 1/64 px (детерминизм на пирах).
            p.x = (p.x * 64.0).round() / 64.0;
            p.y = (p.y * 64.0).round() / 64.0;
            new_pos[i] = p;
            new_pi[i] = idx;
            water[i] = if in_water { 1 } else { 0 };
            arrived[i] = if idx >= (s1 - s0) as i32 { 1 } else { 0 };
            blocked[i] = if gave_up { 1 } else { 0 };
        }
        res.set("pos", &new_pos.to_variant());
        res.set("pi", &new_pi.to_variant());
        res.set("water", &water.to_variant());
        res.set("arrived", &arrived.to_variant());
        res.set("blocked", &blocked.to_variant());
        res
    }

    /// Детерминированное смещение слота построения (замена GDScript-формул).
    #[func]
    fn slot_of(&self, k: i32, dx: f32, dy: f32) -> Vector2 {
        Vector2::new(((k % 3) - 1) as f32 * dx, (k / 3) as f32 * dy)
    }

    /// Диагностика: GDScript узнаёт, что движок загружен.
    #[func]
    fn version(&self) -> GString {
        GString::from("dfarmy 1.0.0")
    }
}
