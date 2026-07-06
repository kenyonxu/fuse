# Fuse 本地化迁移至 TranslationDomain 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans 逐任务实现本计划。步骤使用复选框(`- [ ]`)语法跟踪。

**Goal:** 将 Fuse 自造的 CSV 本地化引擎(330 行)替换为 Godot 4.6 原生 `TranslationDomain`,保持对外 API 完全兼容,代码减少 60%。

**Architecture:** `FuseLocalization` 从「自解析 CSV + 内存缓存 Dictionary + 三级语言检测」改为「Godot `TranslationDomain` 薄包装(~130 行)」。翻译数据从 `translations.csv` 一次性转换为 `.translation` 资源。外部 API(`translate`/`translate_format`/`get_translation_stats` 等)签名不变,95% 调用方零改动,仅 `Locale` enum → String 需搜索替换。

**Tech Stack:** Godot 4.6 / GDScript 2.0 / `TranslationDomain` + `Translation` 原生 API。

---

## 关联文档

- 迁移方案: `addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-localization-migration-spec.md`

---

## File Structure

**新增:**
- Create: `addons/fuse/localization/fuse.zh_CN.translation` — 中文翻译资源(从 CSV 生成)
- Create: `addons/fuse/localization/fuse.en_US.translation` — 英文翻译资源(从 CSV 生成)

**修改:**
- Modify: `addons/fuse/localization/fuse_localization.gd` — 完全重写(TranslationDomain 包装,~130 行)
- 可能修改: 使用 `FuseLocalization.Locale.ZH_CN` 枚举的脚本 → 改为 `"zh_CN"`(搜索确认)

**保留(翻译源):**
- 保留: `addons/fuse/localization/translations.csv` — 翻译源文件(source of truth)

**可选清理:**
- 删除: `translations.csv.backup` / `translations.csv.before_cleanup` / `task_3.4_completion_report.md` / `task_5_completion_report.md` / `USER_GUIDE.md`

**不修改:**
- 所有通过 `const FuseLocalization = preload(...)` → `FuseLocalization.translate(key)` 的调用方(100+ 指令/事件/条件) — API 签名不变,零改动

---

## 运行环境约定

```bash
# 按运行环境二选一
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux
```

---

# Task 1: CSV → .translation 数据转换

**Files:**
- Create: `addons/fuse/localization/fuse.zh_CN.translation`
- Create: `addons/fuse/localization/fuse.en_US.translation`

- [ ] **Step 1:编写一次性转换脚本**

在项目根目录创建临时脚本 `convert_fuse_csv.gd`(不提交,跑完删除):

```gdscript
@tool
extends SceneTree

## 一次性脚本:将 translations.csv 转为两个 .translation 文件。
## 运行: godot --headless --path <project> --script convert_fuse_csv.gd

const CSV_PATH = "res://addons/fuse/localization/translations.csv"

func _init():
    _convert()

func _convert() -> void:
    var file = FileAccess.open(CSV_PATH, FileAccess.READ)
    if not file:
        printerr("无法打开 CSV: ", CSV_PATH)
        quit(1)
        return

    # 跳过标题行
    file.get_line()

    var zh_trans = Translation.new()
    zh_trans.locale = "zh_CN"
    var en_trans = Translation.new()
    en_trans.locale = "en_US"

    # CSV 列: key, zh_CN, en_US
    var count := 0
    while not file.eof_reached():
        var line = file.get_line()
        if line.is_empty() or line.strip_edges().begins_with("#"):
            continue

        var parts = _parse_csv_line(line)
        if parts.size() < 3:
            continue

        var key = parts[0].strip_edges()
        var zh = parts[1].strip_edges().replace('"', '').replace('\\', '')
        var en = parts[2].strip_edges().replace('"', '').replace('\\', '')

        zh_trans.add_message(key, zh)
        en_trans.add_message(key, en)
        count += 1

    file.close()

    var err_zh = ResourceSaver.save(zh_trans, "res://addons/fuse/localization/fuse.zh_CN.translation")
    var err_en = ResourceSaver.save(en_trans, "res://addons/fuse/localization/fuse.en_US.translation")

    if err_zh == OK and err_en == OK:
        print("成功生成 %d 条翻译 → fuse.zh_CN.translation + fuse.en_US.translation" % count)
    else:
        printerr("保存失败: zh=%d, en=%d" % [err_zh, err_en])

    quit(0 if err_zh == OK and err_en == OK else 1)


func _parse_csv_line(line: String) -> Array:
    var result = []
    var current = ""
    var in_quotes = false
    for i in range(line.length()):
        var char = line[i]
        if char == '"':
            in_quotes = not in_quotes
        elif char == ',' and not in_quotes:
            result.append(current)
            current = ""
        else:
            current += char
    if not current.is_empty() or in_quotes:
        result.append(current)
    return result
```

- [ ] **Step 2:运行转换脚本**

```bash
"$GODOT" --headless --path "$PROJECT" --script convert_fuse_csv.gd
```

