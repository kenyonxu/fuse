# addons/fuse/tools/codegen/fuse_self_describe_codegen.gd
extends SceneTree

## Fuse 组件自描述 codegen（开发期工具，方案 Y）
##
## 用 gdscript_ast 扫描 Fuse 指令组件源码，生成
## _get_variable_accesses / _get_nodepath_props / _get_signal_info
## 自描述标记块，写回组件文件。
##
## 运行（CLI）：
##   godot --headless --path <project> -s addons/fuse/tools/codegen/fuse_self_describe_codegen.gd [--write] [单个 res:// 文件]
##
## 默认 dry-run（只打印提取结果 + 标记块，不写文件）。加 --write 写回。
## 传单个 res:// .gd 路径只处理该文件；否则扫描全部指令目录。
##
## 详见 docs/roadmap/2026-06-26-stage6.5-implementation-plan.md

const BEGIN_MARKER := "# === BEGIN FUSE SELF-DESCRIBE（codegen 生成，请勿手动编辑）==="
const END_MARKER := "# === END FUSE SELF-DESCRIBE ==="

const SCAN_DIRS := [
	"res://addons/fuse/instructions/",
	"res://addons/fuse/integration/",
	"res://fuse_generated/instructions/",
]

var _dry_run: bool = true
var _stats := {"ok": 0, "skipped": 0, "failed": 0, "no_metadata": 0}


func _initialize() -> void:
	var args := OS.get_cmdline_args()
	_dry_run = not args.has("--write")
	var files: Array = []
	for a in args:
		if a.begins_with("res://") and a.ends_with(".gd"):
			files.append(a)

	print("[codegen] 模式: %s" % ("dry-run（不写回）" if _dry_run else "WRITE（写回文件）"))

	if not files.is_empty():
		for f in files:
			_process_file(f)
	else:
		_scan_all()

	print("[codegen] 统计: ok=%d skipped=%d failed=%d no_metadata=%d" % [
		_stats.ok, _stats.skipped, _stats.failed, _stats.no_metadata])
	quit()


# ============================================================
# 扫描
# ============================================================

func _scan_all() -> void:
	for dir in SCAN_DIRS:
		if DirAccess.dir_exists_absolute(dir):
			_scan_dir_recursive(dir)


func _scan_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := dir_path.path_join(fname)
			if dir.current_is_dir():
				_scan_dir_recursive(full)
			elif fname.ends_with(".gd"):
				_process_file(full)
		fname = dir.get_next()


# ============================================================
# 单文件处理
# ============================================================

func _process_file(file_path: String) -> void:
	var source := FileAccess.get_file_as_string(file_path)
	if source == "":
		_stats.failed += 1
		printerr("[codegen] 读取失败: %s" % file_path)
		return

	var tokens := GDScriptTokenizer.new().tokenize(source)
	var parser := GDScriptParser.new()
	var class_node = parser.parse(tokens)
	if parser.error != "":
		if class_node == null:
			_stats.failed += 1
			printerr("[codegen] 解析失败 %s : %s" % [file_path, parser.error])
			return
		printerr("[codegen] ⚠ 容错继续 %s : %s" % [file_path, parser.error])

	if not _is_base_instruction_subclass(class_node):
		_stats.skipped += 1
		return

	# 无 _get_instruction_metadata 的组件 → 跳过（标记块无处插）
	if source.find("static func _get_instruction_metadata()") < 0:
		_stats.no_metadata += 1
		return

	var info := _extract_self_describe(class_node)

	if _dry_run:
		print("\n========== %s ==========" % file_path)
		print("@export 成员:")
		for m in class_node.members:
			if m is GDScriptToken.VariableNode and m.is_export:
				var tn := ""
				if m.datatype != null: tn = m.datatype.type_name
				print("  - %s : %s" % [m.name, tn])
		print("variable_accesses:", info["variable_accesses"])
		print("nodepath_props:    ", info["nodepath_props"])
		print("signal_info:       ", info["signal_info"])
		print("---- 标记块预览 ----")
		print(_render_block(info))
		print("=".repeat(60))
		_stats.ok += 1
	else:
		var new_source := _splice_block(source, _render_block(info))
		if new_source == source:
			_stats.skipped += 1
			print("[codegen] 无变化: %s" % file_path)
		else:
			_write_file(file_path, new_source)
			print("[codegen] 写回: %s" % file_path)
			_stats.ok += 1


