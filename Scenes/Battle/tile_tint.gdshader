shader_type canvas_item;

// Recolors a highlight sprite to a solid tint, using only the source texture's
// alpha as a shape mask. Needed because the highlight art is blue and plain
// modulate (a multiply) can't tint it toward colors the texture lacks — a
// route drawn over the blue range highlight would stay blue-on-blue.
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, mask * tint.a);
}
