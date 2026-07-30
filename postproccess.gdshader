shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int pixel_size = 4;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	float x = float(int(FRAGCOORD.x) % pixel_size);
	float y = float(int(FRAGCOORD.y) % pixel_size);
	x = FRAGCOORD.x + floor(float(pixel_size) / 2.0) - x;
	y = FRAGCOORD.y + floor(float(pixel_size) / 2.0) - y;
	ALBEDO = texture(screen_tex, vec2(x, y) / VIEWPORT_SIZE).rgb;
}