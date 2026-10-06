shader_type canvas_item;
// 色を抜く（神隠しルートの異界）。絵の色を明るさだけの灰色に寄せ、少し青白く染める。
// 1回の掛け算と足し算だけの軽いもの。画面全体ではなく、異界の日の小物と背景の層にだけかける（OtherworldZone）

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.93, 0.95, 1.0);

void fragment() {
	float l = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(l) * tint, amount);
}
