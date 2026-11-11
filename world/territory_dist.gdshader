shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Border distance field of the territory, 1 texel per cell, three passes (MapModeLayer):
// pass 0: R = boundary cell (a 4-neighbour has another owner), G = boundary with a war enemy.
// pass 1: horizontal distance (cells) to the nearest boundary / war-boundary cell, / (R + 1).
// pass 2: vertical pass -> Euclidean distance, / (R + 1). Cheap separable transform (2R + 5 fetches).

uniform sampler2D src : filter_nearest;
uniform int pass = 0;
uniform vec2 world_size;
uniform vec2 rect_origin = vec2(0.0);  // v0.28 PERF: the ColorRect covers only this box of cells
uniform vec2 rect_size = vec2(0.0);  // (0 = the whole map, as before)
uniform int war_bits[9];

const int R = 8;

ivec2 cl(ivec2 c) {
	return clamp(c, ivec2(0), ivec2(world_size) - ivec2(1));
}

int owner_at(ivec2 c) {
	return int(texelFetch(src, cl(c), 0).r * 255.0 + 0.5);
}

bool at_war(int a, int b) {
	return a > 0 && b > 0 && a < 9 && b < 9 && ((war_bits[a] >> b) & 1) != 0;
}

void fragment() {
	ivec2 c = rect_size.x > 0.0 ? ivec2(floor(rect_origin + UV * rect_size)) : ivec2(floor(UV * world_size));
	float rn = float(R + 1);
	if (pass == 0) {
		int o = owner_at(c);
		float b = 0.0;
		float e = 0.0;
		ivec2 nb[4] = ivec2[](ivec2(-1, 0), ivec2(1, 0), ivec2(0, -1), ivec2(0, 1));
		for (int i = 0; i < 4; i++) {
			int on = owner_at(c + nb[i]);
			if (on != o) {
				b = 1.0;
				if (at_war(o, on)) {
					e = 1.0;
				}
			}
		}
		COLOR = vec4(b, e, 0.0, 1.0);
	} else if (pass == 1) {
		float bx = rn;
		float ex = rn;
		for (int d = -R; d <= R; d++) {
			vec4 s = texelFetch(src, cl(c + ivec2(d, 0)), 0);
			float ad = abs(float(d));
			if (s.r > 0.5) {
				bx = min(bx, ad);
			}
			if (s.g > 0.5) {
				ex = min(ex, ad);
			}
		}
		COLOR = vec4(bx / rn, ex / rn, 0.0, 1.0);
	} else {
		float bd = rn;
		float ed = rn;
		for (int d = -R; d <= R; d++) {
			vec4 s = texelFetch(src, cl(c + ivec2(0, d)), 0);
			float hx = floor(s.r * rn + 0.5);
			float he = floor(s.g * rn + 0.5);
			float fd = float(d);
			if (hx < rn) {
				bd = min(bd, sqrt(hx * hx + fd * fd));
			}
			if (he < rn) {
				ed = min(ed, sqrt(he * he + fd * fd));
			}
		}
		COLOR = vec4(min(bd, rn) / rn, min(ed, rn) / rn, 0.0, 1.0);
	}
}
