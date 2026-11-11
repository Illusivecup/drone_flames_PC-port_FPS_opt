class_name FxLayer
extends Node2D


var gw: GameWorld
var fa: SpriteAtlas
var atlas_of: Dictionary = {}
var frames: SpriteFrames
var pool: Array[AnimatedSprite2D] = []
var active_loops: Array = []
var debris: Array = []
var _gen: int = 0



const COSMETIC_MAX: float = 2.5
static var vt: float = 0.0


const BIG_FX: Dictionary = {"explosion_l": true, "shockwave": true, "tank_blast": true, "launch_cloud": true, "fire_big_loop": false, 
	"x_ball": true, "x_hyper": true, "x_kab": true, "x_cruise": true}

const FOG_SHOW: Dictionary = {"explosion_s": true, "explosion_m": true, "explosion_l": true, "shockwave": true, "tank_blast": true, 
	"splash": true, "dirt_burst": true, "grenade_burst": true, "atgm_hit": true, "smoke_loop": true, "smoke_black_loop": true, 
	"smoke_s": true, "cookoff_jet_loop": true}
const AIR_FX: Dictionary = {"intercept_flash": true, "trail_s": true, "trail_puff": true, "booster_flame_loop": true, "missile_flame_loop": true}
const FAR_ALPHA: float = 0.45
var _fog_on: bool = false




const FIRE_VARS: Array = ["fire_c_loop", "fire_a_loop", "fire_b_loop"]



const NIGHT_SMOKE: Dictionary = {
	"smoke_loop": 0, "smoke_black_loop": 0, "smoke_screen_loop": 0, "smoke_wall_loop": 0, "smoke_pop": 0, 
	"smoke_column_loop": 0, "dust_s": 0, "dirt_burst": 1, "launch_cloud": 3, "farm_dust_loop": 0, "splash": 2, 
	"ship_smoke": 0, "blast_m": 7, "explosion_l": 9, "explosion_m": 4, "explosion_s": 3, "shell_burst": 3, 
	"mortar_burst": 3, "rocket_burst": 3, "grenade_burst": 3, "tank_blast": 7, "atgm_hit": 4, 
	"x_fpv": 4, "x_mine": 4, "x_shell": 5, "x_mlrs": 7, "x_kab": 2, "x_cruise": 8, "x_ball": 9, "x_hyper": 11, 
	"trail_puff": 0, "dmg_smoke_loop": 0, "era_pop": 2, 
}
var _night_on: bool = false
const SMOKE_GREY: = Color(0.66, 0.64, 0.6)
var _ns: Dictionary = {}
var _fcat: Dictionary = {}
var fires_live: Array = []
var _fire_t: float = 0.0
var _det30: bool = false


func setup(game_world: GameWorld, fx_atlas: SpriteAtlas, extra: Array = []) -> void :
	gw = game_world
	fa = fx_atlas
	frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var d30: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/det30_fx.png", "res://assets/sprites/det30_fx.json", true)
	var x314: SpriteAtlas = SpriteAtlas.load_atlas("res://assets/sprites/atlas_fx314.png", "res://assets/sprites/atlas_fx314.json", true)
	for at: SpriteAtlas in [fx_atlas] + extra + [d30, x314]:
		for sname: String in at.sprites:
			var s: Dictionary = at.sprites[sname]
			atlas_of[sname] = at
			frames.add_animation(sname)
			frames.set_animation_speed(sname, maxf(1.0, float(s["fps"])))
			frames.set_animation_loop(sname, sname.ends_with("_loop") or sname == "fire_small")
			for i in int(s["frames"]):
				frames.add_frame(sname, at.region(sname, i))
	for nk: String in NIGHT_SMOKE:
		_ns[StringName(nk)] = NIGHT_SMOKE[nk]
	_det30 = atlas_of.has("fire_k_loop") and atlas_of.has("fire_a_loop") and atlas_of.has("fire_b_loop") and atlas_of.has("fire_c_loop") and atlas_of.has("fire_d_loop")


func reset() -> void :
	for s in pool:
		s.stop()
		s.visible = false
	active_loops.clear()
	fires_live.clear()
	debris.clear()
	queue_redraw()
	if gw != null and gw.vfx != null:
		gw.vfx.reset()


func _take() -> AnimatedSprite2D:
	for s in pool:
		if not s.visible:
			return s
	var n: = AnimatedSprite2D.new()
	n.sprite_frames = frames
	n.centered = false
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.animation_finished.connect(_on_finished.bind(n))
	add_child(n)
	pool.append(n)
	return n


func _on_finished(n: AnimatedSprite2D) -> void :
	if not frames.get_animation_loop(n.animation):
		n.visible = false



