#[compute]
#version 450

// Source-snapshot pass.
//
// Copies the colour buffer into a separate texture so that an effect which
// samples pixels other than the one it writes has a read source that nothing
// is writing to. The colour buffer does not carry
// `TEXTURE_USAGE_CAN_COPY_FROM_BIT`, so `RenderingDevice.texture_copy()` fails
// on it and a compute pass is the only way to take this copy (measured
// 2026-08-11, capture/stage2_probe/).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Both bindings say rgba8 even though the real colour buffer (and therefore
// the snapshot, allocated to match it in effect_dispatch.gd) is RGBA16F on
// every renderer this addon has been measured against. That mismatch is
// deliberate, not an oversight: this exact combination -- a real RGBA16F
// texture read/written through an rgba8-qualified binding -- has been
// verified to round-trip values above 1.0 with zero pixel loss, including
// on this copy path specifically. Do not "fix" the qualifier without
// re-verifying; a driver that enforces it strictly could clamp the range
// this pass exists to preserve.
layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
layout(set = 0, binding = 1, rgba8) uniform image2D snapshot_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float padding;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }
    imageStore(snapshot_image, uv, imageLoad(color_image, uv));
}
