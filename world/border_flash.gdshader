shader_type canvas_item;
render_mode unshaded;
// New-territory flash (fx_spec.md section 4). TEXTURE: LA8, A = new cell, R = delay/0.5 s.

uniform float time_s = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
uniform vec4 tint_col : source_color = vec4(1.0, 0.690, 0.0, 1.0);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 d = texture(TEXTURE, UV);
	if (d.a < 0.5) {
		discard;
	}
	float t = time_s - d.r * 0.5;
	float a = 0.0;
	vec4 c = tint_col;
	if (t < 0.0) { a = 0.0; }
	else if (t < 0.08) { a = 1.0; c = flash_col; }
	else if (t < 0.24) { a = 0.5; }
	else if (t < 0.32) { a = 0.0; }
	else if (t < 0.48) { a = 0.5; }
	else if (t < 0.64) { a = 0.25; }
	else if (t < 0.90) { a = 0.125; }
	ivec2 p = ivec2(floor(wpos)) & ivec2(3);
	if (a <= (BAYER[p.y * 4 + p.x] + 0.5) / 16.0) {
		discard;
	}
	COLOR = vec4(c.rgb, 1.0);
}
