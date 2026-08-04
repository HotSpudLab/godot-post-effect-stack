shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float threshold : hint_range(0.0, 2.0) = 1.0;
uniform float intensity : hint_range(0.0, 5.0) = 0.8;
uniform float radius : hint_range(0.0, 0.05) = 0.01;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    float lum = dot(color.rgb, vec3(0.2125, 0.7154, 0.0721));
    float bright = max(0.0, lum - threshold);
    
    vec2 texel = 1.0 / vec2(textureSize(screen_texture, 0));
    vec4 bloom = vec4(0.0);
    float weight = 0.0;
    
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * radius;
            vec4 sample_color = texture(screen_texture, SCREEN_UV + offset);
            float sample_lum = dot(sample_color.rgb, vec3(0.2125, 0.7154, 0.0721));
            float sample_bright = max(0.0, sample_lum - threshold);
            float w = exp(-float(x * x + y * y) * 0.25);
            bloom += sample_color * sample_bright * w;
            weight += w;
        }
    }
    
    bloom /= max(weight, 0.001);
    COLOR = vec4(color.rgb + bloom.rgb * intensity, color.a);
}
