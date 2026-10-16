#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float intensity;
    float time;
    float _padding;
} pc;

float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }
    vec4 col = imageLoad(color_image, uv);

    float grain = hash(vec3(float(uv.x), float(uv.y), pc.time)) * 2.0 - 1.0;
    float lum = dot(clamp(col.rgb, 0.0, 1.0), vec3(0.2125, 0.7154, 0.0721));
    float response = 1.0 - sqrt(lum);
    col.rgb += col.rgb * grain * pc.intensity * response;

    imageStore(color_image, uv, col);
}
