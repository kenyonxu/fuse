@tool
@abstract
extends BaseInstruction
class_name BaseTweenInstruction

## Tween 指令基类，提供通用功能
##
## 所有 Tween 类指令都应该继承此基类以获得：
## - 缓动类型和过渡类型枚举定义
## - 统一的 Tween 创建和配置方法
## - 标准的节点获取逻辑（支持相对路径）
##
## 子类需要实现：
## - _update_resource_name() - 更新资源名称
## - _setup_metadata() - 设置指令元数据
## - execute() - 执行指令逻辑
## - get_description() - 获取指令描述
## - validate() - 验证指令参数

## 缓动类型枚举
##
## 定义了 Tween 的缓动类型，控制动画的加速和减速行为
enum EasingType {
	EASE_IN,      ## 缓入（开始慢，后来快）
	EASE_OUT,     ## 缓出（开始快，后来慢）
	EASE_IN_OUT,  ## 缓入缓出（两端慢，中间快）
	EASE_OUT_IN   ## 缓出缓入（两端快，中间慢）
}

## 过渡类型枚举
##
## 定义了 Tween 的过渡类型，控制动画的插值曲线
enum TransitionType {
	LINEAR,   ## 线性过渡
	SINE,     ## 正弦过渡
	QUAD,     ## 二次过渡
	CUBIC,    ## 三次过渡
	QUART,    ## 四次过渡
	QUINT,    ## 五次过渡
	EXPO,     ## 指数过渡
	CIRC,     ## 圆形过渡
	BACK,     ## 回弹过渡
	SPRING,   ## 弹簧过渡
	BOUNCE,   ## 弹跳过渡
	ELASTIC   ## 弹性过渡
}

## 创建并配置 Tween
##
## 在目标节点上创建一个 Tween 对象
##
## 参数：
## - target: Node - 目标节点
##
## 返回：
## - Tween - 创建的 Tween 对象
func _create_tween(target: Node) -> Tween:
	var tween = target.create_tween()
	return tween

## 应用缓动设置
##
## 将自定义的缓动类型和过渡类型枚举转换为 Godot Tween 的枚举值并应用
##
## 参数：
## - tween: Tween - 要配置的 Tween 对象
## - easing_type: int - EasingType 枚举值
## - trans_type: int - TransitionType 枚举值
func _apply_easing_settings(tween: Tween, easing_type: int, trans_type: int) -> void:
	var tween_easing = Tween.EaseType.EASE_IN_OUT
	var tween_trans = Tween.TransitionType.TRANS_SINE

	# 转换 easing_type
	match easing_type:
		EasingType.EASE_IN:
			tween_easing = Tween.EaseType.EASE_IN
		EasingType.EASE_OUT:
			tween_easing = Tween.EaseType.EASE_OUT
		EasingType.EASE_IN_OUT:
			tween_easing = Tween.EaseType.EASE_IN_OUT
		EasingType.EASE_OUT_IN:
			tween_easing = Tween.EaseType.EASE_OUT_IN

	# 转换 trans_type
	match trans_type:
		TransitionType.LINEAR:
			tween_trans = Tween.TransitionType.TRANS_LINEAR
		TransitionType.SINE:
			tween_trans = Tween.TransitionType.TRANS_SINE
		TransitionType.QUAD:
			tween_trans = Tween.TransitionType.TRANS_QUAD
		TransitionType.CUBIC:
			tween_trans = Tween.TransitionType.TRANS_CUBIC
		TransitionType.QUART:
			tween_trans = Tween.TransitionType.TRANS_QUART
		TransitionType.QUINT:
			tween_trans = Tween.TransitionType.TRANS_QUINT
		TransitionType.EXPO:
			tween_trans = Tween.TransitionType.TRANS_EXPO
		TransitionType.CIRC:
			tween_trans = Tween.TransitionType.TRANS_CIRC
		TransitionType.BACK:
			tween_trans = Tween.TransitionType.TRANS_BACK
		TransitionType.SPRING:
			tween_trans = Tween.TransitionType.TRANS_SPRING
		TransitionType.BOUNCE:
			tween_trans = Tween.TransitionType.TRANS_BOUNCE
		TransitionType.ELASTIC:
			tween_trans = Tween.TransitionType.TRANS_ELASTIC

	tween.set_ease(tween_easing)
	tween.set_trans(tween_trans)

## 获取目标节点
##
## 使用 ExecutionContext 获取目标节点，支持相对路径解析
##
## ✅ 正确用法：使用 context.get_node() 支持相对路径
## ❌ 错误用法：直接使用 get_node() 或 SceneTree.get_node()
##
## 参数：
## - context: ExecutionContext - 执行上下文
## - node_path: NodePath - 节点路径
##
## 返回：
## - Node - 找到的节点，如果未找到则返回 null
func _get_target_node(context: ExecutionContext, node_path: NodePath) -> Node:
	# 使用 context.get_node() 以支持相对路径解析
	return context.get_node(node_path)
