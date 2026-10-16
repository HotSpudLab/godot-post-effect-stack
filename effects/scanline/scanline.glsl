#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec4 screen_size_view_line_count; // x=screen_size.x, y=screen_size.y, z=view, w=line_count
    vec4 intensity_smoothness;        // x=intensity, y=smoothness, z=0, w=0
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = pc.screen_size_view_line_count.xy;
    if (uv.x >= int(screen_size.x) || uv.y >= int(screen_size.y)) {
        return;
    }
    vec4 col = imageLoad(color_image, uv);

    float line_count = pc.screen_size_view_line_count.w;
    float intensity = pc.intensity_smoothness.x;
    float smoothness = pc.intensity_smoothness.y;

    float line = fract(float(uv.y) * line_count / screen_size.y);
    float scanline = smoothstep(0.0, smoothness, abs(line - 0.5) * 2.0);
    float factor = mix(1.0, scanline, intensity);

    imageStore(color_image, uv, vec4(col.rgb * factor, col.a));
}
