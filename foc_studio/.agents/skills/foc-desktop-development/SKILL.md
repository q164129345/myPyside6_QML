---
name: foc-desktop-development
description: Assist in developing an industrial-grade PySide6 QML based FOC motor control desktop tool. Focus on motor command control and real-time telemetry visualization. OTA is not included in this phase.
---

# FOC Desktop Development Skill (Phase 1)

## Project Positioning

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

# Primary Objectives (Phase 1)

The system must support:

1. Sending structured motor control commands
2. Receiving and decoding FOC telemetry frames
3. Real-time UI visualization of motor state
4. Deterministic fault state handling

OTA upgrade is NOT included in this phase.

---

# Current Project Architecture

All outputs must strictly integrate into:

core/
    protocol/
    transport/
    service/
ui/
    QMLFiles/

No new top-level directories allowed.

---

# Protocol Layer

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

- All protocol functions must be pure(纯函数)
- No QObject usage(不依赖Qt特性)
- No state(无状态)
- No buffer ownership(不拥有缓冲区)
- No side effects(无副作用)
- CRC must be verified before accepting frame(必须验证CRC)
- Must support incremental parsing(必须支持增量解析,适应粘包和半包)

It is strictly responsible for:
1. Frame construction (encode)
2. Single-frame parsing attempt from a buffer (decode attempt)

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

# Transport Layer

Location:
core.transport.serial.mySerial

Characteristics:

- Uses QSerialPort
- Emits: dataReceived(bytes)
- No protocol parsing
- No business logic
- Lightweight only
- 
Transport is byte carrier only.

Never move parsing logic into transport.

---

# Service Layer

Location:
core.service.data_processor.DataProcessor

Responsibilities:

- Maintain persistent bytearray buffer
- Append incoming bytes
- Call protocol parsing function
- Handle:
    - valid frame
    - discardable bytes
    - insufficient data
- Remove consumed bytes safely
- Dispatch parsed data via Qt signals

Service layer is:

- Stateful
- Deterministic
- Thread-safe (UI thread safe, no blocking)

Service layer must NOT:
- Access QML directly
- Perform blocking operations
- Modify transport logic

---

# Data Processing Strategy

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

Never assume full frame arrives in one read.

Must support:
- Sticky packets
- Partial packets
- Multiple frames in one read

---

# FOC Domain Context

This desktop tool interacts with a FOC motor controller.

Control hierarchy:

Speed Loop → Current Loop → Voltage Vector → PWM

Typical runtime telemetry:

- speed (rpm)
- iq (A)
- id (A)
- bus voltage (V)
- temperature (°C)
- current_limit clamp status
- hard fault state
- driver fault flags

Protection types:

Soft clamp:
- Current limited but system running

Hard fault:
- Motor disabled
- Requires host reset command

Service layer must clearly distinguish between these states.

---

# UI Interaction Rules

Architecture:

UI (QML)
    ↓
Backend QObject
    ↓
Service Layer
    ↓
Protocol Functions

Rules:

- No protocol parsing in QML
- No bytearray in QML
- No blocking calls in UI thread
- UI receives data only via Qt Signals
- UI must treat backend as data provider only

---

# Required Signal Design (Example)

Service layer should emit signals like:

speedUpdated(float)
currentUpdated(float iq, float id)
voltageUpdated(float)
temperatureUpdated(float)
faultUpdated(int)
clampStateUpdated(bool)

Signals must be granular and deterministic.

Avoid sending raw frame data to UI.

---

# Command Sending Rules

When sending control commands:

- Must use protocol_frame to build frame
- Must send through transport layer
- Must validate parameter range before sending
- Must never send malformed frame
- Must handle error responses

Example control types:

- enable motor
- disable motor
- set speed
- set iq
- set current_limit
- clear fault

---

# Engineering Standards

All generated code must reflect:

- Deterministic behavior
- Defensive programming
- Clear separation of concerns
- No hidden side effects
- Embedded-system-grade rigor
- Production-ready quality

---

# Prohibited Behaviors

- No CRC skipping
- No protocol redesign
- No parsing in QML
- No global variables
- No dynamic monkey-patching
- No blocking operations in UI thread
- No mixing of transport and business logic

---

# Phase Boundary

This version of the project does NOT include:

- OTA firmware upgrade
- File transfer
- Multi-device management
- Network support

Focus only on:

Reliable motor control + Stable real-time telemetry visualization.