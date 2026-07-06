# Fuse 本地化迁移至 TranslationDomain 设计方案

日期: 2026-06-16
关联: Fuse 整改 Phase 2 完成后的技术债清理

## 1. 目标

将 Fuse 自造的 CSV 本地化引擎(330 行 `FuseLocalization`)替换为 Godot 4.6 原生的 `TranslationDomain` 机制,消除自定义 CSV 解析器、三级语言检测、翻译缓存等重复造轮子代码,标准化工具链。

**原则:**
- 对外 API 签名完全不变(`translate()`/`translate_format()`/`get_translation_stats()` 等,所有调用方零改动)
- 翻译数据从 `translations.csv` 转为 Godot `.translation` 资源(一次性转换)
- 删除自解析 CSV、语言检测、缓存逻辑(~200 行)
- 保留统计/调试 API(通过包装 TranslationDomain 实现)

## 2. 现状

| 项 | 现状 |
|----|------|
| 翻译存储 | `translations.csv`(4581 行,三列:key, zh_CN, en_US) |
| 解析器 | 自实现 `_parse_csv_line()`(带引号处理,22 行) |
| 缓存 | 内存 `Dictionary`(4581 键,约 300KB) |
| 语言检测 | 三级:EditorInterface → ProjectSettings → TranslationServer(30 行) |
| 翻译 API | `translate(key)` / `translate_format(key, args)` / `tr_format()` |
| 工具 API | `set_locale()` / `get_locale_code()` / `get_translation_stats()` / `reload_translations()` / `get_missing_translations()` |
| 代码量 | 330 行 |

## 3. 目标架构

```
FuseLocalization (RefCounted, ~120 行,保留)
├── TranslationDomain("fuse")          ← Godot 原生
│   ├── fuse.zh_CN.translation         ← 从 CSV 生成
│   └── fuse.en_US.translation         ← 从 CSV 生成
├── _translation_keys: Array[String]   ← 翻译键列表(从 CSV 提取,统计用)
├── translate(key)                     ← 委托 _domain.translate(key, "")
├── translate_format(key, args)        ← 保留(参数替换不变)
├── get_translation_stats()            ← 用 _translation_keys 统计
└── 其余工具 API                       ← 包装 TranslationDomain
```

**删除:**
- `_load_translations()`(行 58-92) — Godot 原生加载
- `_parse_csv_line()`(行 96-116) — 不需要
- `_detect_system_locale()`(行 209-256) — Godot 内置
- `_translations` Dictionary(行 19) — TranslationDomain 托管
- `_missing_translations` Dictionary(行 31) — 简化
- Locale enum(行 10-13) — 改为 locale 字符串常量

**外部调用方不变(API 兼容):**
- `plugin.gd:529` — `FuseLocalization.init()` + `get_translation_stats()`
- `base_instruction.gd:7` — `const FuseLocalization = preload(...)`,用 `translate()`/`translate_format()`
- `instructions/` 100+ 脚本 — 同上
- `instruction_metadata.gd` — 同上
- `component_registry.gd` — 同上

## 4. 数据转换: CSV → .translation

### 4.1 格式映射

CSV 三列 → 两个 `.translation` 文件:

```csv
key,zh_CN,en_US
FUSE_INSTRUCTION_BREAKPOINT_NAME,断点,Breakpoint
```
→
`fuse.zh_CN.translation`: 键 `FUSE_INSTRUCTION_BREAKPOINT_NAME` → 值 `断点`
`fuse.en_US.translation`: 键 `FUSE_INSTRUCTION_BREAKPOINT_NAME` → 值 `Breakpoint`

### 4.2 转换方式

方式 A(推荐):在 Godot 编辑器中,Project Settings → Localization → Translations → Add → 选择 `translations.csv` 作为 zh_CN 翻译。Godot 自动生成 `.translation` 文件。重复添加同一个 CSV 为 en_US(在导入时指定 locale 列)。

方式 B(脚本):写一次性 GDScript 脚本,读取 CSV,用 `Translation.new()` + `add_message()` 构建,`ResourceSaver.save()` 写 `.translation` 文件。

### 4.3 生成后文件

