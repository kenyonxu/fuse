# Fuse Tween Instructions

Tween 补间动画指令集合，基于 Godot 原生 Tween 系统。

## 指令清单

### 基础属性动画 (P0-P1)
- TweenFadeIn - 淡入动画
- TweenFadeOut - 淡出动画 (支持 auto_free)
- TweenMoveTo - 移动动画
- TweenScaleTo - 缩放动画
- TweenRotateTo - 旋转动画
- TweenColorTransition - 颜色过渡

### 预置动画 (P2-P3)
- TweenPopAnimation - 弹出动画
- TweenShakeAnimation - 震动动画
- TweenBounceAnimation - 弹跳动画
- TweenPulseAnimation - 脉冲动画

### 高级功能 (P3)
- TweenProperty - 通用属性动画 (支持 auto_free)

## 技术要点

- 所有指令都是异步的 (_is_async = true)
- 基础动画支持 easing_type 和 trans_type 参数
- 使用 create_tween() 和 tween_property() API
- 参考 Tween 通用模式: docs/tween-common-patterns.md
