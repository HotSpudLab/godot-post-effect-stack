shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float smoothness : hint_range(0.0, 1.0) = 0.3;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    vec2 uv = SCREEN_UV * 2.0 - 1.0;
    float dist = length(uv);
    float vignette = smoothstep(1.0, 1.0 - smoothness, dist);
    vignette = mix(1.0, vignette, intensity);
    COLOR = vec4(mix(vignette_color.rgb, color.rgb, vignette), color.a);
}
