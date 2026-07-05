extends Control

## 文字烧蚀效果测试脚本

@onready var burn_label: Label = $VBoxContainer/BurnLabel
@onready var slider: HSlider = $VBoxContainer/HSlider
@onready var progress_label: Label = $VBoxContainer/ProgressLabel

var burn_material: ShaderMaterial

func _ready() -> void:
	# 获取材质引用
	burn_material = burn_label.material as ShaderMaterial

	# 连接滑块信号
	slider.value_changed.connect(_on_slider_changed)

	# 初始设置
	_update_burn_progress(slider.value)

func _on_slider_changed(value: float) -> void:
	_update_burn_progress(value)

func _update_burn_progress(value: float) -> void:
	if burn_material:
		burn_material.set_shader_parameter("burn_progress", value)

	# 更新进度显示
	var percentage = int(value * 100)
	progress_label.text = "烧蚀进度: %d%%" % percentage