func _is_base_instruction_subclass(class_node) -> bool:
	if class_node == null:
		return false
	# V1: 直接 extends BaseInstruction。中间类子类暂不处理（统计 no_metadata 后人工评估）。
	return class_node.extends_id.find("BaseInstruction") >= 0


# ============================================================
# 提取（遍历 AST）
# ============================================================

func _extract_self_describe(class_node) -> Dictionary:
	var variable_accesses := []
	var nodepath_props := []
	var bool_switches := []  # condition 候选开关名

	# (1) @export 变量属性 + NodePath 属性 + bool 开关
	for member in class_node.members:
		if not (member is GDScriptToken.VariableNode):
			continue
		if not member.is_export:
			continue
		var pname: String = member.name
		var type_name := ""
		if member.datatype != null:
			type_name = member.datatype.type_name

		if pname.ends_with("_variable") and type_name == "String":
			var scope_prop := _find_scope_pair(pname, class_node)
			var mode := _infer_mode(pname)
			variable_accesses.append({
				"prop": pname,
				"scope_prop": scope_prop,
				"mode": mode,
				"condition_prop": "",
			})
		elif (pname.ends_with("_node") or pname.ends_with("_node_path")) and type_name != "NodePath":
			nodepath_props.append(pname)
		elif type_name == "bool" and _is_switch_name(pname):
			bool_switches.append(pname)

	# (2) 信号声明
	var declared_signals := []
	for member in class_node.members:
		if member is GDScriptToken.SignalNode:
			declared_signals.append(member.name)

	# (3) emit 信号（遍历 execute body）
	var emitted_signals := _collect_emitted_signals(class_node)

	# (4) condition 推断（from_* ↔ set_with_*）
	_infer_conditions(variable_accesses, bool_switches)

	return {
		"variable_accesses": variable_accesses,
		"nodepath_props": nodepath_props,
		"signal_info": {"declared": declared_signals, "emitted": emitted_signals},
	}


func _find_scope_pair(var_prop: String, class_node) -> String:
	var candidate := var_prop + "_scope"
	for member in class_node.members:
		if member is GDScriptToken.VariableNode and member.is_export and member.name == candidate:
			return candidate
	return ""


func _infer_mode(var_prop: String) -> String:
	if var_prop.begins_with("target_"):
		return "write"
	if var_prop.begins_with("from_"):
		return "read"
	return "read_write"


func _is_switch_name(pname: String) -> bool:
	return pname.begins_with("set_with_") or pname.begins_with("use_") or pname.begins_with("enable_")


## V1: 恰好 1 个 read(from_*) 变量 + 恰好 1 个开关 → 关联。多对留空（人工复核）。
func _infer_conditions(variable_accesses: Array, bool_switches: Array) -> void:
	if bool_switches.size() != 1:
		return
	var switch_name: String = bool_switches[0]
	for access in variable_accesses:
		if access["mode"] == "read":
			access["condition_prop"] = switch_name


func _collect_emitted_signals(class_node) -> Array:
	var emitted := []
	var execute_fn = _find_function(class_node, "execute")
	if execute_fn != null and execute_fn.body != null:
		_walk_for_emits(execute_fn.body, emitted, 0)
	# 去重保序
	var seen := {}
	var result := []
	for s in emitted:
		if not seen.has(s):
			seen[s] = true
			result.append(s)
	return result


func _find_function(class_node, fname: String):
	for member in class_node.members:
		if member is GDScriptToken.FunctionNode and member.name == fname:
			return member
	return null


## 反射递归遍历 AST 子节点，收集 emit_signal / sig.emit() 调用。
func _walk_for_emits(node, emitted: Array, depth: int) -> void:
	if node == null or depth > 40:
		return
	if node is GDScriptToken.CallNode and _is_emit_call(node):
		if node.arguments.size() > 0:
			var arg0 = node.arguments[0]
			if arg0 is GDScriptToken.LiteralNode and arg0.value is String:
				emitted.append(arg0.value)
	for prop in node.get_property_list():
		var pname: String = prop["name"]
		if pname == "script":
			continue
		var val = node.get(pname)
		if _is_ast_node(val):
			_walk_for_emits(val, emitted, depth + 1)
		elif val is Array:
			for item in val:
				if _is_ast_node(item):
					_walk_for_emits(item, emitted, depth + 1)


