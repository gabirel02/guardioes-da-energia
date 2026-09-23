shader_type canvas_item;

uniform float rotation_angle : hint_range(-90.0, 90.0) = 0.0;
uniform float perspective_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV;
	float skew = radians(rotation_angle) * perspective_strength;
	uv.x += (uv.y - 0.5) * skew;
	COLOR = texture(TEXTURE, uv);
}