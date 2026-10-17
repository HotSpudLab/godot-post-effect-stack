#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
// rgba16f, matching the RGBA16F intermediate allocated in bloom.gd. This
// pass writes `lum - threshold`, which goes above 1.0; a UNORM buffer clamps
// that away. `color_image` keeps rgba8 -- that mismatch against the real
// RGBA16F colour buffer predates this and is harmless.
layout(set = 0, binding = 1, rgba16f) uniform image2D bright_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float threshold;
    float intensity;
    float blur_radius;
    float blur_passes;
    float padding;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }
    vec4 col = imageLoad(color_image, uv);
    float lum = dot(col.rgb, vec3(0.2125, 0.7154, 0.0721));
    float bright = max(0.0, lum - pc.threshold);
    vec3 result = col.rgb * bright / max(lum, 0.001);
    imageStore(bright_image, uv, vec4(result, 1.0));
}
