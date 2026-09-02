> 🌐 [**中文版**](../../../zh_CN/dev_docs/guides/translation-glossary-guide.md) | English

# Fuse Translation Glossary (Chinese-English)

> This table is the terminology authority for making `docs/` bilingual (the `zh_CN/` authoritative source → the `en_US/` English mirror). All English translations follow it, ensuring consistency across documents and batches.

**Audience**: document translators and English documentation reviewers
**Last updated**: 2026-09-02

---

## General Translation Rules

1. **Faithfulness first**: the English version is a faithful translation of the Chinese version; do not add or remove technical content, and do not alter code examples.
2. **Code stays as-is**: code blocks, component names, class names, parameter names, enum values, `res://` paths, and file paths are always kept exactly as they are — never translated or modified.
3. **Headings and anchors**: after H1/H2 headings are translated into English, table-of-contents (TOC) anchors must be regenerated from the English headings — anchors derived from Chinese headings do not resolve in the English version; copying them verbatim is forbidden.
4. **Links point to the matching language**: links to other documents should prefer the corresponding English document in the `en_US/` tree; when that document has no English version yet, link the `zh_CN/` original and append ` (Chinese)` to the link text.
5. **Language switch line**: documents that exist in both languages get a switch line as the first line (before the H1); single-language documents do not.
6. **No frontmatter**: repository documents have no YAML frontmatter convention; the bilingual versions introduce none either.

### Language Switch Line Format

The first line of the document (before the H1); compute the relative path based on the file's own directory:

```markdown
> 🌐 [**中文版**](../../zh_CN/user_docs/guides/01-variable-system-guide.md) | English
```

```markdown
> 🌐 中文 | [**English**](../../en_US/user_docs/guides/01-variable-system-guide.md)
```

---

## Core Glossary

| Chinese | English | Notes |
|------|------|------|
| 事件 | event | One of the three brick types; class name `BaseEvent` kept as-is |
| 指令 | instruction | Class name `BaseInstruction` kept as-is |
| 条件 | condition | Class name `BaseCondition` kept as-is |
| 触发器 | trigger | Node names `Trigger` / `MultiEventTrigger` kept as-is |
| 运行器 | runner | Node name `Runner` kept as-is |
| 动作运行器 | ActionRunner | Resource class name; not translated |
| 执行上下文 | execution context | Class name `ExecutionContext` kept as-is |
| 运行时实例 | runtime instance | `RuntimeEventInstance` / `RuntimeInstructionInstance` kept as-is |
| 变量 | variable | Class name `BaseVariable` kept as-is |
| 三层作用域 | three-layer scopes | `LOCAL` / `SCOPE` / `GLOBAL` enum values kept uppercase as-is |
| 表达式 | expression | The Expression System |
| 预设 | preset | `.tres` preset resources; AI preset toolchain terms are not translated |
| 组件 | component | Collective term for the Event / Instruction / Condition components |
| 毕业交接 | graduation handoff | The process of exporting to engineering code that runs without the plugin |
| 毕业导出器 | graduation exporter | The `export_system` CLI; CLI names are not translated |
| 对象池 | object pool | Class name `FuseObjectPool` kept as-is |
| 监视器 | watcher | Class names such as `VariableWatcher` kept as-is |
| 拓扑 | topology | The `export_topology` CLI / Topology main screen; command names are not translated |
| 事件总线 | event bus | Event Bus |
| 序列化 | serialization | Identifiers such as `preset_value_codec` kept as-is |
| 本地化 | localization | i18n based on the TranslationDomain |
| 信号 | signal | Godot signal |
| 生命周期 | lifecycle | |
| 防抖 | debounce | Trigger debounce |
| 检查器 | Inspector | The Godot Inspector panel |
| 场景 | scene | Godot Scene |
| 节点 | node | Godot Node |
| 指令生成器 | instruction generator | In-editor tool that derives instructions from a scene |

## Content Kept in English As-Is

- Class names / `class_name` (e.g. `BaseInstructionResource`), component registration names (e.g. `PlayAnimation`, `SetVariable`)
- `@export` parameter names, enum values, signal names, function names
- Entire contents of code blocks (GDScript / JSON / command lines)
- File and directory paths, `res://` paths
- CLI names and arguments (`export_topology`, `validate_preset`, `eval_runner`, `derive_systems`, etc.)

## Common Phrase Equivalents

| Chinese | English |
|------|------|
| **适用对象**: XXX | **Audience**: XXX |
| **最后更新**: YYYY-MM-DD | **Last updated**: YYYY-MM-DD |
| 快速开始 | Quick Start |
| 使用场景 | Use cases |
| 验证规则 | Validation rules |
| 基本用法 | Basic usage |
| 常见陷阱 | Common pitfalls |
| 最佳实践 | Best practices |

---

## Introductions File Names

Since 2026-09-02, the Introductions file names in the zh tree have been anglicized (`01-overview.md`, `02-trigger-trio.md` … `16-ai-collaboration-and-graduation-handoff.md`); **both trees use the same directory and the same file names**, so cross-language links and tool handling require no file-name mapping.

`introductions-诊断报告-*.md` are provisional diagnostic documents and are not translated.

## Do-Not-Translate List

`UPDATE_SPEC.md` and `NEW_DOCS_SPEC.md` in each directory (one-off organization specs; provisional documents).

## Per-Document Translation Checklist

- [ ] Terminology matches this glossary
- [ ] Code blocks, component names, and paths kept as-is
- [ ] TOC anchors regenerated from the English headings, each one navigable
- [ ] In-document links point to the corresponding en_US documents; where none exists, link zh_CN and mark `(Chinese)`
- [ ] First-line language switch line correct (only when both languages exist)
- [ ] `tools/check_doc_links.py` exits 0 (zero broken links outside the allowlist)
