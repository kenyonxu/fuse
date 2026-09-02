> 🌐 [**中文版**](../zh_CN/README.md) | English

# Fuse Visual Programming System - Documentation Hub

Fuse is a Godot 4.7 visual programming plugin: Event / Instruction / Condition bricks are assembled into logic in the Inspector, AI can generate presets, and stabilized systems can "graduate" into plugin-free project code — a non-destructive bridge from prototype to code.

## 📚 Documentation categories

Each of the three subdirectories has its own README as full navigation; this page only provides an overview.

### 📖 [User documentation](user_docs/) ([Full index](user_docs/README.md))

For users. Three content tracks:

- **Introductions series** (16 articles): the complete tutorial path from overview to AI collaboration and graduation handoff; entry point [01-Overview (Chinese)](../zh_CN/user_docs/Introductions/01-总览篇.md)
- **Usage guides** (40+ articles): numbered installments covering variables, triggers, expressions, each instruction domain, events, conditions, and advanced topics; entry point [00-index](user_docs/guides/00-index.md)
- **Best practices** (5 articles): the custom-component trilogy ([event (Chinese)](../zh_CN/user_docs/best_practices/custom_event.md) / [instruction (Chinese)](../zh_CN/user_docs/best_practices/custom_instruction.md) / [condition (Chinese)](../zh_CN/user_docs/best_practices/custom_condition.md)) plus two user-practice articles ([Preset reuse and AI collaboration (Chinese)](../zh_CN/user_docs/best_practices/preset_reuse.md) / [Trigger organization and race avoidance (Chinese)](../zh_CN/user_docs/best_practices/trigger_organization.md))

First-time users should enter through the [Quick Start Guide](user_docs/quick_start.md).

### 🏗️ [System documentation (Chinese)](../zh_CN/system_docs/) ([Full index (Chinese)](../zh_CN/system_docs/README.md))

For architects and core developers: architecture design (9 articles, e.g. [Visual Programming System Architecture (Chinese)](../zh_CN/system_docs/architecture/visual_programming_system_architecture.md), [Dataflow and Control Flow Design (Chinese)](../zh_CN/system_docs/architecture/dataflow_controlflow_design.md)) and 20+ mechanism analysis reports (each article was verified against the code during a full documentation audit on 2026-07-07, with an analysis-time note at the head of each article).

### 👨‍💻 [Development documentation (Chinese)](../zh_CN/dev_docs/) ([Full index (Chinese)](../zh_CN/dev_docs/README.md))

For contributors: component creation guides ([event (Chinese)](../zh_CN/dev_docs/guides/event-creation-guide.md) / [instruction (Chinese)](../zh_CN/dev_docs/guides/instruction-creation-guide.md) / [condition (Chinese)](../zh_CN/dev_docs/guides/condition-creation-guide.md); the accompanying agent_skills generation skills are the normative authority), runtime architecture (RuntimeInstance, [Event RuntimeInstance migration (Chinese)](../zh_CN/dev_docs/guides/runtime-instance-migration-guide.md), multithreading), and infrastructure (Event Bus, serialization, icons, object pool). Historical archives live in the local `archive/` (not committed).

---

## 🚀 Quick Start

### Get started with Fuse in 5 minutes

1. **Create a trigger node**: add Trigger / MultiEventTrigger / Runner to the scene (see the [Trigger Selection Guide (Chinese)](../zh_CN/user_docs/guides/02-trigger-selection-guide.md) for how to choose among the three)
2. **Configure the action sequence**: create an ActionRunner resource in the Trigger's Inspector
3. **Add instructions**: add instructions to the ActionRunner's instructions array
4. **Test run**: run the scene; the logic executes when the event fires

### Basic concepts

- **Event**: decides when your logic fires — key presses, collisions, signals, lifecycle
- **Instruction**: the actions executed after triggering — move nodes, play sounds, flow control
- **Condition**: checks performed before execution — variable comparisons, composite logic (AND/OR/NOT)
- **Variable**: data stored in three-layer scopes (LOCAL / SCOPE / GLOBAL)
- **Trigger**: the event entry point; manages instruction execution and debounce

### Next steps

- [Quick Start Guide](user_docs/quick_start.md) for detailed steps
- [01-Overview (Chinese)](../zh_CN/user_docs/Introductions/01-总览篇.md) for a systematic introduction
- [Best practices (Chinese)](../zh_CN/user_docs/best_practices/) for creating custom components

---

## 📊 System status

