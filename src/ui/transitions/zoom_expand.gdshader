shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 start_focus = vec2(0.5, 0.5);
uniform vec2 end_focus = vec2(0.8, 0.8);
uniform float zoom_intensity = 5.0;
uniform float blur_intensity = 0.02;

void fragment() {
	vec2 uv = UV;

	// Move the focus point during the zoom.
	vec2 current_focus = mix(start_focus, end_focus, progress);

	float zoom = 1.0 + progress * zoom_intensity;
	vec2 expanded_uv = (uv - current_focus) / zoom + current_focus;

	if (expanded_uv.x < 0.0 || expanded_uv.x > 1.0 || expanded_uv.y < 0.0 || expanded_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, progress);
	} else {
		vec4 color = vec4(0.0);
		float total_weight = 0.0;
		int samples = 8;

		for (int i = 0; i < samples; i++) {
			float offset = float(i) / float(samples) * progress * blur_intensity;
			vec2 sample_uv = mix(expanded_uv, current_focus, offset);
			float weight = 1.0 - (float(i) / float(samples));
			color += texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0))) * weight;
			total_weight += weight;
		}

		COLOR = color / total_weight;
		COLOR.rgb *= (1.0 - progress * 0.3);
		float dist = distance(uv, current_focus);
		COLOR.rgb *= mix(1.0, 0.0, smoothstep(0.2, 0.8, dist * progress));
	}
}
