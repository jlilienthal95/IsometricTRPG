shader_type canvas_item;

const float GREEN_SATURATION_BOOST = 0.3;
const float GREEN_BRIGHTNESS_BOOST = 0.15;
// hue range for green — 0.0 is red, 0.33 is green, 0.66 is blue
const float GREEN_HUE_CENTER = 0.33;
const float GREEN_HUE_WIDTH = 0.12;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.1) discard;

	vec3 rgb = col.rgb;

	float cmax = max(rgb.r, max(rgb.g, rgb.b));
	float cmin = min(rgb.r, min(rgb.g, rgb.b));
	float delta = cmax - cmin;

	float saturation = (cmax < 0.001) ? 0.0 : delta / cmax;
	float value = cmax;

	float hue = 0.0;
	if (delta > 0.001) {
		if (cmax == rgb.r) {
			hue = mod((rgb.g - rgb.b) / delta, 6.0) / 6.0;
		} else if (cmax == rgb.g) {
			hue = ((rgb.b - rgb.r) / delta + 2.0) / 6.0;
		} else {
			hue = ((rgb.r - rgb.g) / delta + 4.0) / 6.0;
		}
		if (hue < 0.0) hue += 1.0;
	}

	float hue_dist = abs(hue - GREEN_HUE_CENTER);
	float green_influence = clamp(1.0 - hue_dist / GREEN_HUE_WIDTH, 0.0, 1.0);

	float new_saturation = clamp(saturation + GREEN_SATURATION_BOOST * green_influence, 0.0, 1.0);
	float new_value = clamp(value + GREEN_BRIGHTNESS_BOOST * green_influence, 0.0, 1.0);

	float h = hue * 6.0;
	float f = h - floor(h);
	float p = new_value * (1.0 - new_saturation);
	float q = new_value * (1.0 - new_saturation * f);
	float t = new_value * (1.0 - new_saturation * (1.0 - f));

	vec3 result;
	int hi = int(floor(h));
	if (hi == 0) result = vec3(new_value, t, p);
	else if (hi == 1) result = vec3(q, new_value, p);
	else if (hi == 2) result = vec3(p, new_value, t);
	else if (hi == 3) result = vec3(p, q, new_value);
	else if (hi == 4) result = vec3(t, p, new_value);
	else result = vec3(new_value, p, q);

	COLOR = vec4(mix(rgb, result, green_influence), col.a);
}