# Architecture
```
                     ┌──────────────────────────┐
                     │           QML UI         │
                     │                          │
                     │  Main.qml                │
                     │  SYS.qml                 │
                     │  CAN.qml                 │
                     │                          │
                     │  用户操作:               │
                     │  - 选择串口               │
                     │  - 点击连接               │
                     │  - 发送电机控制命令        │
                     │                          │
                     └──────────────┬───────────┘
                                    │
                                    │ Qt Slot / Signal
                                    │
                                    ▼
                     ┌──────────────────────────┐
                     │      BackendFacade       │
                     │                          │
                     │  系统控制中心             │
                     │                          │
                     │  职责:                   │
                     │  - 创建 backend 对象      │
                     │  - 建立信号连接           │
                     │  - 向 UI 暴露接口         │
                     │                          │
                     │  API:                    │
                     │  connectSerial()         │
                     │  disconnectSerial()      │
                     │  sendMotorCommand()      │
                     │                          │
                     └──────────────┬───────────┘
                                    │
                    Qt Signals      │
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
            ▼                       ▼                       ▼

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Transport      │     │    Service       │     │     Protocol     │
│                  │     │                  │     │                  │
│   mySerial       │     │  DataProcessor   │     │  protocol_frame  │
│                  │     │                  │     │                  │
│  职责:           │     │ 职责:            │     │ 职责:            │
│  串口读写        │     │ buffer管理       │     │ 帧编码           │
│                  │     │ 协议解析调度     │     │ CRC16            │
│  QSerialPort     │     │                  │     │                  │
│                  │     │ 状态管理         │     │ 纯函数           │
│ emit:            │     │ emit:            │     │ 无状态           │
│ dataReceived     │────►│ telemetryUpdated │     │ 无QObject        │
│                  │     │ faultUpdated     │     │                  │
│                  │     │                  │     │ decode()         │
└──────────────────┘     └─────────┬────────┘     └──────────────────┘
                                   │
                                   │
                                   ▼
                         ┌──────────────────┐
                         │      QML UI      │
                         │                  │
                         │  实时数据展示     │
                         │                  │
                         │  - 转速           │
                         │  - 电流           │
                         │  - 温度           │
                         │  - 状态           │
                         │                  │
                         └──────────────────┘
```
---

# 数据流（接收路径）
当电机发送一帧数据：
```
FOC Motor Controller
        │
        ▼
Serial Port
        │
        ▼
Transport (mySerial)
        │
        │ emit dataReceived(bytes)
        ▼
Service (DataProcessor)
        │
        │ append buffer
        │ parse frame
        ▼
Protocol (pure function)
        │
        ▼
Service emit telemetryUpdated
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
Protocol.encode()
  │
  ▼
Transport.write()
  │
  ▼
Serial Port
  │
  ▼
FOC Controller
```
# Layer Interaction Rules

UI → BackendFacade
BackendFacade → Service
Service → Protocol
Service → Transport

Forbidden:

UI → Transport
Transport → Service method calls
Protocol → any QObject
