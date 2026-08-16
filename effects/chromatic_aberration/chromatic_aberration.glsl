#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
// Snapshot of the colour buffer taken before this effect runs, supplied by the
// runner because the effect sets `needs_source_snapshot = true`. This effect
// reads pixels other than the one it writes, so it must not read `color_image`
// directly -- neighbouring workgroups may already have overwritten it, which
// makes the result depend on execution order. Bound as a `sampler2D` so the
// displaced reads below are interpolated rather than snapped to a texel.
layout(set = 0, binding = 1) uniform sampler2D source_image;

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
    // Texel centre, so a zero offset samples exactly one texel back.
    vec2 uv_norm = (vec2(uv) + 0.5) * texel_size;
    vec2 dir = uv_norm - vec2(0.5);

    float dist = length(dir);
    float amount = pc.radial > 0.5 ? strength * dist : strength;
    // `normalize()` is undefined at the exact centre of the frame. Guarding it
    // keeps that one pixel defined instead of leaving it to the driver.
    vec2 offset = dist > 1e-6 ? (dir / dist) * amount : vec2(0.0);

    vec2 lo = 0.5 * texel_size;
    vec2 hi = 1.0 - 0.5 * texel_size;

    vec4 col = texture(source_image, uv_norm);
    float r = texture(source_image, clamp(uv_norm + offset, lo, hi)).r;
    float b = texture(source_image, clamp(uv_norm - offset, lo, hi)).b;

    imageStore(color_image, uv, vec4(r, col.g, b, col.a));
}
