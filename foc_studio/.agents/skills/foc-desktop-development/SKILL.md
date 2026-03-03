---
name: foc-desktop-development
description: Assist in building an industrial-grade FOC motor control desktop tuning tool using PySide6 and QML. Use this skill when designing MVVM architecture, implementing serial communication with incremental frame parsing, creating real-time waveform visualization, or applying FOC domain logic including current limits and fault handling.
---

# FOC Desktop Development Skill

## Instructions

Follow strict engineering architecture principles when generating output.

This system is an industrial motor control tuning tool,
not a demo GUI application.

All outputs must respect:

- MVVM architecture
- Thread-safe communication
- Deterministic protocol parsing
- Industrial-grade fault handling

---

## Technical Context

Language:
Python 3.11+

Framework:
PySide6

UI:
QML

Architecture:
MVVM

Communication:
QSerialPort with incremental bytearray parsing

Thread Model:
UI Thread + QThread worker

No blocking calls allowed in UI thread.

---

## Architecture Rules

Layer structure:

QML (View)
→ ViewModel (Signal bridge)
→ Service Layer
→ Transport Layer
→ Protocol Parser

Rules:

- UI must not contain business logic
- ViewModel must not parse protocol frames
- Transport layer must not access UI
- Protocol parsing must be isolated
- CRC verification is mandatory

---

## FOC Domain Knowledge

Control chain:

Speed Loop → Current Loop → Voltage Vector → PWM

Key parameters:

- iq = torque-producing current
- id = flux current (typically 0 in surface PMSM)
- current_limit = soft clamp
- over_current_threshold = fault trigger
- Fault must be cleared by host command

Protection behavior:

If current > current_limit:
    clamp output

If current > over_current_threshold:
    enter fault
    disable PWM
    wait for reset command

---

## Communication Model

Frame format:

Header(2 bytes) | Cmd(1 byte) | Length(1 byte) | Payload | CRC8(1 byte)

Parsing requirements:

- Validate header
- Validate length
- Verify CRC before processing
- Drop malformed frames safely
- Never assume full frame availability

---

## Output Requirements

When generating code:

- Provide complete implementations
- Include type hints
- Include signal definitions
- Include docstrings
- No pseudocode
- No partial implementation
- No UI-thread blocking logic
- No global state

---

## Prohibited Behaviors

- No mixing UI logic with parsing logic
- No skipping CRC validation
- No using sleep() in UI thread
- No dynamic attribute injection
- No direct transport access from QML

This is production-level motor control software.
Maintain deterministic and modular design at all times.