- **Current version**: Fuse 1.0.0 (see `addons/fuse/plugin.cfg`)
- **Godot compatibility**: 4.7+
- **Component count**: 310 ready-to-use components (70 events × 185 instructions × 55 conditions; authoritative source: `addons/fuse/preset_ai_context/fuse_components.json`)
- **Documentation size**: roughly 130 articles across the whole tree (see each subdirectory's README for details)

---

## 🎯 Find documentation by role

### Game designers (no coding)
[Quick Start Guide](user_docs/quick_start.md) → [Introductions series (Chinese)](../zh_CN/user_docs/Introductions/01-总览篇.md) → [Variable system (Chinese)](../zh_CN/user_docs/guides/01-variable-system-guide.md)

### AI-assisted developers
[Preset reuse and AI collaboration practice (Chinese)](../zh_CN/user_docs/best_practices/preset_reuse.md) → [AI collaboration and graduation handoff (Chinese)](../zh_CN/user_docs/Introductions/16-AI协作与毕业交接.md)

### Game developers (extending components)
[Create a custom event (Chinese)](../zh_CN/user_docs/best_practices/custom_event.md) · [instruction (Chinese)](../zh_CN/user_docs/best_practices/custom_instruction.md) · [condition (Chinese)](../zh_CN/user_docs/best_practices/custom_condition.md)

### System architects
[Visual Programming System Architecture (Chinese)](../zh_CN/system_docs/architecture/visual_programming_system_architecture.md) → [Dataflow and Control Flow Design (Chinese)](../zh_CN/system_docs/architecture/dataflow_controlflow_design.md) → [Fuse Architecture Advantages Analysis (Chinese)](../zh_CN/system_docs/analysis/fuse_architecture_advantages_analysis.md)

### Core developers
[Instruction System Design (Chinese)](../zh_CN/system_docs/architecture/instruction_system_design.md) → [RuntimeInstructionInstance Guide (Chinese)](../zh_CN/dev_docs/guides/runtime-instruction-instance-guide.md) → [Multithreading Developer Guide (Chinese)](../zh_CN/dev_docs/guides/multithreading-developer-guide.md)

---

## 📖 Related resources

- [Game Creator documentation](https://gamecreator.io/) - visual programming reference
- [Godot official documentation](https://docs.godotengine.org/) - Godot API reference
- [Project development guidelines](../../../../CLAUDE.md) / [AGENTS.md](../../../../AGENTS.md) - code standards and development guides
- [Test scenes](../../../../tests/) - system tests (repo root level, not distributed with the plugin)
- [Demo scenes](../../../../demos/) - feature demos

---

## 📝 Documentation changelog

### v1.5.0 (2026-09-02)
- ✅ Root README returned to its hub role: detailed navigation handed back to each subdirectory README (listing details on the root page once caused 27 broken links and three sets of stale statistics)
- ✅ Added entries for the new Introductions and best-practices articles; added an AI-assisted developer track to the role entries
- ✅ Basic concepts now include Condition and the SCOPE scope; Quick Start rephrased around the three trigger types
- ✅ Fixed the tests link (moved to repo root); statistics switched to a drift-resistant methodology (pointing to authoritative sources)

### v1.4.0 (2026-07-07)
- ✅ Reorganized the documentation tree: only system_docs / dev_docs / user_docs remain
- ✅ Archived 68 outdated documents to archive/ (stage specs/plans, proposals, reports, architecture remediation plans, ideas, vision, etc.)
- ✅ archive/ added to .gitignore (kept locally, not published)

### v1.3.0 (2026-03-19)
- ✅ Documentation audit and cleanup: deleted 7 temporary files, archived 19 outdated documents
- ✅ Archived the outdated Trigger system design document (migrated to the Event pattern)
- ✅ Added 12 user guides and the BaseEvent / MultiEventTrigger / Runner technical analyses

### v1.2.0 (2026-03-19)
- ✅ Added the breakpoint instruction usage guide (BreakpointInstruction)

### v1.1.0 (2026-03-18)
- ✅ Added Expression System / scene preloading / global variable persistence / instruction generator guides
- ✅ Archived the old roadmap and completed task reports

### v1.0.0 (2026-01-25)
- ✅ Created the main documentation hub and navigation system

---

## 🤝 Contributing

Improvements to the documentation are welcome:
- Use clear Chinese expression, and provide code examples and use cases
- Register new documents in the owning subdirectory's README (each directory has its own registration conventions)
- Keep documentation in sync with code; for figures, defer to authoritative sources (component count: see `preset_ai_context/fuse_components.json`)

If you find a problem, please open a project Issue noting the document path and a description of the problem.

---

**Documentation maintainers**: Fuse development team
**Last updated**: 2026-09-02
**Documentation version**: 1.5.0
