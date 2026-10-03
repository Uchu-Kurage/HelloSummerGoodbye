shader_type canvas_item;
// 空のグラデーション。上は深い青、地平線に近づくほど白くかすむ（夏の空気の厚み）。
// sky_color は時間帯・季節で決まる空の色（TimeOfDay）。この色を中ほどに置き、上下を作る。

uniform vec4 sky_color : source_color = vec4(0.557, 0.773, 0.878, 1.0);
// 上の濃さ（0〜1）と、地平線のかすみの強さ
uniform float zenith_depth = 0.32;
uniform float horizon_haze = 0.5;
// 地平線（画面の上からの割合）
uniform float horizon = 0.66;
uniform vec3 haze_color : source_color = vec3(0.98, 0.97, 0.93);

void fragment() {
	float y = SCREEN_UV.y;
	vec3 base = sky_color.rgb;
	// 上：少し暗く、青みを強く
	vec3 zenith = base * (1.0 - zenith_depth) + vec3(-0.04, 0.0, 0.06) * zenith_depth;
	// 夜の暗い空ではかすみを弱める（地平線だけ白く浮かないように）
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 haze = mix(base, haze_color, horizon_haze * smoothstep(0.2, 0.7, lum));
	vec3 c = mix(zenith, base, smoothstep(0.0, 0.45, y));
	c = mix(c, haze, smoothstep(0.35, horizon, y));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
