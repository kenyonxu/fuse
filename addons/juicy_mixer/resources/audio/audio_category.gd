@tool
class_name AudioCategory
extends Resource

## 音频类别配置
##
## 用于对相似音效进行分组管理（如爆炸、脚步声、受击等）
## 实现类别级别的播放限额和智能优先级排序

# =============================================================================
# 枚举
# =============================================================================

## 类别优先级
enum AudioCategoryPriority {
	CRITICAL = 90,   # 关键（对白、UI 反馈）
	HIGH = 70,       # 高（玩家受击、重要音效）
	MEDIUM = 50,     # 中（环境音效、次要音效）
	LOW = 30,        # 低（背景噪音、装饰音效）
	VERY_LOW = 10    # 极低（碎片、杂物）
}

# =============================================================================
# 类别配置
# =============================================================================

@export_group("Category Configuration")

## 类别名称（如 "Explosions", "Footsteps", "Hit"）
@export var category_name: String = ""

## 类别最大播放实例数
@export_range(1, 50, 1) var max_instances: int = 5

## 类别优先级
@export var category_priority: AudioCategoryPriority = AudioCategoryPriority.MEDIUM

# =============================================================================
# 智能排序配置
# =============================================================================

@export_group("Priority Factors")

## 距离权重（0.0 - 1.0）
@export_range(0.0, 1.0, 0.05) var distance_weight: float = 0.4

## 重要性权重（0.0 - 1.0）
@export_range(0.0, 1.0, 0.05) var importance_weight: float = 0.4

## 最近播放时间权重（0.0 - 1.0）
@export_range(0.0, 1.0, 0.05) var recency_weight: float = 0.2

## 共享总线（可选）
@export var shared_bus: String = ""

# =============================================================================
# 公共方法
# =============================================================================

## 获取优先级因子的字典表示
func get_priority_factors() -> Dictionary:
	return {
		"distance_weight": distance_weight,
		"importance_weight": importance_weight,
		"recency_weight": recency_weight
	}

## 验证类别配置
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"issues": [],
		"warnings": []
	}

	if category_name.is_empty():
		result.issues.append("Category name cannot be empty")
		result.valid = false

	if max_instances <= 0:
		result.issues.append("max_instances must be positive")
		result.valid = false

	# 验证权重总和
	var weight_sum = distance_weight + importance_weight + recency_weight
	if abs(weight_sum - 1.0) > 0.01:
		result.warnings.append("Priority weights should sum to 1.0 (current: %.2f)" % weight_sum)

	return result

## 克隆类别
func clone() -> AudioCategory:
	var cloned = duplicate(true) as AudioCategory
	return cloned
