# PC-MCU Communication Protocol

This document defines the communication protocol
between the PC desktop application (FOC Studio)
and the MCU controller.  
  
Transport: Serial (UART)  
Frame format: Custom binary protocol  
CRC: CRC16-MODBUS
Byte order：Big Endian

---

# 1 Frame Format

| Field | Size | Description |
|------|------|-------------|
| Head1 | 1 byte | 0xAA |
| Head2 | 1 byte | 0xBB |
| CMD | 1 byte | Command ID |
| LEN | 1 byte | Payload length |
| DATA | N bytes | Payload |
| CRC_H | 1 byte | CRC16 high |
| CRC_L | 1 byte | CRC16 low |

CRC range: CMD + LEN + DATA  
CRC algorithm: CRC16-MODBUS  

---

# 2 Command List

## PC -> MCU

### CMD 0x01 - Motor Control
Direction: PC → MCU  
Description:  控制电机使能状态和目标转速。  
Frequence: 500ms/次  
Note: MCU在2S内收不到指令，会自动让电机停下来。  

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8 | 电机使能位：0 = 松轴，1 = 使能 |
| 1 | 2 | int16 | 目标转速 (rpm) |
| **DATA_LEN** | 3 |  |  |

## MCU -> PC

### CMD 0x64 - Speed Feedback
Direction: MCU → PC  
Description:  反馈电机当前的转速
Frequence: 50ms/次
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16 | 当前转速 (rpm) |
| **DATA_LEN** | 2 |  |  |








---
