#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform image2D screen_tex;

layout(push_constant, std430) uniform Params {
	vec2 screen_size;
} p;

const vec3 MONOCHROME_SCALE = vec3(0.2126,0.7152,0.0722);

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	vec2 size = p.screen_size;
	if(px.x >= size.x || px.y >= size.y) return;

	imageStore(screen_tex, px, vec4(1.0 - imageLoad(screen_tex, px).xyz, 1.0));
}
