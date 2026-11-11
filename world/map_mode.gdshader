shader_type canvas_item;
render_mode unshaded;
// Map view overlay (MapModeLayer), a world-sized sprite drawn right under the border line:
// re-colours what is already on screen (terrain, fill, static objects) per map mode.
// 1 political: terrain desaturated, flat strong country colours.
// 2 my land: everything outside the player's land grey and dark, own land untouched.
// 3 ores: world dimmed and desaturated (deposit pins of EcoLayer are drawn above).
// 4 logistics: world dimmed, roads / bridges / railways bright (flags_tex, rail_tex).
// 5 military: world slightly dimmed, countries lightly tinted.
// 6 alliances: members in their alliance colour, countries outside alliances grey (R320 ALLY320).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D owner_tex : filter_nearest;
uniform sampler2D flags_tex : filter_nearest;  // WorldData.flags (1 road, 2 bridge, 8 city)
uniform sampler2D rail_tex : filter_nearest;  // Rail.mask (tracks per cell)
uniform bool has_logi = false;
uniform vec2 world_size;
uniform vec4 colors[9] : source_color;
uniform vec4 ally_cols[9] : source_color;  // R320 ALLY320: alliance colour per country (alpha 0 = in no alliance)
uniform int map_mode = 0;
uniform int player_id = 0;
uniform float px_world = 1.0;

ivec2 cl(ivec2 c) {
	return clamp(c, ivec2(0), ivec2(world_size) - ivec2(1));
}

int owner_at(ivec2 c) {
	return int(texelFetch(owner_tex, cl(c), 0).r * 255.0 + 0.5);
}

int flags_at(ivec2 c) {
	return int(texelFetch(flags_tex, cl(c), 0).r * 255.0 + 0.5);
}

float rail_at(ivec2 c) {
	return texelFetch(rail_tex, cl(c), 0).r;
}

void fragment() {
	vec2 cellf = UV * world_size;
	ivec2 c = ivec2(floor(cellf));
	int o = owner_at(c);
	vec3 s = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float l = dot(s, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(l);
	bool water = o == 0 && s.b > s.r + 0.1 && s.b > s.g;
	vec3 col = colors[min(o, 8)].rgb;
	vec3 outc = s;
	if (map_mode == 1) {
		vec3 base = mix(s, grey, 0.85) * 0.8 + 0.12;
		if (water) {
			base = mix(s, grey, 0.45) * 0.85;
		}
		if (o > 0) {
			base = mix(base, col, 0.6);
		}
		outc = base;
	} else if (map_mode == 2) {
		if (o == player_id && o > 0) {
			discard;
		}
		outc = water ? mix(s, grey, 0.75) * 0.5 : grey * 0.42 + vec3(0.05, 0.055, 0.07);
	} else if (map_mode == 3) {
		float k = (o == player_id && o > 0) ? 0.72 : 0.48;
		outc = mix(s, grey, 0.8) * k;
	} else if (map_mode == 4) {
		outc = mix(s, grey, 0.85) * 0.42;
		if (has_logi) {
			// Roads / rails at least ~2 screen px wide: look one cell around when zoomed out.
			int f = flags_at(c);
			float r = rail_at(c);
			int rad = px_world >= 2.0 ? 1 : 0;
			int fn = 0;
			float rn = 0.0;
			for (int dy = -rad; dy <= rad; dy++) {
				for (int dx = -rad; dx <= rad; dx++) {
					if (abs(dx) + abs(dy) <= rad) {
						fn |= flags_at(c + ivec2(dx, dy));
						rn = max(rn, rail_at(c + ivec2(dx, dy)));
					}
				}
			}
			if (r > 0.0 || rn > 0.0) {
				// Railway (R332b): only a dark trace here - MapModeLayer draws the rail map sign over it
				// (vector casing + crimson / cream ties), so a road under a track never reads as a road.
				outc = mix(outc, vec3(0.1, 0.07, 0.09), r > 0.0 ? 0.55 : 0.3);
			} else if ((f & 2) != 0 || (fn & 2) != 0) {
				outc = (f & 2) != 0 ? vec3(1.0, 0.76, 0.24) : vec3(0.7, 0.5, 0.15);
			} else if ((f & 1) != 0 && (f & 8) != 0) {
				// City streets: visible but quieter than the roads between cities.
				outc = mix(outc, vec3(0.75, 0.73, 0.68), 0.5);
			} else if ((f & 1) != 0 || ((fn & 1) != 0 && (f & 8) == 0)) {
				outc = (f & 1) != 0 ? mix(s, vec3(0.98, 0.95, 0.84), 0.8) : vec3(0.6, 0.58, 0.52);
			} else if ((f & 8) != 0) {
				outc = mix(s, grey, 0.6) * 0.62;
			}
		}
	} else if (map_mode == 6) {
		vec3 base = mix(s, grey, 0.85) * 0.6 + 0.12;
		if (water) {
			base = mix(s, grey, 0.45) * 0.8;
		}
		if (o > 0) {
			// members: near-solid alliance colour (terrain shading kept faintly); others: neutral mid grey
			vec4 ac = ally_cols[min(o, 8)];
			base = ac.a > 0.5 ? ac.rgb * (0.78 + 0.3 * l) : vec3(0.42, 0.42, 0.41) + (l - 0.4) * 0.15;
		}
		outc = base;
	} else if (map_mode == 5) {
		vec3 base = mix(s, grey, 0.65) * 0.72;
		if (o > 0) {
			base = mix(base, col, 0.18);
		}
		outc = base;
	} else if (map_mode == 7) {
		// CAM324 AD cover: quiet grey map, the coverage (AdCoverLayer) carries the colour
		outc = water ? mix(s, grey, 0.6) * 0.6 : mix(s, grey, 0.8) * 0.62 + 0.04;
	} else {
		discard;
	}
	COLOR = vec4(outc, 1.0);
}