```
addons/fuse/localization/
  translations.csv              # 保留作为翻译源(source of truth)
  fuse.zh_CN.translation        # 从 CSV 生成(二进制/文本资源)
  fuse.en_US.translation        # 从 CSV 生成
```

> `translations.csv` 仍保留为翻译源文件(翻译者编辑 CSV,每次修改后重新导入生成 .translation)。

## 5. FuseLocalization 改造后代码

```gdscript
@tool
class_name FuseLocalization extends RefCounted

## Fuse 本地化管理器(Godot TranslationDomain 包装)
##
## 基于 Godot 4.6 原生 TranslationDomain(官方推荐的编辑器插件本地化方案),
## 保留 Fuse 现有 API 签名兼容。

const DOMAIN_NAME: StringName = &"fuse"

static var _domain: TranslationDomain = null
static var _translation_keys: Array[String] = []  # 翻译键列表(统计用)
static var _initialized: bool = false

# 当前 locale 字符串("zh_CN" / "en_US")
static var _current_locale: String = "zh_CN"


## 初始化:注册 TranslationDomain,加载 .translation 资源
static func init() -> void:
	if _initialized:
		return

	_domain = TranslationServer.get_or_add_domain(DOMAIN_NAME)
	_domain.set_locale_override(TranslationServer.get_tool_locale())
	_current_locale = TranslationServer.get_tool_locale()

	# 加载 locales/ 下所有 .translation 文件
	var dir := DirAccess.open("res://addons/fuse/localization/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".translation") and file_name.begins_with("fuse."):
				var res = load("res://addons/fuse/localization/" + file_name)
				if res is Translation:
					_domain.add_translation(res)
					# 提取翻译键(仅从第一个翻译资源提取,后续资源键相同)
					if _translation_keys.is_empty():
						for msg_key in res.get_message_list():
							_translation_keys.append(msg_key)
			file_name = dir.get_next()
		dir.list_dir_end()

	_initialized = true
	print("FuseLocalization initialized: %d keys, locale: %s" % [_translation_keys.size(), _current_locale])


## 清理(插件停用时)
static func cleanup() -> void:
	if _domain:
		_domain.clear()
		if TranslationServer.has_domain(DOMAIN_NAME):
			TranslationServer.remove_domain(DOMAIN_NAME)
		_domain = null
	_initialized = false
	_translation_keys.clear()


## 翻译(保留原签名)
static func translate(key: String) -> String:
	if not _initialized:
		init()
	if _domain:
		return _domain.translate(key, "")
	return key


## 参数化翻译(保留原签名,逻辑不变)
static func translate_format(key: String, args: Dictionary = {}) -> String:
	var template = translate(key)
	for arg_key in args:
		template = template.replace("{%s}" % arg_key, str(args[arg_key]))
	return template


## 兼容性别名
static func tr_format(key: String, args: Dictionary = {}) -> String:
	return translate_format(key, args)


## 切换语言
static func set_locale(locale_string: String) -> void:
	if locale_string != _current_locale:
		_current_locale = locale_string
		if _domain:
			_domain.set_locale_override(locale_string)
		_notify_cache_changed()
		print("FuseLocalization: locale switched to %s" % locale_string)


## 获取当前 locale
static func get_current_locale() -> String:
	return _current_locale


## 获取 locale 代码(保留签名,直接返回)
static func get_locale_code() -> String:
	return _current_locale


## 语言切换时刷新(给编辑器语言变化回调调用)
static func refresh_locale() -> void:
	var new_locale := TranslationServer.get_tool_locale()
	if new_locale != _current_locale:
		set_locale(new_locale)


## 重新加载翻译
static func reload_translations() -> void:
	cleanup()
	init()


## 获取翻译统计
static func get_translation_stats() -> Dictionary:
	var total_keys = _translation_keys.size()
	return {
		"total_keys": total_keys,
		"zh_CN_coverage": 100.0 if total_keys > 0 else 0,  # .translation 资源保证完整
		"en_US_coverage": 100.0 if total_keys > 0 else 0,
		"current_locale": _current_locale
	}


## 缺失翻译(TranslationDomain 自动 fallback,始终返回空)
static func get_missing_translations() -> Array:
	# Translation 资源保证所有键有对应值,不再有"缺失"概念
	return []


static func clear_missing_translations() -> void:
	pass


## 支持的语言列表
static func get_supported_locales() -> Array[String]:
	return ["zh_CN", "en_US"]


## 语言显示名
static func get_locale_display_name(locale: String) -> String:
	match locale:
		"zh_CN": return "简体中文"
		"en_US": return "English"
		_: return locale


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()


## 通知缓存刷新(保留占位,TranslationDomain 不需要)
static func _notify_cache_changed() -> void:
	# TranslationDomain.translate() 实时返回当前 locale 的值,
	# 不需要显式刷新缓存。
	pass
```

