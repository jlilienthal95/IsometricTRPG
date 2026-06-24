// burning.gdshader
shader_type canvas_item;

uniform float time_scale: hint_range(0.5, 5.0) = 2.0;
uniform vec4 fire_color_low: source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform vec4 fire_color_high: source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float intensity: hint_range(0.0, 1.0) = 0.6;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float noise = rand(vec2(UV.x + TIME * time_scale, UV.y));
	float flicker = rand(vec2(floor(TIME * time_scale * 3.0), 0.0));
	vec4 fire_color = mix(fire_color_low, fire_color_high, noise);
	COLOR = mix(original, fire_color, intensity * original.a * (noise * 0.5 + flicker * 0.5));
	COLOR.a = original.a;
}