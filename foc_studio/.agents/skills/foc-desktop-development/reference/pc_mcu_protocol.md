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

### CMD 0x02 - PC Heartbeat
Direction: PC → MCU
Description: PC在线心跳，用于维持MCU向PC发送数据的状态。
Frequence: 1000ms/次
Timeout: MCU在5秒内未收到该命令，将停止发送所有MCU→PC的数据帧。
Note:该命令 没有DATA,仅用于保持连接,MCU收到就刷新计时器。
| Offset       | Size | Type | Description |
| ------------ | ---- | ---- | ----------- |
| **DATA_LEN** | 0    |      | 无payload    |


### CMD 0x03 - Query Software Version
Direction: PC -> MCU
Description: PC actively queries the MCU software version.
Frequence: On demand (recommended once after connection; manual re-query is allowed)
Note:
- MCU must not upload software version periodically; only respond after CMD 0x03.
- No DATA payload.

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | No payload |

### CMD 0x04 - Query Motor Type
Direction: PC → MCU  
Description: PC queries the motor type configured in the MCU firmware.  
Frequence: 1000ms/次，仅在 PC 侧电机类型 == 0（未知）时轮询；获取到有效类型后停止查询。  
Note:
- MCU 总是立即响应，不依赖心跳在线状态。
- No DATA payload.
- PC 侧行为：连接初始化时电机类型置 0；串口断开时电机类型重置为 0；每 1S 发一次，直到收到 CMD 0x6D 且类型 ≠ 0 为止。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | No payload |

### CMD 0x05 - Query Speed Loop Params
Direction: PC → MCU
Description: PC 查询速度环 PID 参数。
Frequence: On demand
Note:
- MCU 收到后立即以 CMD 0x6E 响应。
- 由 `TUNE` 页的“读取参数”按钮触发，也会在 UI 从其他页面切换到 `TUNE` 时触发。
- PC 侧会将 CMD 0x05、CMD 0x06 与 CMD 0x0B 作为一组刷新动作连续发送。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x06 - Query Current Loop Params
Direction: PC → MCU
Description: PC 查询电流环 PID 参数。
Frequence: On demand
Note:
- MCU 收到后立即以 CMD 0x6F 响应。
- 由 `TUNE` 页的“读取参数”按钮触发，也会在 UI 从其他页面切换到 `TUNE` 时触发。
- PC 侧会将 CMD 0x05、CMD 0x06 与 CMD 0x0B 作为一组刷新动作连续发送。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x07 - Set Speed Loop Params
Direction: PC → MCU
Description: PC 设置速度环 PID 参数。
Frequence: On demand
Note:
- payload 固定 16 字节，参数顺序：kp → ki → kd → tf。
- PC 侧编码：`raw = round(value × 1000000)`，打包为 int32 Big Endian 发送。
- MCU 侧解码：`value = raw / 1000000.0f`。
- tf 单位为秒。
- PC 不等待单独的写入应答帧；发送完 CMD 0x07、CMD 0x08 与 CMD 0x0C 后，会立即再发 CMD 0x05、CMD 0x06 和 CMD 0x0B 读回校验。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | kp（×1000000 编码） |
| 4 | 4 | int32 | ki（×1000000 编码） |
| 8 | 4 | int32 | kd（×1000000 编码） |
| 12 | 4 | int32 | tf，单位秒（×1000000 编码） |
| **DATA_LEN** | 16 |  |  |

### CMD 0x08 - Set Current Loop Params
Direction: PC → MCU
Description: PC 设置电流环 PID 参数。
Frequence: On demand
Note:
- payload 固定 16 字节，参数顺序：kp → ki → kd → tf。
- PC 侧编码：`raw = round(value × 1000000)`，打包为 int32 Big Endian 发送。
- MCU 侧解码：`value = raw / 1000000.0f`。
- tf 单位为秒。
- PC 不等待单独的写入应答帧；发送完 CMD 0x07、CMD 0x08 与 CMD 0x0C 后，会立即再发 CMD 0x05、CMD 0x06 和 CMD 0x0B 读回校验。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | kp（×1000000 编码） |
| 4 | 4 | int32 | ki（×1000000 编码） |
| 8 | 4 | int32 | kd（×1000000 编码） |
| 12 | 4 | int32 | tf，单位秒（×1000000 编码） |
| **DATA_LEN** | 16 |  |  |

