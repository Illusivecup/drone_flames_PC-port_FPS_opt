shader_type canvas_item;
render_mode unshaded;
// TEXTURE = owners (L8, 1 texel per cell, cell = 4x4 world px). Two sprites use this shader:
// mode 0 = fill under objects (dithered country colour, denser near the border),
// mode 1 = border line above objects: dark outer outline | country colour | light inner line,
// thickness in screen px (zoom-aware), war borders pulse red. Cells next to a border are
// measured exactly (8 neighbours); deeper cells use the distance field of MapModeLayer
// (dist_tex, see territory_dist.gdshader). map_mode = GameWorld.MapMode.

uniform sampler2D owner_tex : filter_nearest;
uniform sampler2D dist_tex : filter_linear;
uniform bool has_dist = false;
uniform vec2 world_size;
uniform vec4 colors[9] : source_color;
uniform vec4 ally_cols[9] : source_color;  // R320 ALLY320: alliances view - border in the alliance colour (alpha 0 = grey)
uniform vec4 over_cols[9] : source_color;  // v0.26 DIP2 subject stripe: overlord colour per subject (alpha 0 = free)
uniform float fill_alpha = 0.16;  // legacy, unused
uniform int mode = 0; // 0 = dithered fill (under objects), 1 = border line (above objects)
uniform float border_px = 1.0;  // legacy (set by main.gd), unused: px_world drives thickness
uniform float fill_scale = 1.0; // world px per dither texel (1/zoom when zoomed out)
uniform float px_world = 1.0;  // world px per screen px (1 / camera zoom)
uniform int map_mode = 0;  // 0 normal, 1 political, 2 my land, 3 ores, 4 logistics, 5 military
uniform int player_id = 0;
uniform int war_bits[9];
uniform vec4 outline_col : source_color = vec4(0.043, 0.078, 0.188, 1.0);
uniform vec4 war_col : source_color = vec4(0.91, 0.25, 0.165, 1.0);
// v0.20 night readability (mode 1, set by the UnitsLayer night instance): the border colours are
// pre-divided by the night / grade tint (clamped), so after NightLayer's multiply they keep most
// of their day colour; at night (night_k 0..1) the dark outline - useless on dark ground - takes
// the country colour, the inner line gets lighter and the colour band one unit wider.
uniform vec3 night_comp = vec3(1.0);
uniform float night_k = 0.0;
// R351 PERF: cells (x0, y0, x1, y1; end exclusive) whose distance field is not current yet (MapModeLayer._stale_upd).
uniform vec4 stale_box = vec4(0.0, 0.0, 1e9, 1e9);

const float DR = 9.0;  // territory_dist.gdshader R + 1

int owner_at(ivec2 c) {
	ivec2 cc = clamp(c, ivec2(0), ivec2(world_size) - ivec2(1));
	return int(texelFetch(owner_tex, cc, 0).r * 255.0 + 0.5);
}

bool at_war(int a, int b) {
	return a > 0 && b > 0 && a < 9 && b < 9 && ((war_bits[a] >> b) & 1) != 0;
}

