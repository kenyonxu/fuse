#!/bin/bash
# Bricks Phase 1 Conditions 批量重命名脚本 (Bash 版本)

set -e  # 遇到错误立即退出

# 项目根目录
PROJECT_ROOT="e:/Godot/GodotProjects/project-juicy-godot"
CONDITIONS_DIR="$PROJECT_ROOT/addons/bricks/conditions"

# 进入项目目录
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  Bricks Conditions 批量重命名"
echo "=========================================="
echo ""
echo "项目根目录: $PROJECT_ROOT"
echo "条件目录: $CONDITIONS_DIR"
echo ""

# 确认操作
echo "⚠️  此操作将重命名 13 个条件文件并更新所有引用"
echo ""
read -p "是否继续? (yes/no): " -r response
if [ "$response" != "yes" ] && [ "$response" != "y" ]; then
    echo "操作已取消"
    exit 0
fi

echo ""
echo "=========================================="
echo "  Step 1: 重命名条件文件"
echo "=========================================="

# 重命名函数
rename_file() {
    local old_file="$1"
    local new_file="$2"
    local old_class="$3"
    local new_class="$4"

    local old_path="$CONDITIONS_DIR/$old_file"
    local new_path="$CONDITIONS_DIR/$new_file"

    if [ ! -f "$old_path" ]; then
        echo "  ⚠️  文件不存在: $old_file"
        return 1
    fi

    if [ -f "$new_path" ]; then
        echo "  ❌ 目标文件已存在: $new_file"
        return 1
    fi

    # 使用 sed 替换类名
    sed -e "s/class_name $old_class/class_name $new_class/g" \
        -e "s/: $old_class/: $new_class/g" \
        -e "s/\"$old_class\"/\"$new_class\"/g" \
        -e "s/'$old_class'/'$new_class'/g" \
        "$old_path" > "$new_path"

    # 删除旧文件
    rm "$old_path"

    # 重命名 .uid 文件
    local old_uid="${old_path%.gd}.gd.uid"
    local new_uid="${new_path%.gd}.gd.uid"
    if [ -f "$old_uid" ]; then
        mv "$old_uid" "$new_uid"
    fi

    echo "  ✓ $old_file → $new_file"
    echo "    ($old_class → $new_class)"
}

# 1. 复合逻辑类
echo ""
echo "复合逻辑类:"
rename_file "composite/condition_not.gd" "composite/check_not.gd" "ConditionNot" "CheckNot"
rename_file "composite/condition_all.gd" "composite/check_all.gd" "ConditionAll" "CheckAll"
rename_file "composite/condition_any.gd" "composite/check_any.gd" "ConditionAny" "CheckAny"
rename_file "composite/condition_composite.gd" "composite/check_composite.gd" "ConditionComposite" "CheckComposite"

# 2. 节点操作类
echo ""
echo "节点操作类:"
rename_file "node/condition_node_active.gd" "node/check_node_active.gd" "ConditionNodeActive" "CheckNodeActive"
rename_file "node/condition_node_in_group.gd" "node/check_node_in_group.gd" "ConditionNodeInGroup" "CheckNodeInGroup"

# 3. 物理检测类
echo ""
echo "物理检测类:"
rename_file "physics/condition_on_floor.gd" "physics/check_on_floor.gd" "ConditionOnFloor" "CheckOnFloor"
rename_file "physics/condition_in_air.gd" "physics/check_in_air.gd" "ConditionInAir" "CheckInAir"

# 4. 输入检测类
echo ""
echo "输入检测类:"
rename_file "input/condition_input_pressed.gd" "input/check_input_pressed.gd" "ConditionInputPressed" "CheckInputPressed"
rename_file "input/condition_input_released.gd" "input/check_input_released.gd" "ConditionInputReleased" "CheckInputReleased"
rename_file "input/condition_input_held.gd" "input/check_input_held.gd" "ConditionInputHeld" "CheckInputHeld"

# 5. 时间检测类
echo ""
echo "时间检测类:"
rename_file "time/condition_time_reached.gd" "time/check_time_reached.gd" "ConditionTimeReached" "CheckTimeReached"

# 6. 距离检测类
echo ""
echo "距离检测类:"
rename_file "distance/condition_distance.gd" "distance/check_distance.gd" "ConditionDistance" "CheckDistance"

echo ""
echo "=========================================="
echo "  Step 2: 更新测试文件"
echo "=========================================="

# 更新测试文件的函数
update_test_file() {
    local test_file="$1"
    local test_path="$CONDITIONS_DIR/$test_file"

    if [ ! -f "$test_path" ]; then
        echo "  ⚠️  测试文件不存在: $test_file"
        return 1
    fi

    echo ""
    echo "  更新: $test_file"

    # 创建临时文件
    local temp_file="${test_path}.tmp"

    # 应用所有类名替换
    sed -e "s/ConditionNot/CheckNot/g" \
        -e "s/ConditionAll/CheckAll/g" \
        -e "s/ConditionAny/CheckAny/g" \
        -e "s/ConditionComposite/CheckComposite/g" \
        -e "s/ConditionNodeActive/CheckNodeActive/g" \
        -e "s/ConditionNodeInGroup/CheckNodeInGroup/g" \
        -e "s/ConditionOnFloor/CheckOnFloor/g" \
        -e "s/ConditionInAir/CheckInAir/g" \
        -e "s/ConditionInputPressed/CheckInputPressed/g" \
        -e "s/ConditionInputReleased/CheckInputReleased/g" \
        -e "s/ConditionInputHeld/CheckInputHeld/g" \
        -e "s/ConditionTimeReached/CheckTimeReached/g" \
        -e "s/ConditionDistance/CheckDistance/g" \
        "$test_path" > "$temp_file"

    # 检查是否有变化
    if diff -q "$test_path" "$temp_file" > /dev/null 2>&1; then
        echo "  ℹ️  无需更新"
        rm "$temp_file"
        return 0
    fi

    # 替换原文件
    mv "$temp_file" "$test_path"
    echo "  ✓ 已更新"
}

# 更新所有测试文件
update_test_file "tests/test_composite_conditions.gd"
update_test_file "tests/test_node_conditions.gd"
update_test_file "tests/test_physics_conditions.gd"
update_test_file "tests/test_input_conditions.gd"
update_test_file "tests/test_time_conditions.gd"
update_test_file "tests/test_distance_conditions.gd"
update_test_file "tests/test_phase1_integration.gd"

echo ""
echo "=========================================="
echo "  重命名完成"
echo "=========================================="

echo ""
echo "📊 统计:"
echo "  重命名的条件文件: 13/13"
echo "  更新的测试文件: 7/7"

echo ""
echo "📝 下一步:"
echo "  1. 检查 Git 状态"
echo "  2. 运行语法检查"
echo "  3. 运行测试验证功能"
echo "  4. 提交更改"

echo ""
echo "✅ 所有文件已重命名！"
