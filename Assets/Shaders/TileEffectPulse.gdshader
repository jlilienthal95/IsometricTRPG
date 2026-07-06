shader_type canvas_item;

uniform vec4 colors[8]: source_color;
uniform int color_count = 1;
uniform float pulse_speed = 2.0;
uniform float pulse_min = 0.3;
uniform float pulse_max = 0.7;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.1) discard;

	float t = mod(TIME * pulse_speed, float(color_count));
	int index = int(floor(t));
	float blend = fract(t);

	int next_index = int(mod(float(index + 1), float(color_count)));
	vec4 current_color = colors[index];
	vec4 next_color = colors[next_index];
	vec4 pulse_color = mix(current_color, next_color, blend);

	float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed * 3.14159) + 1.0) * 0.5);
	COLOR = vec4(tex.rgb + pulse_color.rgb * pulse, tex.a);
}