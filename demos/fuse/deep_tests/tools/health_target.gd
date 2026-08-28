extends Node2D

## deep_tests 基底节点——供 OnHealthChanged / SetPropertyValue 使用的健康属性载体
## （测试工具脚本，同 input_driver 性质，不属于 Fuse 测试内容本身）

var health: float = 100.0
var max_health: float = 100.0
