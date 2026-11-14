class_name Unit
extends RefCounted


enum Type{TANK, INFANTRY, FPV, ATGM, ASSAULT, IFV, MORTAR, ARTY, MLRS, RECON, POLICE}
enum State{IDLE, MOVE, FIGHT, SIEGE, DEAD}

var id: int = 0
var type: int = Type.TANK
var country_id: int = 0
var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var frame: int = 0
var hp: float = 100.0
var max_hp: float = 100.0
var state: int = State.IDLE
var path: PackedVector2Array = PackedVector2Array()
var pi: int = 0
var target_city: int = -1
var home: Facility = null
var fire_cd: float = 0.0
var fpv_cd: float = 8.0
var target: Object = null
var life: float = 0.0
var jam_t: float = 0.0
var slot: Vector2 = Vector2.ZERO
var dead_t: float = 0.0
var post: Facility = null
var post_slot: int = -1
var entrenched: bool = false
var rpg_cd: float = 4.0
var smoke_used: bool = false

const KIT_GREN: int = 1
const KIT_SMOKE: int = 2
const KIT_FPV: int = 4
var kit: int = 0
var gren_cd: float = 3.0
var team: int = 0
var op_on: bool = false
var op_hold: bool = false
var op_move: bool = false
var cover: float = 1.0
var still_t: float = 0.0
var dug: bool = false
var hit_t: float = -99.0
var supp: float = 0.0
var no_post_until: float = 0.0
var salvo: int = 0
var salvo_t: float = 0.0
var aim: Vector2 = Vector2.INF
var base: Facility = null
var orbit: float = 0.0
var reinf: int = 0
var reinf_t: float = 0.0
var reinf_v: float = 0.0
var reinf_s: float = 0.0

## R-FORD: свой берег для выхода из реки при прерванном форсировании
var ford_bank: Vector2 = Vector2.INF


func ground() -> bool:
        return type != Type.FPV and type != Type.RECON


func air() -> bool:
        return type == Type.FPV or type == Type.RECON



func foot() -> bool:
        return type == Type.INFANTRY or type == Type.ASSAULT or type == Type.ATGM or type == Type.MORTAR



func indirect() -> bool:
        return type == Type.MORTAR or type == Type.ARTY or type == Type.MLRS


func vehicle() -> bool:
        return type == Type.TANK or type == Type.IFV or type == Type.ARTY or type == Type.MLRS or type == Type.POLICE


func update_frame() -> void :
        frame = posmod(roundi(rad_to_deg(heading) / 22.5), 16)


func alive() -> bool:
        return state != State.DEAD
