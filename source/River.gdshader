shader_type canvas_item;
render_mode unshaded;

uniform float flow_time = 0.0;

float water_mask(vec3 c) {
	// Only the painted teal water: excludes cream bridge, green banks and UI.
	return smoothstep(0.105, 0.17, c.b-c.r)
		* smoothstep(0.075, 0.14, c.g-c.r)
		* smoothstep(0.005, 0.035, c.b-c.g);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float mask = water_mask(base.rgb);
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float drift = flow_time * 10.0;
	// Downstream ripples, with a very small side-to-side movement of painted waves.
	vec2 offset = vec2(sin(pixel.y*0.055-flow_time*0.65),
		cos(pixel.x*0.035-flow_time*0.45)) * TEXTURE_PIXEL_SIZE * 0.7;
	vec4 moved = texture(TEXTURE, UV + offset);
	float safe_mask = mask * water_mask(moved.rgb);
	vec3 color = mix(base.rgb, moved.rgb, safe_mask*0.75);
	float lane = floor(pixel.x / 59.0);
	float phase = mod(lane*17.13, 71.0);
	float local_x = mod(pixel.x, 59.0);
	float local_y = mod(pixel.y-drift+phase+sin(local_x*0.1)*2.0, 71.0);
	float ripple = (1.0-smoothstep(0.5, 1.8, abs(local_y-35.5)))
		* smoothstep(9.0, 17.0, local_x)*(1.0-smoothstep(36.0, 47.0, local_x));
	color = mix(color, vec3(0.75,0.9,0.85), ripple*safe_mask*0.24);
	COLOR = vec4(color, base.a);
}
