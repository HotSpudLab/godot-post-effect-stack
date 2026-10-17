#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

// Snapshot of the colour buffer (uncomment when needs_source_snapshot = true).
// Required if you read any pixel other than the one you write: reading
// color_image at an offset races the workgroups writing it. Sampled, so
// fractional offsets are interpolated — see effects/chromatic_aberration/.
// layout(set = 0, binding = 1) uniform sampler2D source_image;

// Depth buffer (uncomment when needs_depth = true)
// Sampled via sampler2D, not a storage image — see effects/outline/outline.glsl
// Binding 1 normally, but 2 when needs_source_snapshot = true takes slot 1.
// layout(set = 0, binding = 1) uniform sampler2D depth_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float padding;
    // Add user parameters after this line
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }
    vec4 color = imageLoad(color_image, uv);

    // #COMPUTE_CODE: Write your effect here
    // Example: grayscale
    // float gray = dot(color.rgb, vec3(0.2125, 0.7154, 0.0721));
    // color = vec4(vec3(gray), color.a);

    imageStore(color_image, uv, color);
}
