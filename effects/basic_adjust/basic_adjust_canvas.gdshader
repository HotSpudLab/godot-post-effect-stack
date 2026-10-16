shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float brightness : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float contrast : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float hue : hint_range(-180.0, 180.0, 1.0) = 0.0;
uniform float saturation : hint_range(-1.0, 1.0, 0.01) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 display = source.rgb;
	display += vec3(brightness);
	display = (display - vec3(0.5)) * (1.0 + contrast) + vec3(0.5);
	vec3 hsv = rgb_to_hsv(max(display, vec3(0.0)));
	hsv.x = fract(hsv.x + hue / 360.0);
	hsv.y = clamp(hsv.y * (1.0 + saturation), 0.0, 1.0);
	COLOR = vec4(hsv_to_rgb(hsv), source.a);
}