func spawn(sname: String, pos: Vector2, z: int = 6, until: float = 0.0, random_start: bool = false) -> AnimatedSprite2D:
	var fire30: bool = false
	if _det30 and until > 0.0 and sname == "fire_small":
		fire30 = true
		sname = "fire_k_loop"
	elif sname == "explosion_m" and atlas_of.has("blast_m"):
		sname = "blast_m"
	if gw.vfx != null and gw.vfx.blast != null:
		sname = gw.vfx.blast.remap(sname, pos)
	if not atlas_of.has(sname):
		return null
	var s: AnimatedSprite2D = _take()
	var info: Dictionary = (atlas_of[sname] as SpriteAtlas).info(sname)
	s.flip_h = false
	s.flip_v = false
	_gen += 1
	s.set_meta("gen", _gen)
	s.animation = sname
	s.offset = Vector2( - float(info["ax"]), - float(info["ay"]))
	s.position = pos.round()
	s.z_index = z
	s.visible = true

	var grey: bool = sname == "smoke_loop" and until > 0.0 and until - gw.game_time < 1000000.0
	s.set_meta("grey", grey)
	s.self_modulate = SMOKE_GREY if grey else Color.WHITE
	s.modulate = Color(1, 1, 1, fog_alpha(sname, s.position))
	s.speed_scale = cosmetic_scale(gw.time_scale)
	var nf: int = int(info["frames"])
	s.frame = (randi() % nf) if random_start else 0
	s.play(sname)
	if until > 0.0:
		active_loops.append([s, until])
	if fire30:
		var hh: int = posmod(int(pos.x) * 7 + int(pos.y) * 13, 10)
		fires_live.append([s, _gen, gw.game_time, until, 0 if hh < 4 else (1 if hh < 8 else 2), 0, randf_range(0.6, 1.5)])
	if gw.vfx != null and gw.vfx.blast != null and s.modulate.a > 0.0:
		gw.vfx.blast.on_fx(sname, s.position)
	return s




func handle(s: AnimatedSprite2D) -> Array:
	return [s, int(s.get_meta("gen", -1))] if s != null else [null, -1]


func stop_h(h: Array) -> void :
	var s: AnimatedSprite2D = h[0]
	if s != null and s.visible and int(s.get_meta("gen", -1)) == int(h[1]):
		stop(s)



func stop(s: AnimatedSprite2D) -> void :
	if s == null:
		return
	for k in range(active_loops.size() - 1, -1, -1):
		if active_loops[k][0] == s:
			active_loops.remove_at(k)
	s.stop()
	s.visible = false


func debris_burst(pos: Vector2, count: int, wood: bool, soft: bool = false) -> void :
	for k in count:
		var ang: float = randf() * TAU
		var sp: float = randf_range(8.0, 20.0) if soft else randf_range(25.0, 55.0)
		var nm: String = "debris_wood" if (wood != (k % 3 == 0)) else "debris"
		debris.append({"g": pos, "z": 2.0, "v": Vector2(cos(ang), sin(ang) * 0.6) * sp, "vz": randf_range(10.0, 30.0) if soft else randf_range(70.0, 120.0), "n": nm, "t": randf() * 0.3, "flip": randf() < 0.5})



static func cosmetic_scale(ts: float) -> float:
	return clampf(ts, 0.0, COSMETIC_MAX)



func fog_alpha(sname: String, p: Vector2) -> float:
	var v: Vision = gw.vision if gw != null else null
	if v == null or not v.active():
		return 1.0
	if AIR_FX.has(sname):
		return 1.0 if v.sees_air(p) or sname == "intercept_flash" else 0.0
	if v.sees(p) or FOG_SHOW.has(sname) or sname.begins_with("fire_") or sname.begins_with("x_"):
		return 1.0



	return 0.0




func _fog_alpha_fast(s: AnimatedSprite2D, fog: bool) -> float:
	if not fog:
		return 1.0
	var cat: int = int(_fcat.get(s.animation, -1))
	if cat < 0:
		var sname: String = String(s.animation)
		if AIR_FX.has(sname):
			cat = 0 if sname == "intercept_flash" else 1
		else:
			cat = 0 if FOG_SHOW.has(sname) or sname.begins_with("fire_") or sname.begins_with("x_") else 2
		_fcat[s.animation] = cat
	if cat == 0:
		return 1.0
	if cat == 1:
		return 1.0 if gw.vision.sees_air(s.position) else 0.0
	return 1.0 if gw.vision.sees(s.position) else 0.0


