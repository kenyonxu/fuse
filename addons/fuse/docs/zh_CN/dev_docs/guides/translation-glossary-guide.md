# Fuse 中英翻译术语表（Translation Glossary）

> 本表是 `docs/` 中英双语化（`zh_CN/` 权威源 → `en_US/` 英文镜像）的术语权威。所有英文翻译以此为准，保证跨文档、跨批次一致。

**适用对象**: 文档翻译者、英文文档审校者
**最后更新**: 2026-09-02

---

## 翻译总则

1. **忠实优先**：英文版是中文版的忠实翻译，不增删技术内容、不改代码示例。
2. **代码原样**：代码块、组件名、类名、参数名、枚举值、`res://` 路径、文件路径一律保持英文原样，不翻译不改动。
3. **标题与锚点**：H1/H2 标题译为英文后，目录（TOC）锚点必须按英文标题重新生成——中文标题的锚点在英文版不成立，禁止照抄。
4. **链接改指对应语言**：文内指向其他文档的链接，优先指向 `en_US/` 树的对应英文文档；该文档尚无英文版时，链接 `zh_CN/` 原文档并在链接文字后加 ` (Chinese)` 标注。
5. **语言切换行**：双语均存在的文档，在首行（H1 之前）加切换行；只有单语的文档不加。
6. **不引入 frontmatter**：仓库文档无 YAML frontmatter 惯例，双语版同样不引入。

### 语言切换行格式

文档第一行（H1 之前），相对路径按所在目录自行计算：

```markdown
> 🌐 [**中文版**](../../zh_CN/user_docs/guides/01-variable-system-guide.md) | English
```

```markdown
> 🌐 中文 | [**English**](../../en_US/user_docs/guides/01-variable-system-guide.md)
```

---

## 核心术语表

| 中文 | 英文 | 说明 |
|------|------|------|
| 事件 | event | 三类砖块之一；类名 `BaseEvent` 原样 |
| 指令 | instruction | 类名 `BaseInstruction` 原样 |
| 条件 | condition | 类名 `BaseCondition` 原样 |
| 触发器 | trigger | 节点名 `Trigger` / `MultiEventTrigger` 原样 |
| 运行器 | runner | 节点名 `Runner` 原样 |
| 动作运行器 | ActionRunner | 资源类名，不译 |
| 执行上下文 | execution context | 类名 `ExecutionContext` 原样 |
| 运行时实例 | runtime instance | `RuntimeEventInstance` / `RuntimeInstructionInstance` 原样 |
| 变量 | variable | 类名 `BaseVariable` 原样 |
| 三层作用域 | three-layer scopes | `LOCAL` / `SCOPE` / `GLOBAL` 枚举值原样大写 |
| 表达式 | expression | 表达式系统 Expression System |
| 预设 | preset | `.tres` preset 资源；AI preset 工具链相关名词不译 |
| 组件 | component | Event / Instruction / Condition 组件的统称 |
| 毕业交接 | graduation handoff | 导出为脱离插件的工程代码的流程 |
| 毕业导出器 | graduation exporter | `export_system` CLI，CLI 名不译 |
| 对象池 | object pool | 类名 `FuseObjectPool` 原样 |
| 监视器 | watcher | `VariableWatcher` 等类名原样 |
| 拓扑 | topology | `export_topology` CLI / Topology 主屏，命令不译 |
| 事件总线 | event bus | Event Bus |
| 序列化 | serialization | `preset_value_codec` 等标识符原样 |
| 本地化 | localization | 基于 TranslationDomain 的 i18n |
| 信号 | signal | Godot signal |
| 生命周期 | lifecycle | |
| 防抖 | debounce | 触发器防抖 |
| 检查器 | Inspector | Godot Inspector 面板 |
| 场景 | scene | Godot Scene |
| 节点 | node | Godot Node |
| 指令生成器 | instruction generator | 编辑器内根据场景反推指令的工具 |

## 保持英文原样的内容

- 类名 / `class_name`（如 `BaseInstructionResource`）、组件注册名（如 `PlayAnimation`、`SetVariable`）
- `@export` 参数名、枚举值、信号名、函数名
- 代码块全部内容（GDScript / JSON / 命令行）
- 文件与目录路径、`res://` 路径
- CLI 名称与参数（`export_topology`、`validate_preset`、`eval_runner`、`derive_systems` 等）

## 常用句式对照

| 中文 | 英文 |
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

## Introductions 系列文件名

2026-09-02 起 zh 树 Introductions 文件名已英文化（`01-overview.md`、`02-trigger-trio.md` … `16-ai-collaboration-and-graduation-handoff.md`），**两树同目录同文件名**，双语互链与工具处理无需任何文件名映射。

`introductions-诊断报告-*.md` 为过程性诊断文档，不翻译。

## 不翻译清单

各目录 `UPDATE_SPEC.md`、`NEW_DOCS_SPEC.md`（一次性整理规格，过程性文档）。

## 单篇翻译检查清单

- [ ] 术语与本表一致
- [ ] 代码块、组件名、路径原样保留
- [ ] TOC 锚点按英文标题重新生成，逐个可跳转
- [ ] 文内链接指向 en_US 对应文档，无对应时链 zh_CN 并标 `(Chinese)`
- [ ] 首行语言切换行正确（仅双语均存在时）
- [ ] `tools/check_doc_links.py` 退出码 0（白名单外零断链）
