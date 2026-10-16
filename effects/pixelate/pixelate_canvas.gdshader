shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float block_size : hint_range(1.0, 64.0) = 8.0;

void fragment() {
    vec2 screen_size = vec2(textureSize(screen_texture, 0));
    vec2 uv = SCREEN_UV * screen_size;
    float bs = max(1.0, block_size);
    vec2 block_uv = floor(uv / bs) * bs + vec2(bs * 0.5);
    COLOR = texture(screen_texture, block_uv / screen_size);
}
