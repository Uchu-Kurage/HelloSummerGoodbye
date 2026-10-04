shader_type canvas_item;
// 帯の絵（川など）の左右の端と上のふちを、だんだん透明にする。
// ノードの中の座標（足もとが y = 0）で、x = 0〜width の範囲に描いた帯に使う。

uniform float width = 600.0;
// 左右の端をぼかす幅
uniform float fade_x = 140.0;
// 上のふちの高さと、ぼかす幅
uniform float top_y = -86.0;
uniform float fade_top = 14.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float a = smoothstep(0.0, fade_x, local.x) * smoothstep(width, width - fade_x, local.x);
	a *= smoothstep(top_y, top_y + fade_top, local.y);
	COLOR = vec4(c.rgb, c.a * a);
}
