# 文件：instructions_search.gd
class_name InstructionSearch
extends RefCounted

# 核心搜索逻辑：简单粗暴的三级匹配
static func search(query: String) -> Array[Dictionary]:
    var all_instructions = InstructionRegistry.get_all_instructions()

    if query.is_empty():
        # 当查询为空时，返回所有指令，但保持与搜索结果相同的格式
        var all_results: Array[Dictionary] = []
        for info in all_instructions:
            all_results.append({"item": info, "score": 0})
        return all_results

    var results: Array[Dictionary] = []
    var q = query.to_lower()

    for info in all_instructions:
        # 防御性编程：检查info和metadata是否存在
        if not info or not info.has("metadata"):
            continue
            
        var metadata = info.metadata
        if metadata == null:
            continue

        # 检查InstructionMetadata的必要字段是否存在且不为空
        # 支持新的翻译键（name_key）和旧的直接文本（name）
        var has_name = false
        if metadata.has_method("get_localized_name"):
            # 使用新方式：检查是否有 name_key 或 name
            has_name = not metadata.name_key.is_empty() or not metadata.name.is_empty()
        else:
            # 使用旧方式：直接检查 name
            has_name = metadata.name and not metadata.name.is_empty()

        if not has_name:
            continue

        var score = 0

        # 获取本地化名称用于搜索
        var search_name = ""
        var search_category = ""

        if metadata.has_method("get_localized_name"):
            search_name = metadata.get_localized_name()
            search_category = metadata.get_localized_category() if metadata.has_method("get_localized_category") else ""
        else:
            search_name = metadata.name if metadata.name else ""
            search_category = metadata.category if metadata.category else ""

        # 简单粗暴的三级匹配
        if search_name.to_lower().contains(q):
            score = 100
        elif not search_category.is_empty() and search_category.to_lower().contains(q):
            score = 50
        elif metadata.keywords and metadata.keywords.size() > 0 and _match_keywords(metadata.keywords, q):
            score = 30
        
        if score > 0:
            results.append({"item": info, "score": score})
    
    # 按分数排序
    results.sort_custom(func(a, b): return a.score > b.score)
    return results

static func _match_keywords(keywords: Array, query: String) -> bool:
    for keyword in keywords:
        if keyword is String and keyword.to_lower().contains(query):
            return true
    return false