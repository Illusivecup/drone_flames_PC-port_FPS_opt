class_name ColorGrade
extends RefCounted







static var enabled: bool = true

static var strength: float = 1.0

const GOLDEN: = Color(1.0, 0.9, 0.76)
const MORNING: = Color(0.88, 0.94, 1.0)



static func tint_at(ph: float) -> Color:
	if not enabled or strength <= 0.0:
		return Color.WHITE
	var g: float = 0.0
	if ph >= 0.38 and ph < 0.66:
		g = smoothstep(0.38, 0.52, ph)
	var c: float = 0.0
	if ph < 0.14:
		c = 1.0 - smoothstep(0.0, 0.14, ph)
	elif ph >= 0.88:
		c = smoothstep(0.88, 1.0, ph)
	return Color.WHITE.lerp(GOLDEN, g * strength) * Color.WHITE.lerp(MORNING, c * strength)


static func tint(night: NightLayer) -> Color:
	if not GameConfig.night or not GameConfig.day_grade or night == null or night.gw == null:
		return Color.WHITE
	var ph: float = fmod(night.gw.game_time + NightLayer.DAY_LEN * 0.05, NightLayer.DAY_LEN) / NightLayer.DAY_LEN
	return tint_at(ph)