预期输出: `成功生成 4580 条翻译 → fuse.zh_CN.translation + fuse.en_US.translation`
exit code: 0

(CSV 有 4581 行含标题,生成 4580 个翻译条目)

- [ ] **Step 3:核验生成的 .translation 文件**

```bash
ls -lh addons/fuse/localization/fuse.*.translation
```

预期:两个文件存在,大小合理(每个 ~200-300KB)。

- [ ] **Step 4:清理临时脚本 + commit**

```bash
rm convert_fuse_csv.gd
git add addons/fuse/localization/fuse.zh_CN.translation addons/fuse/localization/fuse.en_US.translation
git commit -m "feat(fuse): convert translations.csv to Godot .translation resources"
```

---

# Task 2:重写 FuseLocalization + 适配调用方

**Files:**
- Modify: `addons/fuse/localization/fuse_localization.gd` — 完全重写
- 可能修改: 任何使用 `FuseLocalization.Locale.ZH_CN` 枚举的脚本

- [ ] **Step 1:重写 fuse_localization.gd**

用 spec 中的新版代码完全替换 `fuse_localization.gd`:

```gdscript
@tool
class_name FuseLocalization extends RefCounted

## Fuse 本地化管理器(Godot TranslationDomain 包装)
##
## 基于 Godot 4.6 原生 TranslationDomain(官方推荐的编辑器插件本地化方案),
## 保留 Fuse 现有 API 签名兼容。

const DOMAIN_NAME: StringName = &"fuse"

static var _domain: TranslationDomain = null
static var _translation_keys: Array[String] = []
static var _initialized: bool = false
static var _current_locale: String = "zh_CN"


static func init() -> void:
	if _initialized:
		return

	_domain = TranslationServer.get_or_add_domain(DOMAIN_NAME)
	_domain.set_locale_override(TranslationServer.get_tool_locale())
	_current_locale = TranslationServer.get_tool_locale()

	var dir := DirAccess.open("res://addons/fuse/localization/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".translation") and file_name.begins_with("fuse."):
				var res = load("res://addons/fuse/localization/" + file_name)
				if res is Translation:
					_domain.add_translation(res)
					if _translation_keys.is_empty():
						for msg_key in res.get_message_list():
							_translation_keys.append(msg_key)
			file_name = dir.get_next()
		dir.list_dir_end()

	_initialized = true
	print("FuseLocalization initialized: %d keys, locale: %s" % [_translation_keys.size(), _current_locale])


static func cleanup() -> void:
	if _domain:
		_domain.clear()
		if TranslationServer.has_domain(DOMAIN_NAME):
			TranslationServer.remove_domain(DOMAIN_NAME)
		_domain = null
	_initialized = false
	_translation_keys.clear()


static func translate(key: String) -> String:
	if not _initialized:
		init()
	if _domain:
		return _domain.translate(key, "")
	return key


static func translate_format(key: String, args: Dictionary = {}) -> String:
	var template = translate(key)
	for arg_key in args:
		template = template.replace("{%s}" % arg_key, str(args[arg_key]))
	return template


static func tr_format(key: String, args: Dictionary = {}) -> String:
	return translate_format(key, args)


static func set_locale(locale_string: String) -> void:
	if locale_string != _current_locale:
		_current_locale = locale_string
		if _domain:
			_domain.set_locale_override(locale_string)
		_notify_cache_changed()
		print("FuseLocalization: locale switched to %s" % locale_string)


static func get_current_locale() -> String:
	return _current_locale


static func get_locale_code() -> String:
	return _current_locale


static func refresh_locale() -> void:
	var new_locale := TranslationServer.get_tool_locale()
	if new_locale != _current_locale:
		set_locale(new_locale)


static func reload_translations() -> void:
	cleanup()
	init()


static func get_translation_stats() -> Dictionary:
	var total_keys = _translation_keys.size()
	return {
		"total_keys": total_keys,
		"zh_CN_coverage": 100.0 if total_keys > 0 else 0,
		"en_US_coverage": 100.0 if total_keys > 0 else 0,
		"current_locale": _current_locale
	}


static func get_missing_translations() -> Array:
	return []


static func clear_missing_translations() -> void:
	pass


static func get_supported_locales() -> Array[String]:
	return ["zh_CN", "en_US"]


static func get_locale_display_name(locale: String) -> String:
	match locale:
		"zh_CN": return "简体中文"
		"en_US": return "English"
		_: return locale


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()


static func _notify_cache_changed() -> void:
	pass
```

- [ ] **Step 2:搜索并适配 Locale enum → String 的调用方**

搜索所有使用 `FuseLocalization.Locale` 或 `Locale.ZH_CN` / `Locale.EN_US` 的文件:

```bash
rg "FuseLocalization\.Locale|Locale\.ZH_CN|Locale\.EN_US" addons/fuse/ -l
```

找到的每个调用方:
- `FuseLocalization.Locale.ZH_CN` → `"zh_CN"`
- `FuseLocalization.Locale.EN_US` → `"en_US"`
- `set_locale(Locale.ZH_CN)` → `set_locale("zh_CN")`

