shader_type canvas_item;
render_mode unshaded;
// v0.19 clouds (world/vfx_clouds.gd): ONE quad over the view. Soft stepped cloud SHADOWS at
// every zoom + WorldBox-like pixel cumulus at far zoom only. The cloud field is a tileable data
// texture (tools/art/gen_vfx19_clouds.py: R coverage, G tone; 1 texel = `texel` world px).
// World px in, so everything stays on the world grid and scrolls with the wind.

uniform sampler2D cloud_tex : filter_nearest, repeat_enable;
uniform sampler2D cloud_lin : filter_linear, repeat_enable;
uniform vec2 drift = vec2(0.0);
uniform float cloud_a = 0.0;    // 0 = no clouds (zoomed in / setting off)
uniform float shadow_a = 0.1;
uniform float texel = 8.0;      // world px per cloud texel
uniform float tex_n = 512.0;    // texels per tile
uniform float sgrid = 4.0;      // shadow pixel, world px
uniform vec2 shadow_off = vec2(-110.0, -170.0);  // shadow falls down-right of its cloud
uniform vec4 clear_pts[8];      // xy world point, z 1 / radius (v0.20), w opacity at its centre
uniform int clear_n = 0;
// v0.20: clouds thin over the player's land and the land of countries at war with him
// (land_tex: low-res opacity mask built by vfx_clouds.gd, linear = soft edges) and fade to
// ~0.2 in targeting modes (dim).
uniform sampler2D land_tex : filter_linear;
uniform vec2 land_px = vec2(0.0);  // world px covered by land_tex; 0 = off
uniform float dim = 1.0;
uniform vec3 c_lit : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 c_mid : source_color = vec3(0.886, 0.914, 0.949);
uniform vec3 c_shade : source_color = vec3(0.706, 0.765, 0.851);
uniform vec3 c_shadow : source_color = vec3(0.02, 0.06, 0.12);

varying vec2 wp;

void vertex() {
	wp = VERTEX;
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int k = i.x + i.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[k] + 0.5) / 16.0;
}

float clear_f(vec2 p) {
	float f = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i >= clear_n) {
			break;
		}
		vec4 c = clear_pts[i];
		float q = distance(p, c.xy) * c.z;
		f = min(f, mix(c.w, 1.0, smoothstep(0.45, 1.0, q)));
	}
	return f;
}

float land_f(vec2 p) {
	return land_px.x < 1.0 ? 1.0 : texture(land_tex, p / land_px).r;
}

void fragment() {
	float span = texel * tex_n;
	vec2 sc = floor(wp / sgrid);
	// fract(): wrap by hand - the Compatibility renderer ignored repeat_enable here and clamped
	// at the tile edge (straight horizontal cuts through clouds and shadows, v0.19 fix).
	float sd = texture(cloud_lin, fract((sc * sgrid + drift + shadow_off) / span)).r;
	float sa = floor(clamp(sd * 1.5, 0.0, 1.0) * 2.0 + bayer4(sc)) * 0.5 * shadow_a;
	float ca = 0.0;
	vec3 col = c_mid;
#ifndef SHADOW_ONLY
	// (v0.20: vfx_clouds.gd swaps in a SHADOW_ONLY build of this shader when zoomed in)
	if (cloud_a > 0.003) {
		vec4 c = texture(cloud_tex, fract((wp + drift) / span));
		if (c.r > 0.0) {
			vec2 dc = floor((wp + drift) / (texel * 0.5));
			float k = cloud_a * clear_f(wp) * land_f(wp) * dim;
			if (c.r > 0.75) {
				// solid body: one flat translucent step per tone (clean shapes, no noise)
				ca = floor(k * (c.g > 0.8 ? 1.0 : 0.92) * 8.0 + 0.5) / 8.0;
			} else {
				// 1-texel rim: half the pixels (ordered dither) = soft pixel edge
				ca = bayer4(dc) < 0.5 ? floor(k * 0.8 * 8.0 + 0.5) / 8.0 : 0.0;
			}
			col = c.g > 0.8 ? c_lit : (c.g > 0.4 ? c_mid : c_shade);
		}
	}
#endif
	float a = ca + sa * (1.0 - ca);
	vec3 rgb = (col * ca + c_shadow * sa * (1.0 - ca)) / max(a, 0.0001);
	COLOR = vec4(rgb, a);
}
