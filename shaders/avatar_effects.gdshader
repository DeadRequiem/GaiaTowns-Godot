shader_type canvas_item;

uniform bool invert = false;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (invert) {
		color.rgb = vec3(1.0) - color.rgb;
	}
	COLOR = color;
}