### CMD 0x09 - Save Current PID Params To Flash
Direction: PC -> MCU
Description: PC 命令 MCU 将当前正在运行的 PID 参数写入 FLASH。
Frequence: 按需
Note:
- 无 DATA payload。
- 该命令保存的是 MCU 当前已经生效的 PID 参数，不是 UI 中尚未应用的草稿值。
- MCU 完成 FLASH 保存后，应以 CMD 0x70 返回保存结果。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x0A - Reboot MCU
Direction: PC → MCU
Description: PC 命令 MCU 执行软件复位重启。
Frequence: 按需
Note:
- 无 DATA payload。
- MCU 收到该命令后，应先以 CMD 0x71 回传确认帧，再执行软件复位（确保 PC 侧能感知到重启动作）。
- PC 侧收到 CMD 0x71 后，应将连接状态重置为"未连接"，并等待串口重新上线。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x0B - Query Motor Limits
Direction: PC → MCU
Description: PC 查询电机的 voltage_limit 与 current_limit 参数。
Frequence: 按需
Note:
- 无 DATA payload。
- MCU 收到后立即以 CMD 0x72 响应。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x0C - Set Motor Limits
Direction: PC → MCU
Description: PC 设置电机的 voltage_limit 与 current_limit 参数。
Frequence: 按需
Note:
- payload 固定 8 字节，参数顺序：voltage_limit → current_limit。
- PC 侧编码：`raw = round(value × 1000000)`，打包为 int32 Big Endian 发送。
- MCU 侧解码：`value = raw / 1000000.0f`。
- PC 不等待单独的写入应答帧；发送完 CMD 0x0C 后，会立即再发 CMD 0x0B 读回校验。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | voltage_limit（×1000000 编码） |
| 4 | 4 | int32 | current_limit（×1000000 编码） |
| **DATA_LEN** | 8 |  |  |

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
| **DATA_LEN** | 1 |  |  |

### CMD 0x68 - Software Version Response
Direction: MCU -> PC
Description: Response frame for CMD 0x03 software version query.
Frequence: Passive response only (send only after receiving CMD 0x03)
Note:
- MCU must not proactively upload this frame.
- Version format: main.sub.mini.fixed

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8 | mainVersion |
| 1 | 1 | uint8 | subVersion |
| 2 | 1 | uint8 | miniVersion |
| 3 | 1 | uint8 | fixed/Revision |
| **DATA_LEN** | 4 |  |  |

### CMD 0x69 - Iq、Id与Uq、Ud
Direction: MCU → PC  
Description:  Iq分量、Id分量、Uq分量、Ud分量
Frequence: 50ms/次
Note: 
- SimpleFOC源码的FOCMotor.current变量与FOCMotor.voltage变量
- Iq、Id、Uq、Ud都是float类型，协议是int16_t变量(-32768 ~ 32768)。变量类型转换：float变量 * 1000 -> int16变量
| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16_t | Iq电流分量 |
| 2 | 2 | int16_t | Id电流分量 |
| 4 | 2 | int16_t | Uq电压分量 |
| 6 | 2 | int16_t | Ud电压分量 |
| **DATA_LEN** | 8 |  |  |

### CMD 0x6A - Motor Current
Direction: MCU → PC  
Description:  电机实时的电流值(单位0.001A)  
Frequence: 50ms/次  
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16_t | 电流值 |
| **DATA_LEN** | 2 |  |  |

### CMD 0x6C - Error Code
Direction: MCU → PC  
Description:  错误码
Frequence: 1000ms/次  
Note: 

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | uint16_t | 错误码 |
| **DATA_LEN** | 2 |  |  |

