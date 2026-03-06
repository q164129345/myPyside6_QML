# Architecture
```
                    ┌──────────────────────────┐
                    │           QML UI         │
                    └──────────────┬───────────┘
                                   │
                                   │ Qt Signal / Slot
                                   ▼
                    ┌──────────────────────────┐
                    │       BackendFacade      │
                    │                          │
                    │ UI与系统的唯一入口        │
                    └──────────────┬───────────┘
                                   │
                 ┌─────────────────┼─────────────────┐
                 │                                   │
                 ▼                                   ▼

        ┌─────────────────┐               ┌─────────────────┐
        │    Command      │               │     Service     │
        │                 │               │                 │
        │ motor_command   │               │ frame_dispatch  │
        │                 │               │ data_processor  │
        │ 构造控制命令     │               │ 业务数据处理     │
        └────────┬────────┘               └────────┬────────┘
                 │                                 │
                 ▼                                 ▼
        ┌───────────────────────────────────────────────┐
        │                   Protocol                    │
        │                                               │
        │ frame encode / decode                         │
        │ CRC16                                         │
        │ 粘包处理                                       │
        └─────────────────────────┬─────────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │    Transport    │
                         │                 │
                         │ serial.py       │
                         │                 │
                         │ 串口读写         │
                         └─────────────────┘
```
---

# 数据流（接收路径）
当电机发送一帧数据：
```
MCU
 │
 ▼
Serial Port
 │
 ▼
Transport (serial.py)
 │
 ▼
Protocol.decode()
 │
 ▼
FrameDispatcher
 │
 ▼
DataProcessor
 │
 ▼
BackendFacade
 │
 ▼
QML UI
```

# 控制流（发送命令）
用户点击UI Button，发送控制命令:
```
QML
 │
 ▼
BackendFacade
 │
 ▼
CommandBuilder
 │
 ▼
Protocol.encode()
 │
 ▼
Transport.write()
 │
 ▼
MCU
```
# Layer Interaction Rules

UI → BackendFacade
BackendFacade → Command / Service

Command → Protocol
Service → Protocol
Service → Transport

Protocol → pure functions
Transport → IO only

Forbidden:

UI → Transport
UI → Protocol
Command → Transport
Protocol → QObject
