---
name: foc-desktop-development
description: Assist in developing an industrial-grade PySide6 QML based FOC motor control desktop tool. Focus on motor command control and real-time telemetry visualization. OTA is not included in this phase.
---

# 1 - FOC Desktop Development Skill (Phase 1) （FOC桌面开发目标（阶段1））

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

# 2 - Backend Communication Model（后端通信模型）

## Rule: All QObject-based modules must communicate via Qt Signals/Slots.（所有QObject模块必须通过Qt信号/槽进行通信）
Applies to:
- Transport Layer
- Service Layer
- Backend Facade

Does NOT apply to:
- Protocol Layer (pure functions only)

## Signal-Driven Architecture（信号驱动架构）
Backend modules must follow:
Event-driven model, not direct method coupling.
Prohibited:
- Service directly calling transport.write()
- Transport directly calling service method
- Cross-module method calls after initialization

Allowed:
- Signal → Slot connections only

Example:
Transport.dataReceived → Service.onBytesReceived
Service.speedUpdated → BackendFacade.speedUpdated
BackendFacade.speedUpdated → QML

## Threading Rule（线程规则）
- All signals must be Qt-safe（所有信号必须是 Qt 安全的）
- No blocking operations（无阻塞操作）
- If heavy computation is added later → move to worker thread（如果以后增加重计算 → 移动到工作线程）

## Strict Ownership Model（严格的所有权模型）
- Transport owns QSerialPort（Transport 拥有 QSerialPort）
- Service owns buffer（Service 拥有缓冲区）
- Protocol owns nothing（协议层不拥有任何资源）
- BackendFacade owns service instances（BackendFacade 拥有服务实例）

No shared mutable objects across layers.

---

# 3 - Primary Objectives (Phase 1)（主要目标）

The system must support:
1. Sending structured motor control commands（发送结构化电机控制命令）
    - UI → BackendFacade → Service → Transport
    - UI must never access transport directly.
2. Receiving and decoding FOC telemetry frames（接收并解码 FOC 遥测帧）
3. Real-time UI visualization of motor state（电机状态的实时 UI 可视化）
4. Deterministic fault state handling（确定性故障状态处理）

OTA upgrade is NOT included in this phase.（OTA 升级不包含在此阶段）

---

# 4 - Current Project Architecture（当前项目架构）

All outputs must strictly integrate into:
core/
    protocol/
    transport/
    service/
ui/
    QMLFiles/

## Architecture Overview(架构概览)
System layered architecture:
        QML UI
           │
           ▼
     BackendFacade
           │
           ▼
        Service
           │
           ▼
       Transport
           │
           ▼
        Protocol

Responsibilities:
UI
- User interaction
- Visualization only
BackendFacade
- System coordinator
- Exposes API to UI
- Connects backend modules
Service
- Business logic
- Frame dispatch
- State management
Transport
- Byte transport only
- Serial communication
Protocol
- Pure functions
- Frame encode/decode

No new top-level directories allowed.（不允许新的顶级目录）
For full architecture details see: ./Architecture.md （详细架构请参考：./Architecture.md）
---

# 5 - Protocol Layer（协议层）

Location:
core.protocol.protocol_frame

Frame format (already defined):
head1 head2 cmd datalen data[] crc16_h crc16_l
0xAA  0xBB  1B  1B      N     1B      1B

CRC:
- CRC16-MODBUS
- Polynomial: 0x8005
- Initial: 0xFFFF
- Big-endian storage

Rules:
- All protocol functions must be pure（纯函数）
- No QObject usage（不依赖Qt特性）
- No state（无状态）
- No buffer ownership（不拥有缓冲区）
- No side effects（无副作用）
- CRC must be verified before accepting frame（必须验证CRC）
- Must support incremental parsing（必须支持增量解析,适应粘包和半包）

It is strictly responsible for:
1. Frame construction (encode)
2. attempt_parse_frame(data: bytes)

The protocol layer MUST NOT:
- Store or manage buffers
- Maintain state
- Implement retry logic
- Perform business logic dispatch
- Access UI
- Access transport
- Raise runtime exceptions for malformed data
All functions must be pure and side-effect free.

---

# 6 - Transport Layer（传输层）

Location:
core.transport.serial.mySerial

Characteristics:
- Uses QSerialPort（使用 QSerialPort，串口通讯时）
- Emits: dataReceived(bytes)（发出：dataReceived(bytes)）
- No protocol parsing（不进行协议解析）
- No business logic（不进行业务逻辑处理）
- Lightweight only（仅轻量级）
Transport is byte carrier only.（传输层仅负责字节传输）

Never move parsing logic into transport.（切勿将解析逻辑移动到传输层）

---

# 7 - Service Layer（服务层）

Location:
core.service.data_processor.DataProcessor

Responsibilities:（责任）
- Maintain persistent bytearray buffer（持久化字节数组缓冲区）
- Append incoming bytes（追加接收字节）
- Call protocol parsing function（调用协议解析函数）
- Handle:（处理）
    - valid frame（有效帧）
    - discardable bytes（可丢弃字节）
    - insufficient data（数据不足）
- Remove consumed bytes safely（安全移除已消耗字节）
- Dispatch parsed data via Qt signals（通过 Qt 信号分发解析后的数据）

Service layer is:
- Stateful（有状态）
- Deterministic（确定性）
- Thread-safe (UI thread safe, no blocking)（线程安全，UI 线程安全，无阻塞）
- Business logic only（仅业务逻辑）
- Signal provider for UI（UI数据提供者）
- State manager（状态管理者）

Service layer must NOT:
- Direct function calls are prohibited between them（之间禁止直接函数调用）
   - Use: Service -> BackendFacade -> Service
- Perform blocking operations（执行阻塞操作）
- Modify transport logic（修改传输逻辑）

---

# 8 - Data Processing Strategy（数据处理策略）

When implementing receive logic:
1. Maintain:
   self._buffer: bytearray

2. On dataReceived(bytes):
   - append to buffer
   - loop:
       - try parse_frame_from_buffer()
       - if frame valid:
             process frame
             remove consumed bytes
       - if insufficient data:
             break
       - if invalid header:
             discard one byte and continue

Never assume full frame arrives in one read.（切勿假设完整帧在一次读取中到达）

Must support:
- Sticky packets（粘包）
- Partial packets（半包）
- Multiple frames in one read（一次读取多个帧）