func _is_emit_call(call_node) -> bool:
	var callee = call_node.callee
	if callee is GDScriptToken.IdentifierNode:
		return callee.name == "emit_signal"
	if callee is GDScriptToken.AttributeNode:
		return callee.name == "emit_signal" or callee.name == "emit"
	return false


func _is_ast_node(v) -> bool:
	return v is GDScriptToken.ASTNode


# ============================================================
# 渲染标记块
# ============================================================

func _render_block(info: Dictionary) -> String:
	# _get_variable_accesses
	var va = info["variable_accesses"]
	var va_body := "\treturn []"
	if va.size() > 0:
		var lines := []
		for a in va:
			lines.append("\t\t" + _dict_inline(a))
		va_body = "\treturn [\n" + _join(lines, ",\n") + "\n\t]"

	# _get_nodepath_props
	var np = info["nodepath_props"]
	var np_body := "\treturn " + _string_array_inline(np)

	# _get_signal_info
	var si = info["signal_info"]
	var si_body := "\treturn {\"declared\": " + _string_array_inline(si["declared"]) + ", \"emitted\": " + _string_array_inline(si["emitted"]) + "}"

	return "%s\n\nstatic func _get_variable_accesses() -> Array:\n%s\n\nstatic func _get_nodepath_props() -> Array:\n%s\n\nstatic func _get_signal_info() -> Dictionary:\n%s\n\n%s" % [
		BEGIN_MARKER, va_body, np_body, si_body, END_MARKER
	]


func _dict_inline(d: Dictionary) -> String:
	var parts := []
	for k in d:
		var v = d[k]
		if v is String:
			parts.append("\"%s\": \"%s\"" % [k, v])
		else:
			parts.append("\"%s\": %s" % [k, v])
	return "{" + _join(parts, ", ") + "}"


func _string_array_inline(arr: Array) -> String:
	if arr.is_empty():
		return "[]"
	var parts := []
	for s in arr:
		parts.append("\"%s\"" % s)
	return "[" + _join(parts, ", ") + "]"


func _join(parts: Array, sep: String) -> String:
	var r := ""
	for i in parts.size():
		if i > 0:
			r += sep
		r += str(parts[i])
	return r


# ============================================================
# 写回（标记块替换/插入）
# ============================================================

func _splice_block(source: String, block: String) -> String:
	var begin_idx := source.find(BEGIN_MARKER)
	if begin_idx < 0:
		# 无标记块：插在 _get_instruction_metadata() 的 return 之后
		return _insert_after_metadata(source, block)
	var end_idx := source.find(END_MARKER, begin_idx)
	if end_idx < 0:
		return source  # 标记不完整，不动
	var end_line_end := source.find("\n", end_idx)
	if end_line_end < 0:
		end_line_end = source.length()
	# 替换旧标记块（含尾部换行）
	return source.substr(0, begin_idx) + block + source.substr(end_line_end)


func _insert_after_metadata(source: String, block: String) -> String:
	# 定位 static func _get_instruction_metadata() 的方法块结束（下一个空行后的 "static func" 或 "## "）
	var meta_idx := source.find("static func _get_instruction_metadata()")
	if meta_idx < 0:
		return source  # 无锚点，不动
	# 找 metadata 方法后的插入点：下一个顶层 "static func " 或 "func " 或 "## " 之前
	var search_from := meta_idx
	var next_anchor := source.find("\nstatic func ", search_from + 1)
	if next_anchor < 0:
		next_anchor = source.find("\nfunc ", search_from + 1)
	if next_anchor < 0:
		next_anchor = source.find("\n## ", search_from + 1)
	if next_anchor < 0:
		return source  # 找不到锚点
	return source.substr(0, next_anchor + 1) + "\n" + block + "\n" + source.substr(next_anchor + 1)


func _write_file(file_path: String, content: String) -> void:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		printerr("[codegen] 写入失败: %s" % file_path)
		return
	f.store_string(content)
	f.close()
