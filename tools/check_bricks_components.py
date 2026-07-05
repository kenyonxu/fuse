#!/usr/bin/env python3
"""
Bricks 组件自动化审查脚本

检查所有 Bricks 指令是否应用了标准修复模式：
1. 节点查找使用 find_node_by_relative_path()
2. 场景加载顺序检查
3. 属性缓存机制
"""

import os
import re
from pathlib import Path
from typing import List, Dict, Tuple
from dataclasses import dataclass
from enum import Enum


class Severity(Enum):
    """问题严重性级别"""
    HIGH = "高"
    MEDIUM = "中"
    LOW = "低"


@dataclass
class Issue:
    """检查问题"""
    file_path: str
    check_type: str
    severity: Severity
    description: str
    line_number: int = None

    def __str__(self):
        line_info = f":{self.line_number}" if self.line_number else ""
        return f"[{self.severity.value}] {self.file_path}{line_info} - {self.check_type}: {self.description}"


class BricksComponentChecker:
    """Bricks 组件检查器"""

    def __init__(self, bricks_root: str):
        self.bricks_root = Path(bricks_root)
        self.issues: List[Issue] = []
        self.check_results: Dict[str, Dict] = {}

    def scan_directory(self, instructions_dir: str = "instructions") -> int:
        """
        递归扫描指定目录

        Args:
            instructions_dir: 相对于 bricks_root 的指令目录

        Returns:
            找到的 .gd 文件数量
        """
        target_dir = self.bricks_root / instructions_dir

        if not target_dir.exists():
            print(f"错误: 目录不存在 - {target_dir}")
            return 0

        gd_files = list(target_dir.rglob("*.gd"))
        print(f"找到 {len(gd_files)} 个 GDScript 文件")

        return len(gd_files)

    def check_file(self, file_path: str) -> List[Issue]:
        """
        检查单个文件

        Args:
            file_path: 文件路径

        Returns:
            发现的问题列表
        """
        issues = []
        relative_path = os.path.relpath(file_path, self.bricks_root)

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')

            # 检查 1: 是否使用 find_node_by_relative_path()
            issues.extend(self._check_node_finding(file_path, content, lines))

            # 检查 2: 场景加载顺序检查
            issues.extend(self._check_scene_loading_order(file_path, content, lines))

            # 检查 3: 缓存机制
            issues.extend(self._check_caching_mechanism(file_path, content, lines))

        except Exception as e:
            issues.append(Issue(
                file_path=relative_path,
                check_type="文件读取",
                severity=Severity.HIGH,
                description=f"无法读取文件: {str(e)}"
            ))

        return issues

    def _check_node_finding(self, file_path: str, content: str, lines: List[str]) -> List[Issue]:
        """
        检查 1: 是否使用 find_node_by_relative_path()

        高严重性 - 因为不使用可能导致运行时错误
        """
        issues = []
        relative_path = os.path.relpath(file_path, self.bricks_root)

        # 检查是否使用了 find_node_by_relative_path
        has_correct_method = 'find_node_by_relative_path' in content

        # 检查是否有 get_node() 或 has_node() 调用
        get_node_pattern = r'\.get_node\s*\('
        has_node_pattern = r'\.has_node\s*\('

        get_node_matches = list(re.finditer(get_node_pattern, content))
        has_node_matches = list(re.finditer(has_node_pattern, content))

        # 如果使用了 get_node() 但没有使用 find_node_by_relative_path()
        if (get_node_matches or has_node_matches) and not has_correct_method:
            # 找到第一个 get_node() 的行号
            line_num = None
            if get_node_matches:
                line_num = content[:get_node_matches[0].start()].count('\n') + 1

            issues.append(Issue(
                file_path=relative_path,
                check_type="节点查找方法",
                severity=Severity.HIGH,
                description="使用 get_node() 而非 find_node_by_relative_path()，可能存在 Resource 上下文问题",
                line_number=line_num
            ))

        return issues

    def _check_scene_loading_order(self, file_path: str, content: str, lines: List[str]) -> List[Issue]:
        """
        检查 2: 场景加载顺序检查

        中严重性 - 因为缺少可能导致属性丢失
        """
        issues = []
        relative_path = os.path.relpath(file_path, self.bricks_root)

        # 检查是否有 target_node 或类似的节点引用
        has_node_reference = any(pattern in content for pattern in [
            '@export var target_node',
            '@export var edited_root',
            '@export var source_node'
        ])

        if not has_node_reference:
            return issues

        # 检查是否有场景加载顺序检查
        has_loading_check = any(pattern in content for pattern in [
            'Engine.is_editor_hint()',
            '_target_node_instance == null',
            'edited_root == null'
        ])

        if has_node_reference and not has_loading_check:
            # 找到第一个 @export var target_node 的行号
            line_num = None
            for i, line in enumerate(lines, 1):
                if '@export var' in line and 'node' in line.lower():
                    line_num = i
                    break

            issues.append(Issue(
                file_path=relative_path,
                check_type="场景加载顺序",
                severity=Severity.MEDIUM,
                description="缺少场景加载顺序检查，可能导致属性信息丢失",
                line_number=line_num
            ))

        return issues

    def _check_caching_mechanism(self, file_path: str, content: str, lines: List[str]) -> List[Issue]:
        """
        检查 3: 缓存机制

        低严重性 - 因为缺少只影响性能
        """
        issues = []
        relative_path = os.path.relpath(file_path, self.bricks_root)

        # 检查是否有频繁调用的方法
        has_frequent_calls = any(pattern in content for pattern in [
            '_get_property_list()',
            '_update_available_properties()',
            '_get_material_properties()'
        ])

        if not has_frequent_calls:
            return issues

        # 检查是否有缓存变量
        cache_patterns = [
            r'_cached_\w+',
            r'_\w+_cache'
        ]

        has_cache = any(re.search(pattern, content) for pattern in cache_patterns)

        if has_frequent_calls and not has_cache:
            # 找到第一个频繁调用方法的行号
            line_num = None
            for i, line in enumerate(lines, 1):
                if '_get_property_list' in line or '_update_available_properties' in line:
                    line_num = i
                    break

            issues.append(Issue(
                file_path=relative_path,
                check_type="缓存机制",
                severity=Severity.LOW,
                description="缺少缓存机制，可能影响编辑器性能",
                line_number=line_num
            ))

        return issues

    def run_checks(self, instructions_dir: str = "instructions") -> Dict:
        """
        运行所有检查

        Returns:
            检查结果字典
        """
        print("=" * 80)
        print("Bricks 组件自动化审查")
        print("=" * 80)

        # 扫描目录
        file_count = self.scan_directory(instructions_dir)
        if file_count == 0:
            return {
                "total_files": 0,
                "files_with_issues": 0,
                "issues_by_severity": {
                    "高": 0,
                    "中": 0,
                    "低": 0
                },
                "issues": []
            }

        # 递归检查所有 .gd 文件
        target_dir = self.bricks_root / instructions_dir
        all_issues = []

        print(f"\n开始检查...\n")

        for gd_file in target_dir.rglob("*.gd"):
            issues = self.check_file(str(gd_file))
            all_issues.extend(issues)

        # 统计结果
        files_with_issues = len(set(issue.file_path for issue in all_issues))

        severity_counts = {
            "高": sum(1 for issue in all_issues if issue.severity == Severity.HIGH),
            "中": sum(1 for issue in all_issues if issue.severity == Severity.MEDIUM),
            "低": sum(1 for issue in all_issues if issue.severity == Severity.LOW)
        }

        results = {
            "total_files": file_count,
            "files_with_issues": files_with_issues,
            "issues_by_severity": severity_counts,
            "issues": all_issues
        }

        return results

    def print_results(self, results: Dict):
        """打印检查结果"""
        print("\n" + "=" * 80)
        print("检查结果摘要")
        print("=" * 80)

        print(f"\n检查的文件总数: {results['total_files']}")
        print(f"有问题的文件数: {results['files_with_issues']}")

        severity_counts = results['issues_by_severity']
        print(f"\n按严重性分类:")
        print(f"  高: {severity_counts['高']}")
        print(f"  中: {severity_counts['中']}")
        print(f"  低: {severity_counts['低']}")
        print(f"  总计: {sum(severity_counts.values())}")

        if results['issues']:
            print("\n" + "=" * 80)
            print("详细问题列表")
            print("=" * 80)

            # 按严重性分组
            high_issues = [i for i in results['issues'] if i.severity == Severity.HIGH]
            medium_issues = [i for i in results['issues'] if i.severity == Severity.MEDIUM]
            low_issues = [i for i in results['issues'] if i.severity == Severity.LOW]

            if high_issues:
                print("\n[高严重性问题]")
                for issue in high_issues:
                    print(f"  {issue}")

            if medium_issues:
                print("\n[中严重性问题]")
                for issue in medium_issues:
                    print(f"  {issue}")

            if low_issues:
                print("\n[低严重性问题]")
                for issue in low_issues:
                    print(f"  {issue}")

        print("\n" + "=" * 80)
        print("检查完成")
        print("=" * 80)


def main():
    """主函数"""
    # 获取项目根目录（脚本所在目录的父目录）
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    bricks_root = project_root / "addons" / "bricks"

    print(f"项目根目录: {project_root}")
    print(f"Bricks 目录: {bricks_root}\n")

    if not bricks_root.exists():
        print(f"错误: Bricks 目录不存在 - {bricks_root}")
        return 1

    # 创建检查器并运行检查
    checker = BricksComponentChecker(str(bricks_root))
    results = checker.run_checks("instructions")

    # 打印结果
    checker.print_results(results)

    # 返回退出码
    if results['issues_by_severity']['高'] > 0:
        return 1  # 有高严重性问题
    return 0


if __name__ == "__main__":
    exit(main())
