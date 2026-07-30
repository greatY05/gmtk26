shader_type spatial;
uniform sampler2D albedo;
uniform float triplanar_scale : hint_range(0.01, 2.0) = 0.2;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;
uniform bool is_triplanar = true;

uniform float noise_scale : hint_range(0.001, 2.0) = 0.05;
uniform float noise_darken_strength : hint_range(0.0, 1.0) = 0.15;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash1D(vec2 s) {
	return fract(sin(dot(s, vec2(127.1, 311.7))) * 43758.5453);
}


vec2 hash2D2D(vec2 s) {
	vec2 i = vec2(0.0);
	return fract(sin(modf(vec2(dot(s, vec2(127.1,311.7)), dot(s, vec2(269.5,183.3))) / 3.14159, i))*43758.5453);
}

vec4 tex2DStochastic(sampler2D tex, vec2 uv, vec2 dx, vec2 dy, vec2 noise_uv) {
	mat4 BW_vx;
	vec2 skewUV = mat2(vec2(1.0, 0.0), vec2(-0.57735027, 1.15470054)) * (uv * 3.464);
	vec2 vxID = vec2(floor(skewUV));
	vec3 barry = vec3(fract(skewUV), 0);
	barry.z = 1.0 - barry.x - barry.y;
	BW_vx = ((barry.z > 0.0) ?
		mat4(vec4(vxID, 0, 0), vec4(vxID + vec2(0, 1), 0, 0), vec4(vxID + vec2(1, 0), 0, 0), vec4(barry, 0)) :
		mat4(vec4(vxID + vec2(1, 1), 0, 0), vec4(vxID + vec2(1, 0), 0, 0), vec4(vxID + vec2(0, 1), 0, 0), vec4(-barry.z, 1.0-barry.y, 1.0-barry.x, 0.0)));

	vec4 result = textureGrad(tex, uv + hash2D2D(BW_vx[0].xy), dx, dy) * BW_vx[3].x +
		textureGrad(tex, uv + hash2D2D(BW_vx[1].xy), dx, dy) * BW_vx[3].y +
		textureGrad(tex, uv + hash2D2D(BW_vx[2].xy), dx, dy) * BW_vx[3].z;

	// separate, independently-scaled grid just for the darkening pattern
	float darken = hash1D(floor(noise_uv)) ;
	result.rgb *= 1.0 - darken * noise_darken_strength;

	return result;
}



void fragment() {
	if (!is_triplanar) {
		vec2 noise_uv = UV * noise_scale;
		vec4 c = tex2DStochastic(albedo, UV, dFdx(UV), dFdy(UV), noise_uv);
		ALBEDO = c.rgb;
	} else{
	
	//three planar projections, scaled
	vec2 uv_x = world_pos.zy * triplanar_scale;
	vec2 uv_y = world_pos.xz * triplanar_scale;
	vec2 uv_z = world_pos.xy * triplanar_scale;

	//derivatives per-projection - each needs its own, not the mesh's UV
	vec2 noise_uv_x = world_pos.zy * noise_scale;
	vec2 noise_uv_y = world_pos.xz * noise_scale;
	vec2 noise_uv_z = world_pos.xy * noise_scale;


	vec4 sample_x = tex2DStochastic(albedo, uv_x, dFdx(uv_x), dFdy(uv_x), noise_uv_x);
	vec4 sample_y = tex2DStochastic(albedo, uv_y, dFdx(uv_y), dFdy(uv_y), noise_uv_y);
	vec4 sample_z = tex2DStochastic(albedo, uv_z, dFdx(uv_z), dFdy(uv_z), noise_uv_z);

	//blend weights from normal, sharpened so faces don't blend too softly
	vec3 blend = pow(abs(world_normal), vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z);
	
	vec4 c = sample_x * blend.x + sample_y * blend.y + sample_z * blend.z;
	ALBEDO = c.rgb;
	}
}