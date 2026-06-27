shader_type canvas_item;

uniform float clip_threshold: hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (UV.y > clip_threshold) {
		col.a = 0.0;
	}
	COLOR = col;
}