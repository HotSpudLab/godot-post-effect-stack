#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec4 screen_size_view_strength; // x=screen_size.x, y=screen_size.y, z=view, w=strength
    float radial;
    float _pad0;
    float _pad1;
    float _pad2;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = pc.screen_size_view_strength.xy;
    if (uv.x >= int(screen_size.x) || uv.y >= int(screen_size.y)) {
        return;
    }

    float strength = pc.screen_size_view_strength.w;
    vec2 texel_size = 1.0 / screen_size;
    vec2 uv_norm = vec2(uv) * texel_size;
    vec2 center = vec2(0.5);
    vec2 dir = uv_norm - center;

    float dist = length(dir);
    float amount = pc.radial > 0.5 ? strength * dist : strength;

    vec2 offset = normalize(dir) * amount;

    ivec2 uv_r = ivec2(clamp(vec2(uv) + offset * screen_size, vec2(0.0), screen_size - 1.0));
    ivec2 uv_b = ivec2(clamp(vec2(uv) - offset * screen_size, vec2(0.0), screen_size - 1.0));

    vec4 col = imageLoad(color_image, uv);
    float r = imageLoad(color_image, uv_r).r;
    float b = imageLoad(color_image, uv_b).b;

    imageStore(color_image, uv, vec4(r, col.g, b, col.a));
}
