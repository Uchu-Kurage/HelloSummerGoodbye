shader_type canvas_item;
// 宝箱の影（拾い逃したアイテム）：絵の中は塗らず、まわりの輪郭の線だけを描く。
// 8 方向をのぞくだけの軽いシェーダー（宝箱の枠の中の小さな絵にだけ使う）

uniform vec4 line_color : source_color = vec4(0.396, 0.353, 0.294, 0.5);
// 線の太さ（絵の画素で。描く大きさに合わせて ItemSlot が決める）
uniform float width = 2.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = texture(TEXTURE, UV).a;
	float m = 0.0;
	m = max(m, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	m = max(m, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	m = max(m, texture(TEXTURE, UV + px * 0.7071).a);
	m = max(m, texture(TEXTURE, UV - px * 0.7071).a);
	m = max(m, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7071).a);
	m = max(m, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7071).a);
	// 絵のふちの外側だけ（中は塗らない）
	float edge = clamp(m - a, 0.0, 1.0);
	COLOR = vec4(line_color.rgb, line_color.a * edge);
}
