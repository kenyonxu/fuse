> 🌐 [**中文版**](../../zh_CN/system_docs/README.md) | English

# System Documentation (system_docs)

Authoritative documentation for system architects and core developers: architecture design, data flow / control flow, and in-depth analysis of the core components.

> For developer-oriented guides, see [../dev_docs/](../dev_docs/); for user-oriented usage documentation, see [../user_docs/](../user_docs/); for historical design / analysis documents, see `archive/`.

---

## 🏗️ Architecture Design Documents (9 docs)

### Core Architecture
| Document | Description |
|------|------|
| [Visual Programming System Architecture](architecture/visual_programming_system_architecture.md) | Overall system architecture, main component responsibilities, extension points, and the Godot integration approach |
| [Complete Design Summary](architecture/visual_programming_complete_design_summary.md) | System design summary, core features, technical highlights |

### System Design
| Document | Description |
|------|------|
| [Data Flow and Control Flow Design](architecture/dataflow_controlflow_design.md) | Data flow diagrams, control flow design, execution flow optimization |
| [Variable System Design](architecture/variable_system_design.md) | Variable containers, managers, scope control, persistence |
| [Instruction System Design](architecture/instruction_system_design.md) | Instruction base classes, execution modes, error handling, async execution |
| [Condition System Design](architecture/condition_system_design.md) | Condition base classes, composite conditions, condition evaluation |

### Integration and Extension
| Document | Description |
|------|------|
| [Godot Integration Design](architecture/godot_integration_design.md) | Resource / Signal / NodePath / SceneTree integration |
| [Editor Tools Design](architecture/editor_tools_design.md) | Custom Inspector, visual editor, node tools |

### Event Design
| Document | Description |
|------|------|
| [Event: Key Input](architecture/event_on_input_key_design.md) | Key event design, input mapping, event triggering |

---

## 🔍 Analysis Reports (20+ docs)

### System Analysis
| Document | Description |
|------|------|
| [Fuse Architecture Analysis](analysis/fuse_architecture_analysis.md) | Overall architecture, component relationships, design patterns, runtime instance system |
| [Fuse Architecture Advantages Analysis](analysis/fuse_architecture_advantages_analysis.md) | Architecture advantages, design trade-offs |
| [Core System Analysis](analysis/fuse_core_analysis_report.md) | Core component analysis, performance assessment, optimization suggestions |

### Component Analysis
| Document | Description |
|------|------|
| [BaseInstruction Analysis](analysis/base_instruction_analysis.md) | Instruction base class interface design, extension mechanisms |
| [BaseCondition Analysis](analysis/base_condition_analysis.md) | Condition base class, condition evaluation, composite conditions |
| [BaseEvent Analysis](analysis/base_event_analysis.md) | Event base class, event lifecycle |
| [BaseTrigger Analysis](analysis/base_trigger_analysis.md) | Trigger base class, event handling, lifecycle |
| [BaseVariable Analysis](analysis/base_variable_analysis.md) | Variable base class, type system, storage mechanisms |
| [ExecutionContext Analysis](analysis/execution_context_analysis.md) | Execution context, variable access, state management |
| [ActionRunner Analysis](analysis/action_runner_analysis.md) | Action executor, execution flow, performance characteristics |
| [MultiEventTrigger Analysis](analysis/multi_event_trigger_analysis.md) | Multi-event trigger mechanism |
| [Runner Analysis](analysis/runner_analysis.md) | The Runner execution model |

