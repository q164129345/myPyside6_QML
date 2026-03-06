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

CRC range: CMD + LEN + DATA（注意：Head1、Head2不参与CRC运算）  
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
Description:  反馈电机当前的转速（单位rpm）  
Frequence: 50ms/次
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16 | 当前转速 (rpm) |
| **DATA_LEN** | 2 |  |  |

### CMD 0x65 - Motor Temperature
Direction: MCU → PC  
Description:  反馈电机的实时温度(单位0.1℃)  
Frequence: 1000ms/次
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16 | 当前温度 (单位0.1℃) |
| **DATA_LEN** | 2 |  |  |

### CMD 0x66 - MOS Temperature
Direction: MCU → PC  
Description:  反馈板子MOS的实时温度(单位0.1℃)  
Frequence: 1000ms/次
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16 | 当前温度 (单位0.1℃) |
| **DATA_LEN** | 2 |  |  |

### CMD 0x67 - Motor Enable State
Direction: MCU → PC  
Description:  反馈电机的使能状态  
Frequence: 1000ms/次
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8_t | 使能状态（0：未使能，1：使能） |
| **DATA_LEN** | 2 |  |  |

### CMD 0x68 - Error Code(错误码)
Direction: MCU → PC  
Description:  错误码
Frequence: 1000ms/次  
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | uint16_t | 错误码 |
| **DATA_LEN** | 2 |  |  |

### CMD 0x69 - Iq、Id（Iq、Id电流分量）
Direction: MCU → PC  
Description:  Iq分量、Id分量  
Frequence: 50ms/次
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16_t | Iq电流分量 |
| 2 | 2 | int16_t | Id电流分量 |
| **DATA_LEN** | 4 |  |  |

### CMD 0x6A - Motor Current
Direction: MCU → PC  
Description:  电机实时的电流值(单位0.1A)  
Frequence: 50ms/次  
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16_t | 电流值 |
| **DATA_LEN** | 2 |  |  |




---
