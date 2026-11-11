shader_type canvas_item;
render_mode unshaded;
// v0.28.4 CONF-MAP: the peace conference tint over the defeated country's land (world/conf_map_layer.gd).
// A sprite of region_tex (one texel per world cell = territory number, 0 = not in the conference)
// drawn above the border line while the world is in the «my land» view centred on the defeated.
// Per territory (pal_tex: rgb colour, a = style / 255):
//   1 stays with the defeated: cream wash + sparse dots   2 yours, annex: solid
//   3 yours, puppet: wide stripes                          4 taken by another winner: dense hatch
//   5 another winner will take it (forecast): sparse hatch
// Dark + light lines between territories; the selected territory gets a dark/gold/dark ring.
// Line and pattern unit = one screen px, never thinner than one art pixel (like territory.gdshader).

uniform sampler2D region_tex : filter_nearest;
uniform sampler2D pal_tex : filter_nearest;
uniform vec2 rsize = vec2(1.0);
uniform int npal = 1;
uniform float px_world = 1.0;
uniform int sel = 0;  // selected territory number (index + 1), 0 = none
uniform float pulse = 0.0;

int reg_at(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= int(rsize.x) || c.y >= int(rsize.y)) {
		return 0;
	}
	return int(texelFetch(region_tex, c, 0).r * 255.0 + 0.5);
}

void fragment() {
	vec2 cellf = UV * rsize;
	ivec2 c = ivec2(floor(cellf));
	int r = reg_at(c);
	if (r == 0 || r > npal) {
		discard;
	}
	vec2 sub = fract(cellf) * 4.0;
	float ein = 99.0;
	float eout = 99.0;
	for (int dy = -2; dy <= 2; dy++) {
		for (int dx = -2; dx <= 2; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			int rn = reg_at(c + ivec2(dx, dy));
			if (rn != r) {
				float ex = dx < 0 ? sub.x + float(-dx - 1) * 4.0 : (dx > 0 ? 4.0 - sub.x + float(dx - 1) * 4.0 : -1.0);
				float ey = dy < 0 ? sub.y + float(-dy - 1) * 4.0 : (dy > 0 ? 4.0 - sub.y + float(dy - 1) * 4.0 : -1.0);
				float dd = max(ex, ey);
				if (rn == 0) {
					eout = min(eout, dd);
				} else {
					ein = min(ein, dd);
				}
			}
		}
	}
	float u = max(px_world, 1.0);
	vec4 pal = texelFetch(pal_tex, ivec2(r - 1, 0), 0);
	int style = int(pal.a * 255.0 + 0.5);
	vec3 col = pal.rgb;
	vec2 wp = floor(cellf * 4.0 / u);
	vec3 oc = col;
	float a = 0.0;
	if (style == 1) {
		bool dot = mod(wp.x, 4.0) < 1.0 && mod(wp.y + floor(wp.x / 4.0) * 2.0, 4.0) < 1.0;
		a = dot ? 0.6 : 0.12;
	} else if (style == 2) {
		a = 0.52;
	} else if (style == 3) {
		bool st = mod(floor((wp.x + wp.y) / 3.0), 2.0) < 1.0;
		oc = st ? col : mix(col, vec3(1.0), 0.5);
		a = st ? 0.58 : 0.36;
	} else if (style == 4) {
		bool h = mod(wp.x - wp.y, 4.0) < 1.5;
		a = h ? 0.85 : 0.14;
	} else if (style == 5) {
		bool h = mod(wp.x - wp.y, 6.0) < 1.0;
		a = h ? 0.7 : 0.06;
	} else {
		discard;
	}
	vec3 dark = vec3(0.106, 0.071, 0.047);
	float s_in = ein / u;
	float s_any = min(ein, eout) / u;
	if (r == sel) {
		a = min(1.0, a + 0.1);
		if (s_any < 1.0) {
			oc = dark;
			a = 1.0;
		} else if (s_any < 3.0) {
			oc = mix(vec3(1.0, 0.97, 0.85), vec3(1.0, 0.84, 0.37), pulse);
			a = 1.0;
		} else if (s_any < 4.0) {
			oc = dark;
			a = 0.85;
		}
	} else if (s_in < 1.0) {
		oc = dark;
		a = 0.85;
	} else if (s_in < 2.0) {
		oc = vec3(0.98, 0.95, 0.88);
		a = 0.45;
	}
	COLOR = vec4(oc, a);
}
