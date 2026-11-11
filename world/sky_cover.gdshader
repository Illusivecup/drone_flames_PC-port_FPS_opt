shader_type canvas_item;
render_mode unshaded;
// R331 «закрытое небо» over a host's land (SkyCoverLayer, world/sky_cover_layer.gd), POLISH2 rework.
// TEXTURE = owners (L8, 1 texel per cell), same setup as the territory sprites (two children of them):
// mode 0 = DOME under the objects (child of Territory): a soft translucent tint of the whole host's land
//          in the coverer's colour, a dotted diamond «force-field» lattice at far / mid zoom, a slow light
//          sweep and a glow just inside the border;
// mode 1 = RIM above the objects but under the units (child of TerritoryBorder): a crisp 2-px band in the
//          coverer's colour right inside the host's border line (land borders and coasts alike), dark seam
//          outside, light line inside, bright glints marching along it. A second coverer alternates segments.
// flash[h] 0..1: an interception over h just happened (rim -> white, dome brighter), decays on the CPU.
// Distance to the border: exact 8-neighbour test near it, MapModeLayer's distance field (dist_tex) deeper.

uniform int mode = 0;
uniform sampler2D owner_tex : filter_nearest;
uniform sampler2D dist_tex : filter_linear;
uniform bool has_dist = false;
uniform vec2 world_size;
uniform vec4 cov_a[9] : source_color;  // per host id: first coverer colour (a = 0: no sky)
uniform vec4 cov_b[9] : source_color;  // second coverer (a = 0: none)
uniform float flash[9];
uniform float px_world = 1.0;  // world px per screen px (1 / zoom)
uniform float fade = 1.0;
uniform float tint = 0.1;  // dome alpha (zoom-dependent, set by the layer)
uniform float lat_a = 0.2;  // «net» lattice alpha (zoom-dependent: strong far, gone near)
uniform vec4 outline_col : source_color = vec4(0.043, 0.078, 0.188, 1.0);
uniform vec3 night_comp = vec3(1.0);  // the border's night pre-compensation (UnitsLayer._sync_border), copied by the layer

const float DR = 9.0;  // territory_dist.gdshader R + 1
const float RIM0 = 5.0;  // screen px from the border: the border line ends here (seam)

int owner_at(ivec2 c) {
	ivec2 cc = clamp(c, ivec2(0), ivec2(world_size) - ivec2(1));
	return int(texelFetch(owner_tex, cc, 0).r * 255.0 + 0.5);
}

void fragment() {
	vec2 cellf = UV * world_size;
	ivec2 c = ivec2(floor(cellf));
	int o = owner_at(c);
	if (o <= 0 || o > 8) {
		discard;
	}
	vec4 ca = cov_a[o];
	if (ca.a < 0.5) {
		discard;
	}
	vec4 cb = cov_b[o];
	vec2 sub = fract(cellf) * 4.0;
	float e = 999.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			if (owner_at(c + ivec2(dx, dy)) != o) {
				float ex = dx < 0 ? sub.x : (dx > 0 ? 4.0 - sub.x : -1.0);
				float ey = dy < 0 ? sub.y : (dy > 0 ? 4.0 - sub.y : -1.0);
				e = min(e, max(ex, ey));
			}
		}
	}
	if (e > 998.0 && has_dist) {
		float dv = texture(dist_tex, UV).r;
		if (dv < 0.98) {
			e = (dv * DR + 0.5) * 4.0;
		}
	}
	float u = max(px_world, 1.0);
	float s = e / u;  // screen px from the border
	vec2 sp = floor(cellf * 4.0 / u);  // screen-px grid: crisp pixels at every zoom
	float fl = clamp(flash[o], 0.0, 1.0);
	float diag = sp.x + sp.y;
	float RW = px_world >= 1.5 ? 3.0 : 2.0;  // colour band of the rim, screen px
	if (mode == 1) {
		if (s < RIM0 || s >= RIM0 + RW + 2.0) {
			discard;
		}
		if (s < RIM0 + 1.0) {
			COLOR = vec4(outline_col.rgb, 0.85 * fade);
		} else if (s < RIM0 + 1.0 + RW) {
			float ph = mod(diag - floor(TIME * 16.0), 20.0);
			bool second = cb.a > 0.5 && mod(floor((diag - floor(TIME * 16.0)) / 20.0), 2.0) > 0.5;
			vec3 col = mix(second ? cb.rgb : ca.rgb, vec3(1.0), 0.28);
			if (ph < 5.0) {
				col = mix(col, vec3(1.0), ph < 1.0 || ph >= 4.0 ? 0.45 : 0.8);  // glint
			}
			col = mix(col, vec3(1.0), 0.75 * fl);
			COLOR = vec4(col, fade);
		} else {
			COLOR = vec4(mix(ca.rgb, vec3(1.0), 0.6 + 0.3 * fl), (0.55 + 0.4 * fl) * fade);
		}
		COLOR.rgb = min(COLOR.rgb * night_comp, vec3(1.0));
	} else {
	// DOME (under the objects)
	vec3 tc = mix(ca.rgb, vec3(1.0), 0.22);
	float a = tint;
	if (lat_a > 0.0) {
		// the dome's «net» (as on the sky icon): a diamond lattice, 1 px lines every 10 screen px
		float d1 = mod(diag, 10.0);
		float d2 = mod(sp.x - sp.y + 1000.0, 10.0);
		if (d1 < 1.0 || d2 < 1.0) {
			a += lat_a;
			tc = mix(cb.a > 0.5 && d2 < 1.0 ? cb.rgb : ca.rgb, vec3(1.0), 0.45);
		}
	}
	// slow light sweep across the dome
	float band = mod(diag * 0.5 - TIME * 36.0, 520.0);
	if (band < 28.0) {
		a += 0.05 * (1.0 - abs(band - 14.0) / 14.0);
	}
	// glow just inside the rim (stepped, pixel look); the distance field limits it at far zoom
	float g0 = RIM0 + RW + 2.0;
	float gw = 10.0;
	if (s >= g0 - 2.0 && s < g0 + gw) {
		float g = clamp(1.0 - (s - g0) / gw, 0.0, 1.0);
		g = floor(g * 3.0 + 0.999) / 3.0;
		a += 0.26 * g;
	}
	a += 0.3 * fl;
	COLOR = vec4(min(tc * mix(vec3(1.0), night_comp, 0.6), vec3(1.0)), clamp(a, 0.0, 0.6) * fade);
	}
}
