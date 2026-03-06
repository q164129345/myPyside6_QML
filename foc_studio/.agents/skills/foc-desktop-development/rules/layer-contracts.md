# Layer Contracts（系统分层约束）

This document defines the architectural responsibilities and boundaries
between system layers in the FOC Studio desktop application.

These rules ensure the system remains:

- maintainable
- testable
- scalable
- predictable

Violating these rules will cause architecture degradation.

---

# System Layer Overview

The system is organized into the following layers:

- UI Layer
- Backend Facade Layer
- Service Layer
- Command Layer
- Protocol Layer
- Transport Layer

High-level receive flow:

MCU → Transport → Protocol → Service → BackendFacade → UI

Command flow:

UI → BackendFacade → Command → Protocol → Transport → MCU

Each layer has **strict responsibilities and restrictions**.

---

# 1 - Transport Layer（传输层）

Location:

core.transport

Responsibilities:

- Serial port communication
- Raw byte transmission
- Raw byte reception
- Hardware communication management

Characteristics:

- Byte-stream oriented
- IO layer only
- Lightweight
- No protocol awareness

Typical output:

dataReceived(bytes)

Transport layer MUST NOT:

- Parse protocol frames
- Interpret payload data
- Implement business logic
- Dispatch commands
- Manage parsing buffers
- Maintain application state

Transport layer acts as a **pure byte carrier**.

---

# 2 - Protocol Layer（协议层）

Location:

core.protocol

Responsibilities:

- Frame encoding
- Frame validation
- CRC verification
- Frame extraction from byte sequences

Example frame format:

head1 head2 cmd datalen data[] crc16_h crc16_l  
0xAA  0xBB  1B  1B      N     1B      1B

CRC specification:

- CRC16-MODBUS
- Polynomial: 0x8005
- Initial value: 0xFFFF
- Big-endian storage

Protocol layer characteristics:

- Pure functions
- Stateless
- Deterministic
- No side effects
- No QObject usage
- No dependency on Qt

Protocol layer MUST NOT:

- Store buffers
- Maintain runtime state
- Access transport
- Access UI
- Emit signals
- Implement retry logic
- Implement business dispatch

Protocol layer operates only on **given input bytes**.

Buffer management is handled by the service layer.

---

# 3 - Command Layer（命令构造层）

Location:

core.command

Responsibilities:

- Construct command payloads
- Provide semantic command APIs
- Hide protocol details from upper layers

Examples of command types:

- enable motor
- set motor speed
- clear fault
- configure parameters

Command layer characteristics:

- Stateless
- Pure construction logic
- No IO operations

Command layer MUST NOT:

- Access UI
- Access transport
- Parse incoming frames
- Maintain runtime state
- Emit Qt signals

Command layer prepares **command payloads only**.

Actual transmission is handled by other layers.

---

# 4 - Service Layer（业务服务层）

Location:

core.service

Service layer is the **core business logic layer**.

Responsibilities include:

Frame dispatching

- Receive parsed frames
- Dispatch frames based on command ID
- Route frames to proper processing logic

Data processing

- Interpret payload data
- Maintain runtime state
- Update telemetry values
- Emit signals for UI updates

State management

- Track device status
- Maintain runtime variables
- Provide processed information to upper layers

Service layer characteristics:

- Stateful
- Deterministic
- Non-blocking
- Qt-aware (signals allowed)

Service layer MUST NOT:

- Perform serial communication
- Implement protocol encoding
- Perform blocking IO
- Access UI directly

Service layer may interact with:

- Protocol layer
- Transport layer
- BackendFacade layer

Service layer is responsible for **system runtime state**.

---

# 5 - Backend Facade Layer（系统门面层）

Location:

core

BackendFacade is the **single entry point between UI and backend system**.

Responsibilities:

- Coordinate backend subsystems
- Expose high-level APIs to UI
- Manage system lifecycle
- Connect signals between layers

Example responsibilities:

- connect serial port
- disconnect serial port
- send control commands
- provide system status to UI

Facade characteristics:

- Thin coordination layer
- No heavy business logic

BackendFacade MUST NOT:

- Parse protocol frames
- Implement transport logic
- Duplicate service functionality

BackendFacade exists to **simplify UI interaction**.

---

# 6 - UI Layer（界面层）

Location:

ui

Responsibilities:

- User interaction
- Data visualization
- User command input

UI communicates only with:

BackendFacade

UI MUST NOT:

- Access transport
- Access protocol
- Parse frames
- Implement business logic
- Maintain application state

UI is strictly a **presentation layer**.

---

# Layer Interaction Rules

Allowed interactions:

UI → BackendFacade

BackendFacade → Service  
BackendFacade → Command

Service → Protocol  
Service → Transport

Command → Protocol

Transport → OS / Serial Driver

---

Forbidden interactions:

UI → Protocol  
UI → Transport

Protocol → UI  
Protocol → Transport

Command → Transport

Transport → Business Logic

These rules prevent architectural coupling.

---

# Data Receive Strategy（数据接收策略）

Receiving data from the MCU must follow **incremental parsing**.

Typical workflow:

1. Transport receives bytes from serial port
2. Transport emits raw byte stream
3. Service layer appends data to internal buffer
4. Protocol layer attempts frame extraction
5. Service processes valid frames

Pseudo workflow:

append incoming bytes → buffer

loop:

try parse frame

if frame valid  
 process frame  
 remove consumed bytes

if insufficient data  
 break

if invalid header  
 discard one byte

The system must support:

- Sticky packets
- Partial packets
- Multiple frames in one read

Never assume that a full frame arrives in a single read.

---

# Architectural Principles

The system follows these principles:

- Single Responsibility
- Layer Isolation
- Stateless Protocol Logic
- Transport as Byte Carrier
- Service as Business Core
- Facade as UI Gateway

These principles guarantee:

- clean architecture
- maintainable code
- predictable behavior
- scalable system design