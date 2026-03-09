---
name: foc-desktop-development
description: Assist in developing an industrial-grade PySide6 QML based FOC motor control desktop tool. Focus on motor command control and real-time telemetry visualization. OTA is not included in this phase.
---

# FOC Desktop Development Skill (Phase 1) （FOC桌面开发目标（阶段1））

## Project Positioning（项目定位）

This project is an industrial FOC motor tuning and monitoring platform.

It is NOT:
- a serial debugging assistant
- a demo GUI
- a protocol playground

It IS:
- a structured control console
- a deterministic telemetry visualizer
- an embedded-system-grade desktop frontend

---

## Primary Objectives (Phase 1)（主要目标）

The system must support:
1. Sending structured motor control commands（发送结构化电机控制命令）
    - UI → BackendFacade → Service → Transport
    - UI must never access transport directly.
2. Receiving and decoding FOC telemetry frames（接收并解码 FOC 遥测帧）
3. Real-time UI visualization of motor state（电机状态的实时 UI 可视化）
4. Deterministic fault state handling（确定性故障状态处理）

OTA upgrade is NOT included in this phase.（OTA 升级不包含在此阶段）

---

## Encoding Rule（编码规则）

All files in this project MUST use **UTF-8 encoding**.

Applies to:
- Python source files (.py)
- QML files (.qml)
- Markdown documentation (.md)
- JSON configuration files (.json)

Forbidden encodings:
- GBK
- GB2312
- ANSI
- UTF-16

All AI-generated files must be UTF-8 encoded.

All text in source code and documentation must be UTF-8 compatible.

---

## Current Project Architecture（当前项目架构）

All outputs must strictly integrate into:
core/
    command/
    protocol/
    transport/
    service/
ui/
    QMLFiles/

### Architecture Overview（架构概览）

| Layer | Responsibility |
|-------|---------------|
| UI | User interaction, visualization only |
| BackendFacade | System coordinator, exposes API to UI, connects backend modules |
| Service | Business logic, frame dispatch, state management |
| Transport | Byte transport only, serial communication |
| Protocol | Pure functions, frame encode/decode |

No new top-level directories allowed.（不允许新的顶级目录）

---

## Rules & Constraints（规则与约束）

All backend components must follow the architecture rules defined below.  
Violating these constraints will break the system design.
- [Communication Model](./rules/communication-model.md) — Signal/Slot rules, threading, ownership model（信号/槽规则、线程规则、所有权模型）
- [Layer Contracts](./rules/layer-contracts.md) — Protocol, Transport, Service constraints and data processing strategy（各层约束与数据处理策略）

---

## Reference（参考资料）

- [Architecture Diagram](./reference/Architecture.md) — Full architecture visual and data flow paths（架构图与数据流路径）
- [PC-MCU Protocol](./reference/pc_mcu_protocol.md) — Frame format, command list, CRC specification（帧格式、命令列表、CRC 规格）
