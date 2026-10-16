shader_type canvas_item;
// 青年期の回想の色：全体に温かい色をかけ、ふちを茶色く暗くする（古い写真のように）

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.5, 0.22);
uniform vec4 edge : source_color = vec4(0.42, 0.26, 0.12, 0.7);
uniform float amount = 0.0;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.75);
	float v = smoothstep(0.18, 0.6, length(d));
	vec3 c = mix(tint.rgb, edge.rgb, v);
	float a = mix(tint.a, edge.a, v);
	COLOR = vec4(c, a * amount);
}
