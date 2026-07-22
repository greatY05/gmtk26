shader_type spatial;

// --- CHARACTER BASE PROPERTIES ---
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// --- DASH EFFECT PROPERTIES ---
uniform float dash_intensity : hint_range(0.0, 5.0) = 0.0;
uniform float stretch_amount : hint_range(0.0, 1.0) = 0.5;
uniform float edge_fade : hint_range(0.0, 2.0) = 1.0;
uniform vec4 dash_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform vec3 dash_velocity = vec3(0.0, 0.0, 0.0); 
void vertex() {
    // If there is no movement velocity, skip the stretch math to save performance
    if (length(dash_velocity) > 0.001) {
        // 1. Normalize the direction vector
        vec3 move_dir = normalize(dash_velocity);
        
        // 2. See how aligned this vertex is with the movement direction.
        // A positive dot product means the vertex points forward in the direction of movement.
        float alignment = dot(VERTEX, move_dir);
        
        // 3. Stretch vertices that are trailing behind the center point
        if (alignment < 0.0) {
            // Pull the vertex BACKWARDS along the movement path
            VERTEX += move_dir * alignment * stretch_amount * dash_intensity;
        }
    }
}

void fragment() {
    // 1. Read base texture and mix with base color
    vec4 tex_color = texture(texture_albedo, UV);
    vec3 base_rgb = tex_color.rgb * albedo_color.rgb;
    
    // 2. Calculate the dash effect glow intensity
    float depth = -VERTEX.z;
    float dash_glow = clamp(1.0 - (depth * edge_fade), 0.0, 1.0) * dash_intensity;
    
    // 3. Blend character colors with dash speed colors
    ALBEDO = mix(base_rgb, dash_color.rgb, dash_glow * dash_color.a);
    
    // 4. Standard PBR material settings
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
