---
name: foc-desktop-development
description: Assist in developing an industrial-grade PySide6 QML based FOC motor control desktop tool. Use this skill when working with serial communication, CRC16 frame parsing, MVVM architecture, real-time data processing, or motor control domain logic.
---

# FOC Desktop Development Skill

## Instructions

This project is an industrial motor control desktop tool,
not a demo GUI application.

All outputs must follow the actual project architecture
and integrate with the existing modules:

- core.protocol
- core.transport
- core.service
- ui (QML)

Generated code must be compatible with the current implementation.

---

## Current Project Architecture

Project structure:

core/
    protocol/
        protocol_frame.py
    transport/
        serial.py
    service/
        data_processor.py
ui/
    QMLFiles/

Entry point:
main.py

Signal chain:

QSerialPort
    ↓
mySerial.dataReceived (bytes)
    ↓
DataProcessor.process_data(bytes)

---

## Communication Model (Actual Implementation)

Protocol specification (implemented):

Frame format:

head1 head2 cmd datalen data[] crc16_h crc16_l
0xAA  0xBB  1B  1B      N     1B      1B

CRC16:
- CRC16-MODBUS
- Polynomial: 0x8005
- Initial value: 0xFFFF
- Big-endian storage

Frame parsing strategy:

- Pure function design
- No side effects
- Incremental parsing using bytearray
- Support sticky packets
- CRC must be verified before accepting frame

Refer to:
core.protocol.protocol_frame

Do not redesign protocol logic unless explicitly requested.

---

## Transport Layer Rules

Transport layer implementation:

Class:
core.transport.serial.mySerial

Characteristics:

- Uses QSerialPort
- Emits dataReceived(bytes)
- Does not parse protocol
- No business logic inside transport
- No UI access
- Must remain lightweight

Never move parsing logic into transport layer.

---

## Service Layer Rules

Current service:

core.service.data_processor.DataProcessor

Characteristics:

- QObject-based
- Receives raw bytes
- Business logic belongs here
- Future protocol dispatching should be implemented here

Rules:

- Service layer may use protocol_frame functions
- Service layer may manage internal bytearray buffer
- Service layer must not directly manipulate UI
- All UI interaction must use signals

---

## Architectural Constraints

Strict layering:

UI (QML)
    ↓
Backend QObject
    ↓
Service Layer
    ↓
Protocol Functions

Rules:

- No protocol parsing in QML
- No blocking calls in UI thread
- No global variables
- No tight coupling between layers
- No mixing of transport and business logic

---

## Data Processing Strategy

When generating receive logic:

- Maintain a persistent bytearray buffer in service layer
- Append new bytes from serial
- Call parse_frame_from_buffer()
- Handle:
    - valid frame
    - discardable bytes
    - insufficient data
- Remove consumed bytes safely

Never assume a full frame arrives in one read.

---

## FOC Domain Context

This system is intended for FOC motor tuning.

Control hierarchy:

Speed Loop → Current Loop → Voltage Vector → PWM

Typical parameters:

- iq (torque current)
- id (flux current)
- speed
- bus voltage
- current_limit
- over_current_threshold

Protection logic must distinguish:

- soft current clamp
- hard fault state

Fault state requires host reset command.

---

## Code Generation Rules

When generating Python code:

- Use type hints
- Follow current module naming style
- Keep protocol functions pure
- Keep service logic stateful
- Use Qt Signals for cross-layer communication
- Avoid pseudocode
- Provide full implementations

When generating new modules:

Place them inside:

core/
    protocol/
    service/
    transport/

Do not create arbitrary new directories.

---

## Prohibited Behaviors

- No CRC skipping
- No protocol redesign without request
- No UI-thread blocking logic
- No parsing in QML
- No global shared state
- No dynamic monkey-patching

---

## Engineering Standard

All generated output must reflect:

- Deterministic behavior
- Defensive programming
- Embedded-system-grade rigor
- Clean separation of concerns
- Production-ready quality