func _process(delta: float) -> void :
	if gw == null:
		return
	var cs: float = cosmetic_scale(gw.time_scale)
	if VfxBlast.hitstop > 0.0:
		cs = 0.0
	vt += delta * cs
	var dt: float = delta * cs
	var fog: bool = gw.vision != null and gw.vision.active()
	var nt: Color = _night_tint()
	var nton: bool = nt != Color.WHITE
	for s in pool:
		if s.visible:
			s.speed_scale = cs
			if nton or _night_on:
				var nf: int = int(_ns.get(s.animation, -1))
				s.self_modulate = nt if nf >= 0 and s.frame >= nf else (SMOKE_GREY if s.get_meta("grey", false) else Color.WHITE)
			if fog or _fog_on:
				var fa: float = _fog_alpha_fast(s, fog)
				if s.modulate.a != fa:
					s.modulate = Color(1, 1, 1, fa)
	_fog_on = fog
	_fire_t -= delta
	if _fire_t <= 0.0 and not fires_live.is_empty():
		_fire_t = 0.2
		_fire_cycle()
	for k in range(active_loops.size() - 1, -1, -1):
		var e: Array = active_loops[k]
		if gw.game_time >= float(e[1]):
			(e[0] as AnimatedSprite2D).visible = false
			active_loops.remove_at(k)
	if debris.is_empty():
		return
	for k in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[k]
		d["g"] = Vector2(d["g"]) + Vector2(d["v"]) * dt
		d["vz"] = float(d["vz"]) - 320.0 * dt
		d["z"] = float(d["z"]) + float(d["vz"]) * dt
		d["t"] = float(d["t"]) + dt
		if float(d["z"]) <= 0.0:
			var cell: = Vector2i(Vector2(d["g"]) / 4.0)
			if gw.data.inside(cell.x, cell.y) and Biome.is_water(gw.data.get_biome(cell.x, cell.y)) and not gw.data.has_flag(cell.x, cell.y, WorldData.F_BRIDGE):
				var sp: AnimatedSprite2D = spawn("splash", Vector2(d["g"]), 6)
				if sp != null:
					sp.frame = 3
			debris.remove_at(k)
	queue_redraw()



func _night_tint() -> Color:
	var nl: NightLayer = gw.night
	if nl == null or nl.factor <= 0.01:
		var was: bool = _night_on
		_night_on = false
		if was:
			return Color(1, 1, 1, 0.999)
		return Color.WHITE
	_night_on = true
	var t: Color = nl.grade.lerp(NightLayer.NIGHT_TINT, nl.factor).lerp(Color.WHITE, 0.2)
	t.a = 1.0
	return t



func _fire_cycle() -> void :
	var now: float = gw.game_time
	for k in range(fires_live.size() - 1, -1, -1):
		var e: Array = fires_live[k]
		var s: AnimatedSprite2D = e[0]
		if not s.visible or int(s.get_meta("gen", -1)) != int(e[1]):
			fires_live.remove_at(k)
			continue
		var t0: float = e[2]
		var total: float = maxf(float(e[3]) - t0, 1.0)
		var age: float = now - t0
		var left: float = float(e[3]) - now
		var kin: float = clampf(total * 0.03, 0.5, 1.6) * float(e[6])
		var dying: float = clampf(total * 0.22, 3.0, 12.0)
		var pv: int = int(e[4])
		var nm: String = "fire_d_loop"
		if left >= dying:
			if age < kin:
				nm = "fire_k_loop"
			else:
				var g: int = mini(pv, int((age - kin) / maxf(kin * 1.2, 0.5)))
				if left < dying * 1.8:
					g = mini(g, maxi(pv - 1, 0))
				nm = FIRE_VARS[g]
		if String(s.animation) != nm:
			var info: Dictionary = (atlas_of[nm] as SpriteAtlas).info(nm)
			var fr: int = s.frame
			s.offset = Vector2( - float(info["ax"]), - float(info["ay"]))
			s.play(nm)
			s.frame = fr % maxi(1, int(info["frames"]))


func _draw() -> void :
	var v: Vision = gw.vision if gw != null else null
	for d: Dictionary in debris:
		var nm: String = d["n"]
		var info: Dictionary = fa.info(nm)
		var fr: int = int(float(d["t"]) * 12.0) % int(info["frames"])
		var p: Vector2 = (Vector2(d["g"]) + Vector2(0, - float(d["z"])) - Vector2(float(info["ax"]), float(info["ay"]))).round()
		var src: Rect2 = fa.rect(nm, fr)
		var size: Vector2 = src.size
		if bool(d["flip"]):
			size.x = - size.x
			p.x += src.size.x
		draw_texture_rect_region(fa.texture, Rect2(p, size), src)
