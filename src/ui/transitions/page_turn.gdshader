shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float curl_width : hint_range(0.05, 0.45) = 0.26;
uniform vec4 page_back_color : source_color = vec4(0.92, 0.86, 0.72, 1.0);
uniform vec4 crease_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.36);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.78, 0.24);

void fragment() {
	vec2 uv = UV;
	float fold_x = 1.02 - progress * 1.26;
	float fold_start = fold_x - curl_width;
	float fold_end = fold_x + curl_width * 0.68;

	if (uv.x <= fold_start) {
		vec4 color = texture(TEXTURE, uv);
		float edge_shadow = smoothstep(fold_start - 0.12, fold_start, uv.x) * 0.18;
		COLOR = mix(color, crease_shadow_color, edge_shadow);
	} else if (uv.x <= fold_x) {
		float local = clamp((uv.x - fold_start) / max(curl_width, 0.001), 0.0, 1.0);
		vec2 sample_uv = uv;
		sample_uv.x += sin(local * 3.14159265) * 0.028;
		sample_uv.y += (local - 0.5) * (local - 0.5) * 0.018;
		vec4 color = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
		color.rgb *= 1.0 - local * 0.28;
		color = mix(color, highlight_color, sin(local * 3.14159265) * 0.16);
		COLOR = color;
	} else if (uv.x <= fold_end) {
		float local = clamp((uv.x - fold_x) / max(fold_end - fold_x, 0.001), 0.0, 1.0);
		vec2 sample_uv = uv;
		sample_uv.x = clamp(fold_x - local * curl_width * 0.82, 0.0, 1.0);
		sample_uv.y += sin(local * 3.14159265) * 0.018;
		vec4 mirrored = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
		vec4 back = mix(page_back_color, mirrored, 0.22);
		float rim = smoothstep(0.0, 0.25, local) * (1.0 - smoothstep(0.72, 1.0, local));
		back = mix(back, crease_shadow_color, rim * 0.28);
		back = mix(back, highlight_color, (1.0 - local) * 0.18);
		back.a = 1.0 - smoothstep(0.84, 1.0, local) * 0.55;
		COLOR = back;
	} else {
		discard;
	}
}