### CMD 0x6D - Motor Type Response
Direction: MCU → PC  
Description: 响应 PC 的 CMD 0x04 电机类型查询，返回 MCU 固件中编译的电机类型。  
Frequence: 被动响应（仅在收到 CMD 0x04 后发送，不主动上报）  
Note:
- 电机类型值与固件宏 `MOTOR_TYPE` 一致：1=边刷(中菱)，2=滚刷，3=新边刷(11050)，4=中菱轮毂电机，5=割刀电机。
- MCU 总是立即响应，不依赖心跳在线状态。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8_t | 电机类型（1~5） |
| **DATA_LEN** | 1 |  |  |

### CMD 0x6E - Speed Loop Params Response
Direction: MCU → PC
Description: 响应 CMD 0x05，返回速度环 PID 参数。
Frequence: 被动响应（仅在收到 CMD 0x05 后发送，不主动上报）
Note:
- payload 固定 16 字节，参数顺序：kp → ki → kd → tf。
- MCU 侧编码：`raw = (int32_t)roundf(value × 1000000)`，打包为 int32 Big Endian 发送。
- PC 侧解码：`value = raw / 1000000.0`。
- tf 单位为秒。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | kp（÷1000000 解码） |
| 4 | 4 | int32 | ki（÷1000000 解码） |
| 8 | 4 | int32 | kd（÷1000000 解码） |
| 12 | 4 | int32 | tf，单位秒（÷1000000 解码） |
| **DATA_LEN** | 16 |  |  |

### CMD 0x6F - Current Loop Params Response
Direction: MCU → PC
Description: 响应 CMD 0x06，返回电流环 PID 参数。
Frequence: 被动响应（仅在收到 CMD 0x06 后发送，不主动上报）
Note:
- payload 固定 16 字节，参数顺序：kp → ki → kd → tf。
- MCU 侧编码：`raw = (int32_t)roundf(value × 1000000)`，打包为 int32 Big Endian 发送。
- PC 侧解码：`value = raw / 1000000.0`。
- tf 单位为秒。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | kp（÷1000000 解码） |
| 4 | 4 | int32 | ki（÷1000000 解码） |
| 8 | 4 | int32 | kd（÷1000000 解码） |
| 12 | 4 | int32 | tf，单位秒（÷1000000 解码） |
| **DATA_LEN** | 16 |  |  |

### CMD 0x70 - Save PID Params Result
Direction: MCU -> PC
Description: 响应 CMD 0x09，返回 PID 参数写入 FLASH 的结果。
Frequence: 被动响应（仅在收到 CMD 0x09 后发送，不主动上报）
Note:
- `status = 0x00` 表示保存成功。
- `status = 0x01` 表示保存失败。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8 | status |
| **DATA_LEN** | 1 |  |  |

### CMD 0x71 - Reboot MCU Acknowledgement
Direction: MCU → PC
Description: 响应 CMD 0x0A，MCU 在执行软件复位前通知 PC 已收到重启指令。
Frequence: 被动响应（仅在收到 CMD 0x0A 后发送，不主动上报）
Note:
- 无 DATA payload。
- MCU 发送本帧后立即执行软件复位，PC 侧收到后应将连接状态重置为"未连接"。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x72 - Motor Limits Response
Direction: MCU → PC
Description: 响应 CMD 0x0B，返回电机的 voltage_limit 与 current_limit 参数。
Frequence: 被动响应（仅在收到 CMD 0x0B 后发送，不主动上报）
Note:
- payload 固定 8 字节，参数顺序：voltage_limit → current_limit。
- MCU 侧编码：`raw = (int32_t)roundf(value × 1000000)`，打包为 int32 Big Endian 发送。
- PC 侧解码：`value = raw / 1000000.0`。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | voltage_limit（÷1000000 解码） |
| 4 | 4 | int32 | current_limit（÷1000000 解码） |
| **DATA_LEN** | 8 |  |  |


---
