shader_type canvas_item;

// 进度控制：0.0 = 完全烧蚀，1.0 = 完好无损
uniform float burn_progress: hint_range(0.0, 1.0) = 1.0;

// 噪声纹理：用于创建不规则的烧蚀边缘
uniform sampler2D burn_noise : repeat_enable, filter_nearest;

// 边缘柔和度：烧蚀边缘的平滑程度
uniform float edge_softness: hint_range(0.0, 0.2) = 0.05;

// 发光边缘宽度：烧蚀前沿的发光带宽度
uniform float edge_width: hint_range(0.0, 0.3) = 0.1;

// 烧蚀渐变纹理：使用 GradientTexture1D 创建渐变色边缘
// 从左到右：靠近烧蚀边界 → 靠近完好区域
uniform sampler2D burn_gradient;

// 是否使用渐变纹理：false = 使用单色 burn_color，true = 使用 burn_gradient
uniform bool use_gradient = false;

// 默认烧蚀颜色：当 use_gradient = false 时使用
uniform vec4 burn_color : source_color = vec4(1.0, 0.3, 0.0, 1.0);

// 噪声强度：0 = 完全规则的方向性烧蚀，越大越不规则
uniform float noise_strength: hint_range(0.0, 0.5) = 0.1;

// 烧蚀方向角度（度）：0 = 从右向左，90 = 从下向上，180 = 从左向右，270 = 从上向下
uniform float direction_angle: hint_range(0.0, 360.0) = 0.0;

// 混合模式：决定发光边缘如何与原始纹理混合
uniform int blend_mode : hint_enum("Replace,Additive,Overlay") = 0;

// Inverse lerp function
// 将值 v 从范围 [a, b] 转换到范围 [0, 1]
float inverse_lerp(float a, float b, float v) {
	return (v - a) / (b - a);
}

void fragment() {
    vec4 main_texture = texture(TEXTURE, UV);
    float noise = texture(burn_noise, UV).r;

    // Godot 的 COLOR 内置变量已包含节点的调制颜色（modulate/font_color）
    // 字体纹理通常只有 alpha 通道，RGB 是白色
    // 所以我们使用 COLOR.rgb 作为文字颜色，main_texture.a 作为形状

    // 计算方向向量（从角度转换）
    float rad = radians(direction_angle);
    vec2 dir_vec = normalize(vec2(cos(rad), -sin(rad)));

    // 计算 UV 在烧蚀方向上的投影值（0 到 1）
    // 将 UV 中心移到 (0.5, 0.5)，然后投影到方向向量上
    float projected = dot(UV - 0.5, dir_vec) + 0.5;

    // 结合噪声创建烧蚀 mask
    // noise_strength = 0 时，完全按方向烧蚀
    // noise_strength > 0 时，边缘会变得不规则
    float mask = projected - (noise - 0.5) * noise_strength;

    // 计算进度阈值（带有边距）
    float margin = (edge_width + edge_softness) * 2.0;
    float threshold = mix(1.0 + margin, 0.0 - margin, burn_progress);

    // 文字可见度：使用 smoothstep 实现平滑过渡
    float text_alpha = 1.0 - smoothstep(threshold, threshold + edge_softness, mask);

    // 发光带：在烧蚀前沿创建发光效果
    float glow_start = threshold - edge_width;
    float glow_mask = smoothstep(glow_start, threshold, mask)
                    * (1.0 - smoothstep(threshold, threshold + edge_softness, mask));

    // 获取烧蚀颜色：根据 use_gradient 开关选择渐变纹理或单色
    vec4 burn_final_color;

    if (use_gradient) {
        // 从渐变纹理采样烧蚀颜色
        // 根据 mask 在发光带中的位置映射到渐变纹理的 U 坐标
        // mask = glow_start → U = 0（靠近烧蚀边界）
        // mask = threshold → U = 1（靠近完好区域）
        vec2 burn_uv = vec2(inverse_lerp(glow_start, threshold, mask), 0.0);
        burn_final_color = texture(burn_gradient, burn_uv);
    } else {
        // 使用单色
        burn_final_color = burn_color;
    }

    // 计算发光贡献
    vec3 glow_contribution = burn_final_color.rgb * glow_mask;

    // 根据混合模式决定最终颜色
    vec3 final_rgb;

    if (blend_mode == 0) {
        // Replace 模式：在烧蚀边缘使用烧蚀颜色
        // 使用更大的混合系数让烧蚀颜色更明显
        final_rgb = mix(COLOR.rgb, burn_final_color.rgb, glow_mask * 2.0);
    } else if (blend_mode == 1) {
        // Additive 模式：发光颜色叠加到原始颜色上
        // 适合浅色文字，增加亮度
        final_rgb = COLOR.rgb + glow_contribution;
    } else {
        // Overlay 模式：发光颜色与原始颜色混合
        // 保留更多原始纹理细节
        final_rgb = mix(COLOR.rgb, COLOR.rgb * (1.0 + glow_contribution), glow_mask);
    }

    // 最终透明度：文字和发光的最大值
    float final_a = max(text_alpha, glow_mask) * main_texture.a;

    COLOR = vec4(final_rgb, final_a);
}