> 改造后 ~130 行(从 330 行减少 200 行)。

## 6. API 兼容性

| 方法 | 签名变化 | 调用方影响 |
|------|:---:|------|
| `init()` | **不变** | 无 |
| `translate(key)` | **不变** | 无 |
| `translate_format(key, args)` | **不变** | 无 |
| `tr_format(key, args)` | **不变** | 无 |
| `set_locale(locale)` | 参数从 `Locale` enum 改为 `String` | ⚠️ 需检查 `set_locale(Locale.ZH_CN)` → `set_locale("zh_CN")` |
| `get_current_locale()` | 返回从 `Locale` → `String` | ⚠️ 检查调用方 |
| `get_locale_code()` | **不变**(已返回 String) | 无 |
| `get_translation_stats()` | **不变** | 无 |
| `reload_translations()` | **不变** | 无 |

> 需确认 `set_locale()` 和 `get_current_locale()` 的调用方(搜索 `FuseLocalization.set_locale` 和 `Locale.ZH_CN` / `Locale.EN_US`)。若调用方直接使用枚举常量,改为字符串。

## 7. 调用方影响评估

**完全不受影响(占 ~95%):**
- 100+ 指令/事件/条件通过 `const FuseLocalization = preload(...)` → `FuseLocalization.translate(key)` / `FuseLocalization.translate_format(key, args)` — 签名完全不变
- `plugin.gd:529-537` — `FuseLocalization.init()` + `get_translation_stats()` 不变
- `component_registry.gd` — 同上

**需小幅调整:**
- 任何直接引用 `FuseLocalization.Locale.ZH_CN` 枚举的地方 → 改为字符串 `"zh_CN"`
- `set_locale()` / `get_current_locale()` 调用方若使用 Locale enum → 适配 String

## 8. 迁移步骤

| 步骤 | 内容 | 风险 |
|:----:|------|:---:|
| 1 | CSV → `.translation` 转换(生成 `fuse.zh_CN.translation` / `fuse.en_US.translation`) | 极低(仅数据转换) |
| 2 | 重写 `FuseLocalization`(替换为 TranslationDomain 包装,130 行) | 中(API 不兼容点) |
| 3 | 适配 Locale enum → String 的调用方 | 低(搜索替换) |
| 4 | 回归验证:启用插件,确认翻译输出与改造前一致,`get_translation_stats()` 键数 4581 | 低 |
| 5 | 可选:删除 `translations.csv.backup` / `translations.csv.before_cleanup` / `task_*_report.md` 等旧辅助文件 | 无 |

## 9. 优势

- **代码减少:** 330 → 130 行(-60%)
- **标准性:** 使用 Godot 官方推荐的 `TranslationDomain` 插件本地化方案(Clef 同样采用)
- **工具链:** 未来可对接 Godot 编辑器的 POT 自动提取(`Project > Tools > Generate Translation`),新增翻译条目不再手动维护 CSV
- **维护:** 删除自造的 CSV 解析器、三级语言检测、缓存逻辑
- **运行时:** Godot 引擎级翻译缓存,性能优于自建 Dictionary

## 10. 风险

- **数据转换:** CSV → .translation 是一次性转换,需验证 4581 条翻译无遗漏(通过 `get_translation_stats()` 核验)
- **Locale enum:** 调用方若直接使用 `FuseLocalization.Locale.ZH_CN` → 一次性搜索替换为 `"zh_CN"`,改动面小
- **TranslationDomain 行为差异:** `_domain.translate(key)` 找不到时返回原 key(Fuse 旧行为:返回 key + push_warning),差异可接受