void fragment() {
	vec2 cellf = UV * world_size;
	ivec2 c = ivec2(floor(cellf));
	int o = owner_at(c);
	if (o == 0) {
		discard;
	}
	bool mine = o == player_id;
	// Which countries this mode shows at all.
	if (map_mode == 2 || map_mode == 3) {
		if (!mine) {
			discard;
		}
	}
	vec2 sub = fract(cellf) * 4.0;
	// Distance (world px) from this fragment to the nearest foreign cell, war-enemy cell.
	float e = 99.0;
	float we = 99.0;
	// R351 PERF: a cell with a differing 8-neighbour is at most 1 cell from a border cell of the
	// distance field, so the bilinear sample there reads <= 1 + sqrt(2) cells: e <= 11.8 (<= 21.6 even
	// if the field went through an sRGB encode). A current field reading e > 22 means no neighbour
	// differs: the scan below would find nothing and e / we come from the same sample as before.
	bool fast = false;
	vec4 dv = vec4(1.0);
	if (has_dist) {
		vec2 cf = vec2(c);
		if (cf.x < stale_box.x || cf.y < stale_box.y || cf.x >= stale_box.z || cf.y >= stale_box.w) {
			dv = texture(dist_tex, UV);
			fast = (dv.r * DR + 0.5) * 4.0 > 22.0;
		}
	}
	for (int dy = -1; dy <= 1; dy++) {
		if (fast) {
			break;
		}
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			int on = owner_at(c + ivec2(dx, dy));
			if (on != o) {
				float ex = dx < 0 ? sub.x : (dx > 0 ? 4.0 - sub.x : -1.0);
				float ey = dy < 0 ? sub.y : (dy > 0 ? 4.0 - sub.y : -1.0);
				float dd = max(ex, ey);
				e = min(e, dd);
				if (at_war(o, on)) {
					we = min(we, dd);
				}
			}
		}
	}
	if (e > 98.0 && has_dist) {
		if (!fast) {
			dv = texture(dist_tex, UV);
		}
		e = (dv.r * DR + 0.5) * 4.0;
		if (dv.g < 0.999) {
			we = (dv.g * DR + 0.5) * 4.0;
		}
	}
	vec3 col = colors[min(o, 8)].rgb;
	if (map_mode == 6) {
		vec4 ac = ally_cols[min(o, 8)];
		col = ac.a > 0.5 ? ac.rgb : vec3(0.55, 0.55, 0.53);
	}
	// Line unit: one screen px, never thinner than one art pixel.
	float u = max(px_world, 1.0);
	float cw = px_world >= 0.99 ? 2.0 : 1.0;  // colour band, in units
	if (map_mode == 1 || map_mode == 5 || map_mode == 6) {
		cw += 1.0;
	}
	cw += night_k > 0.5 ? 1.0 : 0.0;
	float pulse = 0.5 + 0.5 * sin(TIME * 4.0);
	float war_k = map_mode == 5 ? 1.0 : 0.8;
	if (mode == 1) {
		float s = e / u;
		bool war = we / u < 2.0 + cw + (map_mode == 5 ? 2.0 : 0.0);
		if (map_mode == 4) {
			// Logistics: thin, quiet borders.
			if (s >= 1.0 + 1.0) {
				discard;
			}
			COLOR = s < 1.0 ? vec4(outline_col.rgb, 0.7) : vec4(col, 0.7);
		} else if (s < 1.0) {
			COLOR = vec4(outline_col.rgb, 1.0);
		} else if (s < 1.0 + cw) {
			vec3 cc = col;
			if (war) {
				// Front line: pulsing red / dark hazard stripes, readable for any country colour.
				vec2 wp = cellf * 4.0 / u;
				bool st = mod(floor((wp.x + wp.y) / 3.0), 2.0) < 1.0;
				vec3 hz = st ? war_col.rgb : outline_col.rgb;
				cc = mix(cc, hz, war_k * (0.55 + 0.45 * pulse));
			}
			COLOR = vec4(cc, 1.0);
		} else if (over_cols[min(o, 8)].a > 0.5 && s < 2.0 + cw) {
			// v0.26 DIP2 subject stripe: a dashed inner band in the overlord's colour (v0.27.2:
			// one unit wide, softened toward the light inner line - subtle)
			vec2 sp = cellf * 4.0 / u;
			bool dash = mod(floor((sp.x + sp.y) / 4.0), 2.0) < 1.0;
			vec3 lite = mix(col, vec3(1.0), 0.55);
			COLOR = dash ? vec4(mix(lite, over_cols[min(o, 8)].rgb, 0.8), 0.95) : vec4(lite, 0.85);
		} else if (s < 2.0 + cw) {
			COLOR = vec4(mix(col, vec3(1.0), 0.55), 0.85);
		} else if (war && map_mode == 5) {
			// Military: wide red glow on the war side of the front line.
			COLOR = vec4(war_col.rgb, 0.35 * pulse * (1.0 - (we / u - 2.0 - cw) / 2.0));
		} else {
			discard;
		}
		if (night_k > 0.0 && map_mode != 4) {
			if (s < 1.0) {
				COLOR.rgb = mix(outline_col.rgb, col, 0.6 * night_k);
			} else if (s >= 1.0 + cw && s < 2.0 + cw && over_cols[min(o, 8)].a < 0.5) {
				COLOR.rgb = mix(col, vec3(1.0), 0.55 + 0.25 * night_k);
			}
		}
		COLOR.rgb = min(COLOR.rgb * night_comp, vec3(1.0));
	} else {
		// Fill: only in the normal view (other views tint the world in the overlay); my-land
		// view keeps the normal look of the player's own land.
		if (map_mode != 0 && !(map_mode == 2 && mine)) {
			discard;
		}
		// v0.20: an edge band only (the old 2/16 checker over ALL land and cities hid units and
		// buildings): 5/16 at the border fading to none ~12 screen px inside; the my-land view
		// keeps a light 2/16 fill.
		// v0.20.1: far zoom (WorldBox "map of countries"): a calm flat tint over the whole
		// territory, full at zoom <= 0.35, gone at zoom 0.6; the edge band dither on top.
		float gw = clamp(12.0 * u, 16.0, 64.0);
		float g = 1.0 - smoothstep(0.0, gw, e);
		float dens = max(map_mode == 2 ? 2.0 : 0.0, floor(g * 5.0 + 0.5));
		float far_k = smoothstep(1.0 / 0.6, 1.0 / 0.35, px_world);
		ivec2 p = ivec2(floor(cellf * 4.0 / fill_scale)) & ivec2(3);
		const float B[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (B[p.y * 4 + p.x] < dens) {
			COLOR = vec4(col, 1.0);
		} else if (far_k > 0.01) {
			COLOR = vec4(col, (0.24 + 0.08 * g) * far_k);
		} else {
			discard;
		}
	}
}
