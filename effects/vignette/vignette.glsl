#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec4 screen_size_view; // x=screen_size.x, y=screen_size.y, z=view, w=intensity
    vec4 color_smoothness; // x=color.r, y=color.g, z=color.b, w=smoothness
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = pc.screen_size_view.xy;
    if (uv.x >= int(screen_size.x) || uv.y >= int(screen_size.y)) {
        return;
    }
    vec4 col = imageLoad(color_image, uv);

    vec2 center = screen_size * 0.5;
    float dist = distance(vec2(uv), center) / length(center);
    float vignette = smoothstep(0.5, 0.5 + pc.color_smoothness.w, dist);
    vec3 result = mix(col.rgb, pc.color_smoothness.rgb, vignette * pc.screen_size_view.w);

    imageStore(color_image, uv, vec4(result, col.a));
}
