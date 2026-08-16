#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
// Snapshot of the colour buffer taken before the aberration pass. This effect
// reads pixels other than the one it writes, so it must not read `color_image`
// directly -- neighbouring workgroups may already have overwritten it, which
// makes the result depend on execution order.
layout(set = 0, binding = 1, rgba8) uniform image2D source_image;

layout(push_constant, std430) uniform PushConstant {
    vec4 screen_size_view_strength; // x=screen_size.x, y=screen_size.y, z=view, w=strength
    float radial;
    float mode; // 0 = snapshot colour -> source, 1 = aberration source -> colour
    float _pad1;
    float _pad2;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = pc.screen_size_view_strength.xy;
    if (uv.x >= int(screen_size.x) || uv.y >= int(screen_size.y)) {
        return;
    }

    // Pass 1: snapshot.
    if (pc.mode < 0.5) {
        imageStore(source_image, uv, imageLoad(color_image, uv));
        return;
    }

    // Pass 2: aberration, reading the snapshot.
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

    vec4 col = imageLoad(source_image, uv);
    float r = imageLoad(source_image, uv_r).r;
    float b = imageLoad(source_image, uv_b).b;

    imageStore(color_image, uv, vec4(r, col.g, b, col.a));
}