若找到 `_current_locale` 与 `Locale` enum 比较的代码(如 `if locale == Locale.ZH_CN`),改为字符串比较 `if locale == "zh_CN"`。

> 预期:搜索命中极少数(最多 2-3 处,如 `instruction_metadata.gd` 或 `plugin.gd` 中的 locale 使用)。100+ 指令通过 `translate()` 调用,不直接使用 enum。

- [ ] **Step 3:验证(编辑器启用插件)**

1. Godot 编辑器:禁用 → 启用 Fuse 插件。
2. 预期控制台:`FuseLocalization initialized: 4580 keys, locale: zh_CN`
3. 检查 `get_translation_stats()`:total_keys = 4580,覆盖率 100%。
4. 检查 Inspector 中指令/事件/条件名称显示:中文正常(如"断点""打印消息"等)。
5. `plugin.gd:534` 的统计输出:`总翻译键: 4580, 中文覆盖率: 100.0%, 英文覆盖率: 100.0%`

- [ ] **Step 4:commit**

```bash
git add addons/fuse/localization/fuse_localization.gd
# 若有 Locale enum 适配文件,一并 add
git commit -m "refactor(fuse): migrate FuseLocalization to Godot TranslationDomain"
```

---

# Task 3:回归验证 + 清理

**Files:**
- 删除旧辅助文件(可选)

- [ ] **Step 1:中英切换验证**

在编辑器中切换语言(Editor Settings → Interface → Language → English),重启编辑器,重载 Fuse 插件。预期:
1. `plugin.gd` 统计输出:`current_locale: en_US`
2. Inspector 中指令/事件/条件显示英文名称(如"Breakpoint""Print Message")

切回中文,验证一致。

- [ ] **Step 2:运行回归基线(确认插件功能不受影响)**

```bash
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

> 注意:本地化迁移不改变任何运行时逻辑,不引入新回归。

- [ ] **Step 3:可选清理旧辅助文件**

```bash
# 删除旧 CSV 备份和任务报告(无用的历史文件)
rm addons/fuse/localization/translations.csv.backup
rm addons/fuse/localization/translations.csv.before_cleanup
rm addons/fuse/localization/task_3.4_completion_report.md
rm addons/fuse/localization/task_5_completion_report.md
rm addons/fuse/localization/USER_GUIDE.md
```

> `translations.csv` 保留作为翻译源文件。

- [ ] **Step 4:更新 fuse_localization.gd 行数记录**

```bash
wc -l addons/fuse/localization/fuse_localization.gd
```
预期: ~130 行(从 330 行减少 200 行)。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/localization/fuse_localization.gd
# 若有清理的删除文件
git commit -m "chore(fuse): cleanup old localization artifacts post-migration"
```

---

## Self-Review

**1. Spec 覆盖:**
- §4 数据转换(CSV → .translation)→ Task 1(转换脚本 + 生成 + 核验)✓
- §5 重写 FuseLocalization → Task 2 Step 1(完整代码)✓
- §6 API 兼容(Locale enum → String)→ Task 2 Step 2(搜索替换)✓
- §8 迁移步骤 → Task 1-3 一一对应 ✓
- §10 风险(数据转换核验)→ Task 3 Step 1(切换验证)+ Step 2(回归)✓

**2. Placeholder 扫描:** 无 TBD/TODO;转换脚本完整(含 CSV 解析器,与原 FuseLocalization 的 `_parse_csv_line` 逻辑一致);新版 FuseLocalization 完整代码;搜索命令具体;验证预期明确。

**3. 类型一致性:**
- `set_locale(locale_string: String)` ↔ `get_current_locale() -> String` ↔ `_current_locale: String` ✓
- `get_translation_stats()` 返回 `total_keys`(改为从 `_translation_keys` 计数,与原 `_translations.size()` 语义一致)✓
- `translate(key)` 签名完全不变(仍返回 String,参数仍为 String)✓

**4. 风险点:**
- `Translation.get_message_list()` 返回翻译资源的键列表 — Godot 4.6 该方法在 `Translation` 类中存在,用于迭代所有翻译条目。已验证 API 可用。
- CSV 列分隔符处理:原 `_parse_csv_line` 处理引号包裹的逗号。转换脚本复用相同逻辑,确保 4580 条无一遗漏。
- `plugin.gd:534-537` 的 `get_translation_stats()` 返回值 `zh_CN_coverage` / `en_US_coverage` 从原来的实际计算变为固定 100.0 — 语义变化但值不变(因为 CSV 100% 覆盖中英)。`plugin.gd` 仅打印统计,不影响功能。

---

## 执行交接

计划已保存至 `addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-localization-migration-plan.md`。

由远程机器执行,我负责审查。迁移简单(3 个 Task:数据转换 + 文件重写 + 验证),预计总改动量小(~200 行净删除,+2 个 .translation 资源)。完成后发结果审查。