### Topic Analysis
| Document | Description |
|------|------|
| [Object Pool Analysis](analysis/pooling_analysis.md) | 5 classes under `core/pooling/`: FuseObjectPool / PoolManager / InstructionInstancePool, etc. |
| [Threading System Analysis](analysis/threading_analysis.md) | 4 classes under `core/threading/`: FuseTaskManager / ParallelConditionEvaluator, etc. |
| [Variable System Analysis](analysis/variable_system_analysis.md) | The full chain of 7 variable classes: BaseVariable / VariableContext / three-layer scopes / GlobalVariable* |
| [Runtime Instance Analysis](analysis/runtime_instance_analysis.md) | The trio: RuntimeEvent/Instruction/ActionRunnerInstance, state isolation + pooling integration |
| [Global Infrastructure Analysis](analysis/global_infrastructure_analysis.md) | FuseEventBus (event bus) + FuseRuntimeBridge (TCP bridge for variable watching) |
| [Serialization Analysis](analysis/serialization_analysis.md) | InstructionSerializer (reflection-based serialization) + CompiledInstructionSequence (compiled cache) |

---

## 🎯 Task-Oriented Entry Points

### I want to understand the overall architecture
→ [Visual Programming System Architecture](architecture/visual_programming_system_architecture.md) · [Fuse Architecture Analysis](analysis/fuse_architecture_analysis.md) · [Complete Design Summary](architecture/visual_programming_complete_design_summary.md)

### I want to dive into a specific subsystem
→ Variables: [Design](architecture/variable_system_design.md) · [BaseVariable Analysis](analysis/base_variable_analysis.md)
→ Instructions: [Design](architecture/instruction_system_design.md) · [BaseInstruction Analysis](analysis/base_instruction_analysis.md) · [ActionRunner Analysis](analysis/action_runner_analysis.md)
→ Conditions: [Design](architecture/condition_system_design.md) · [BaseCondition Analysis](analysis/base_condition_analysis.md)
→ Events / triggers: [Key Event Design](architecture/event_on_input_key_design.md) · [BaseEvent Analysis](analysis/base_event_analysis.md) · [BaseTrigger Analysis](analysis/base_trigger_analysis.md) · [MultiEventTrigger](analysis/multi_event_trigger_analysis.md)

### I want to understand the execution flow and context
→ [Data Flow and Control Flow](architecture/dataflow_controlflow_design.md) · [ExecutionContext Analysis](analysis/execution_context_analysis.md) · [Runner Analysis](analysis/runner_analysis.md)

### I want to do Godot integration or editor extension
→ [Godot Integration Design](architecture/godot_integration_design.md) · [Editor Tools Design](architecture/editor_tools_design.md)

---

## 🔗 Cross-Directory Resources

### Developer Documentation (../dev_docs/)
- [Developer Documentation Overview](../dev_docs/README.md) · [Developer Guides Directory](../dev_docs/guides/)
- [Multithreading Developer Guide](../dev_docs/guides/multithreading-developer-guide.md) · [Variable Operations Tools](../dev_docs/guides/variable-operations-guide.md)

### User Documentation (../user_docs/)
- [Global Variable Manager V2](../user_docs/guides/54-global-variables-guide.md) · [Variable System Guide](../user_docs/guides/01-variable-system-guide.md)
- [Creating Custom Events](../user_docs/best_practices/custom_event.md) (extension practices)

### Historical Archive (../archive/)
Early design documents (e.g. `trigger_system_design`, `extensibility_design`, `runtime-instance-pattern`) and optimization analyses (FlowKit / GameCreator) have been archived. For reference only, **not the authoritative source for the current implementation** — refer to the architecture documents in this directory instead.

---

## 📊 Documentation Statistics

| Category | Count |
|------|------|
| Architecture design | 9 docs (`architecture/`) |
| Analysis reports | 18 docs (`analysis/`) |
| Update spec | 1 doc ([UPDATE_SPEC.md (Chinese)](../../zh_CN/system_docs/UPDATE_SPEC.md)) |
| **Total** | **27 docs** + spec |

---

## 📝 Maintenance

- **New documents**: architecture design goes into `architecture/`, analysis reports into `analysis/`, and register them under the matching group in this README
- **Source references**: when analysis documents reference source code, use inline code (e.g. `` `addons/fuse/core/base/base_event.gd` ``) to avoid relative-link base path errors
- **Link health**: when adding / modifying documents, make sure all relative links point to files that actually exist

---

**Last updated**: 2026-09-02
**Maintainer**: Fuse development team
