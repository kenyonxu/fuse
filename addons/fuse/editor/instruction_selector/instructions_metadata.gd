# 文件：instructions_metadata.gd
class_name InstructionMetadata extends FuseMetadata

## Instruction 元数据类
##
## 继承自 FuseMetadata，为 Instruction 提供元数据支持
## 包含 Instruction 特有的 ExecutionHint 枚举和字段

## 执行提示枚举
##
## 用于在编译时提供指令执行模式的提示，帮助优化执行路径：
## - UNKNOWN: 未知，需要运行时检测
## - LIKELY_SYNC: 很可能是同步的
## - LIKELY_ASYNC: 很可能是异步的
## - FORCE_SYNC: 强制同步
## - FORCE_ASYNC: 强制异步
enum ExecutionHint {
    UNKNOWN,        ## 未知，需要运行时检测
    LIKELY_SYNC,    ## 很可能是同步的
    LIKELY_ASYNC,   ## 很可能是异步的
    FORCE_SYNC,     ## 强制同步
    FORCE_ASYNC     ## 强制异步
}

## 编译时执行提示
@export var execution_hint: ExecutionHint = ExecutionHint.UNKNOWN
