# 文字烧蚀效果 (Text Burn Effect)

## 概述

这是一个用于 Godot Label 控件的烧蚀效果 shader，通过 float 参数（0~1）控制从左到右的烧蚀程度，边缘呈现不规则的烧蚀效果。

## 文件结构

```
addons/fuse/texture/
├── text_burn.gdshader           # Shader 源码
├── text_burn_material.tres      # 材质资源
├── noise_texture_2d.tres        # 噪声纹理
├── test_text_burn.tscn          # 测试场景
├── test_text_burn.gd            # 测试脚本
└── text_burn_readme.md          # 本文档
```

## 使用方法

### 1. 直接使用材质

```gdscript
extends Label

@onready var burn_material: ShaderMaterial = preload("res://addons/fuse/texture/text_burn_material.tres")

func _ready():
    material = burn_material

# 设置烧蚀进度 (0.0 = 完全烧掉, 1.0 = 完好)
func set_burn(value: float):
    material.set_shader_parameter("burn_progress", clamp(value, 0.0, 1.0))
```

### 2. 代码中创建材质

```gdscript
extends Label

var burn_material: ShaderMaterial

func _ready():
    burn_material = ShaderMaterial.new()
    burn_material.shader = preload("res://addons/fuse/texture/text_burn.gdshader")
    burn_material.set_shader_parameter("burn_noise", preload("res://addons/fuse/texture/noise_texture_2d.tres"))
    material = burn_material
```

## Shader 参数

| 参数 | 类型 | 范围 | 默认值 | 说明 |
|------|------|------|--------|------|
| `burn_progress` | float | 0.0 ~ 1.0 | 1.0 | 烧蚀进度，0=完全烧掉，1=完好 |
| `burn_noise` | sampler2D | - | - | 噪声纹理，用于生成不规则边缘 |
| `edge_softness` | float | 0.0 ~ 0.5 | 0.1 | 边缘柔和度 |
| `edge_width` | float | 0.0 ~ 0.5 | 0.15 | 烧蚀边缘宽度（不规则程度） |
| `burn_color` | Color | - | (1.0, 0.3, 0.0) | 烧蚀边缘颜色 |
| `glow_intensity` | float | 0.0 ~ 2.0 | 0.8 | 辉光强度 |

## 测试场景

打开 `test_text_burn.tscn` 可以：
- 拖动滑块实时查看烧蚀效果
- 调整参数观察不同效果

## 效果说明

- **burn_progress = 0.0**: 文字从左侧完全烧蚀消失
- **burn_progress = 0.5**: 文字烧蚀到中间位置
- **burn_progress = 1.0**: 文字完全显示，完好无损

烧蚀边缘具有以下特性：
- 使用噪声生成不规则边缘
- 带有辉光效果
- 边缘柔和可调

## 自定义噪声纹理

如需自定义烧蚀效果，可以替换 `noise_texture_2d.tres`：

1. 创建新的 `NoiseTexture2D` 资源
2. 调整噪声类型（Perlin/Simplex/等）
3. 调整噪声大小和细节
4. 在材质中替换 `burn_noise` 参数

## 注意事项

1. 该 shader 仅适用于 `CanvasItem` 类型（Label、RichTextLabel 等）
2. 确保噪声纹理资源路径正确
3. 在编辑器中预览时，可能需要运行场景才能看到动态效果
4. 对于大量使用烧蚀效果的 UI，注意性能影响
