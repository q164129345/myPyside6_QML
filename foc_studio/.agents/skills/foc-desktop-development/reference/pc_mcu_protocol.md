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
- MCU 响应（CMD 0x6F）包含 Iq（q 轴/转矩环）与 Id（d 轴/磁场环）两组独立 PID 参数（共 40 字节），二者已解耦，分别对应 `motor->PID_current_q`/`LPF_current_q` 与 `motor->PID_current_d`/`LPF_current_d`。
- 由 `TUNE` 页的”读取参数”按钮触发，也会在 UI 从其他页面切换到 `TUNE` 时触发。
- PC 侧会将 CMD 0x05、CMD 0x06 与 CMD 0x0B 作为一组刷新动作连续发送。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x07 - Set Speed Loop Params
Direction: PC → MCU
Description: PC 设置速度环 PID 参数。
Frequence: On demand
Note:
- payload 固定 20 字节，参数顺序：kp → ki → kd → ramp → tf。
- PC 侧编码：`raw = round(value × 1000000)`，打包为 int32 Big Endian 发送。
- MCU 侧解码：`value = raw / 1000000.0f`。
- ramp 单位为输出值/秒（output_ramp），tf 单位为秒。
- PC 不等待单独的写入应答帧；发送完 CMD 0x07、CMD 0x08 与 CMD 0x0C 后，会立即再发 CMD 0x05、CMD 0x06 和 CMD 0x0B 读回校验。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | kp（×1000000 编码） |
| 4 | 4 | int32 | ki（×1000000 编码） |
| 8 | 4 | int32 | kd（×1000000 编码） |
| 12 | 4 | int32 | ramp，output_ramp（×1000000 编码） |
| 16 | 4 | int32 | tf，单位秒（×1000000 编码） |
| **DATA_LEN** | 20 |  |  |

### CMD 0x08 - Set Current Loop Params
Direction: PC → MCU
Description: PC 设置电流环 PID 参数（Iq 与 Id 两组参数各自独立设置，互不耦合）。
Frequence: On demand
Note:
- payload 固定 40 字节，分为两组，每组 20 字节，组内参数顺序均为：kp → ki → kd → ramp → tf；第一组对应 Iq（q 轴/转矩环），第二组对应 Id（d 轴/磁场环），二者完全独立、互不影响。
- PC 侧编码：`raw = round(value × 1000000)`，打包为 int32 Big Endian 发送。
- MCU 侧解码：`value = raw / 1000000.0f`，第一组写入 `motor->PID_current_q`/`LPF_current_q`，第二组写入 `motor->PID_current_d`/`LPF_current_d`。
- ramp 单位为输出值/秒（output_ramp），tf 单位为秒。
- PC 不等待单独的写入应答帧；发送完 CMD 0x07、CMD 0x08 与 CMD 0x0C 后，会立即再发 CMD 0x05、CMD 0x06 和 CMD 0x0B 读回校验。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | Iq（q 轴/转矩环）kp（×1000000 编码） |
| 4 | 4 | int32 | Iq（q 轴/转矩环）ki（×1000000 编码） |
| 8 | 4 | int32 | Iq（q 轴/转矩环）kd（×1000000 编码） |
| 12 | 4 | int32 | Iq（q 轴/转矩环）ramp，output_ramp（×1000000 编码） |
| 16 | 4 | int32 | Iq（q 轴/转矩环）tf，单位秒（×1000000 编码） |
| 20 | 4 | int32 | Id（d 轴/磁场环）kp（×1000000 编码） |
| 24 | 4 | int32 | Id（d 轴/磁场环）ki（×1000000 编码） |
| 28 | 4 | int32 | Id（d 轴/磁场环）kd（×1000000 编码） |
| 32 | 4 | int32 | Id（d 轴/磁场环）ramp，output_ramp（×1000000 编码） |
| 36 | 4 | int32 | Id（d 轴/磁场环）tf，单位秒（×1000000 编码） |
| **DATA_LEN** | 40 |  |  |

### CMD 0x0A - Reboot MCU
Direction: PC → MCU
Description: PC 命令 MCU 执行软件复位重启。
Frequence: 按需
Note:
- 无 DATA payload。
- MCU 收到该命令后，立即重启（比如：NVIC_SystemReset()或HAL_NVIC_SystemReset()）

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

### CMD 0x0D - Query DIP Switch ID
Direction: PC → MCU
Description: PC 查询 MCU 的拨码开关 ID。
Frequence: 按需
Note:
- 无 DATA payload。
- MCU 收到后立即以 CMD 0x71 响应。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

### CMD 0x0E - Query External Flash ID
Direction: PC → MCU
Description: PC 查询外部 Flash 的 Manufacturer ID 与 Device ID（JEDEC ID）。
Frequence: 按需
Note:
- 无 DATA payload。
- MCU 收到后立即以 CMD 0x76 响应。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| **DATA_LEN** | 0 |  | 无 payload |

## MCU -> PC

### CMD 0x64 - Speed Feedback
Direction: MCU → PC  
Description:  反馈电机当前的转速（单位rpm）  
Frequence: 50ms/次
Note:
- `tick_ms`：MCU 调用 `HAL_GetTick()` 获取的采集时刻，单位毫秒，Big Endian uint32。
- PC 侧时钟对齐：首帧记录 `pc_mcu_offset = Date.now() - tick_ms`，后续样本 `pc_timestamp = tick_ms + pc_mcu_offset`，以还原真实采集间隔，消除 DMA 批量发送导致的时间戳堆叠问题。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16 | 当前转速 (rpm) |
| 2 | 4 | uint32_t | HAL_GetTick() (ms) |
| **DATA_LEN** | 6 |  |  |

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
- `tick_ms`：MCU 调用 `HAL_GetTick()` 获取的采集时刻，单位毫秒，Big Endian uint32。
- PC 侧时钟对齐：首帧记录 `pc_mcu_offset = Date.now() - tick_ms`，后续样本 `pc_timestamp = tick_ms + pc_mcu_offset`，以还原真实采集间隔，消除 DMA 批量发送导致的时间戳堆叠问题。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16_t | Iq电流分量 |
| 2 | 2 | int16_t | Id电流分量 |
| 4 | 2 | int16_t | Uq电压分量 |
| 6 | 2 | int16_t | Ud电压分量 |
| 8 | 4 | uint32_t | HAL_GetTick() (ms) |
| **DATA_LEN** | 12 |  |  |

### CMD 0x6A - Motor Current
Direction: MCU → PC  
Description:  电机实时的电流值(单位0.001A)  
Frequence: 50ms/次  
Note:
- `tick_ms`：MCU 调用 `HAL_GetTick()` 获取的采集时刻，单位毫秒，Big Endian uint32。
- PC 侧时钟对齐：首帧记录 `pc_mcu_offset = Date.now() - tick_ms`，后续样本 `pc_timestamp = tick_ms + pc_mcu_offset`，以还原真实采集间隔，消除 DMA 批量发送导致的时间戳堆叠问题。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 2 | int16_t | 电流值 |
| 2 | 4 | uint32_t | HAL_GetTick() (ms) |
| **DATA_LEN** | 6 |  |  |

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
- 电机类型值与固件宏 `MOTOR_TYPE` 一致：1=边刷(中菱)，2=滚刷，3=新边刷(11050)，4=中菱轮毂电机，5=0.8N割刀电机，6=frx_0.4N割刀电机。
- MCU 总是立即响应，不依赖心跳在线状态。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8_t | 电机类型（1~6） |
| **DATA_LEN** | 1 |  |  |

### CMD 0x6E - Speed Loop Params Response
Direction: MCU → PC
Description: 响应 CMD 0x05，返回速度环 PID 参数。
Frequence: 被动响应（仅在收到 CMD 0x05 后发送，不主动上报）
Note:
- payload 固定 20 字节，参数顺序：kp → ki → kd → ramp → tf。
- MCU 侧编码：`raw = (int32_t)roundf(value × 1000000)`，打包为 int32 Big Endian 发送。
- PC 侧解码：`value = raw / 1000000.0`。
- ramp 单位为输出值/秒（output_ramp），tf 单位为秒。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | kp（÷1000000 解码） |
| 4 | 4 | int32 | ki（÷1000000 解码） |
| 8 | 4 | int32 | kd（÷1000000 解码） |
| 12 | 4 | int32 | ramp，output_ramp（÷1000000 解码） |
| 16 | 4 | int32 | tf，单位秒（÷1000000 解码） |
| **DATA_LEN** | 20 |  |  |

### CMD 0x6F - Current Loop Params Response
Direction: MCU → PC
Description: 响应 CMD 0x06，返回电流环 PID 参数（Iq 与 Id 两组独立参数）。
Frequence: 被动响应（仅在收到 CMD 0x06 后发送，不主动上报）
Note:
- payload 固定 40 字节，分为两组，每组 20 字节，组内参数顺序均为：kp → ki → kd → ramp → tf；第一组为 Iq（q 轴/转矩环，对应 `motor->PID_current_q`/`LPF_current_q`），第二组为 Id（d 轴/磁场环，对应 `motor->PID_current_d`/`LPF_current_d`），二者完全独立。
- MCU 侧编码：`raw = (int32_t)roundf(value × 1000000)`，打包为 int32 Big Endian 发送。
- PC 侧解码：`value = raw / 1000000.0`。
- ramp 单位为输出值/秒（output_ramp），tf 单位为秒。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | int32 | Iq（q 轴/转矩环）kp（÷1000000 解码） |
| 4 | 4 | int32 | Iq（q 轴/转矩环）ki（÷1000000 解码） |
| 8 | 4 | int32 | Iq（q 轴/转矩环）kd（÷1000000 解码） |
| 12 | 4 | int32 | Iq（q 轴/转矩环）ramp，output_ramp（÷1000000 解码） |
| 16 | 4 | int32 | Iq（q 轴/转矩环）tf，单位秒（÷1000000 解码） |
| 20 | 4 | int32 | Id（d 轴/磁场环）kp（÷1000000 解码） |
| 24 | 4 | int32 | Id（d 轴/磁场环）ki（÷1000000 解码） |
| 28 | 4 | int32 | Id（d 轴/磁场环）kd（÷1000000 解码） |
| 32 | 4 | int32 | Id（d 轴/磁场环）ramp，output_ramp（÷1000000 解码） |
| 36 | 4 | int32 | Id（d 轴/磁场环）tf，单位秒（÷1000000 解码） |
| **DATA_LEN** | 40 |  |  |

### CMD 0x71 - DIP Switch ID Response
Direction: MCU → PC
Description: 响应 CMD 0x0D，返回 MCU 的拨码开关 ID。
Frequence: 被动响应（仅在收到 CMD 0x0D 后发送，不主动上报）
Note:
- payload 固定 1 字节，为拨码开关当前读取到的 ID 值。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8_t | 拨码开关 ID（0~255） |
| **DATA_LEN** | 1 |  |  |

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

### CMD 0x73 - Log Message
Direction: MCU → PC  
Description: MCU 主动上传日志消息（INFO / WARN / ERROR），供上位机显示调试信息。  
Frequence: 按需（仅在 `DEBUG_LOG_ENABLE=1` 且 `LOG_PRINT_TO_USARTX=2` 时触发）  
Note:
- 由 `LOG_INFO` / `LOG_WARN` / `LOG_ERROR` 宏触发，格式化后通过协议帧发送。
- Message 字段为 ASCII 字符串，不含 `\r\n`，不含 null 终止符。
- Message 最长 254 字节，LEN 最大 255（Level 1 字节 + Message 254 字节）。
- Level 枚举：0 = INFO，1 = WARN，2 = ERROR。
- PC 侧建议按 Level 用不同颜色显示。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8 | Level（0=INFO，1=WARN，2=ERROR） |
| 1 | N | char[] | Message 字符串（ASCII，无终止符） |
| **DATA_LEN** | 1+N |  | N = strlen(message)，最大 254 |

### CMD 0x74 - Hall Sensor State
Direction: MCU → PC
Description: 上报霍尔传感器三路原始信号、hall_state 及当前电气扇区，用于调试诊断。
Frequence: 50ms/次
Note:
- Hall A/B/C 各为 0 或 1，表示对应霍尔引脚的当前电平。
- hall_state 编码：`hall_state = C + (B << 1) + (A << 2)`，取值范围 0~7，其中 1~6 有效，0 和 7 表示无效。
- electric_sector 有效范围 0~5，-1 表示无效（hall_state=0 或 7 时）。
- 仅当电机传感器为霍尔传感器（`motor->sensor->IsHallSensor() == true`）时才上传，与 `Motor_Type` 无关。
- `tick_ms`：MCU 调用 `HAL_GetTick()` 获取的采集时刻，单位毫秒，Big Endian uint32。
- PC 侧时钟对齐：首帧记录 `pc_mcu_offset = Date.now() - tick_ms`，后续样本 `pc_timestamp = tick_ms + pc_mcu_offset`，以还原真实采集间隔，消除 DMA 批量发送导致的时间戳堆叠问题。

| Offset | Size | Type  | Description                          |
|--------|------|-------|--------------------------------------|
| 0      | 1    | uint8 | Hall A（0 或 1）                     |
| 1      | 1    | uint8 | Hall B（0 或 1）                     |
| 2      | 1    | uint8 | Hall C（0 或 1）                     |
| 3      | 1    | uint8 | hall_state（0~7，其中 1~6 有效，0/7 表示无效） |
| 4      | 1    | int8  | electric_sector（0~5，-1 表示无效）  |
| 5      | 4    | uint32_t | HAL_GetTick() (ms)               |
| **DATA_LEN** | 9 |  |                                 |

### CMD 0x75 - Absolute Sensor Info
Direction: MCU → PC
Description: 上报绝对值编码器当前单圈原始计数值与单圈分辨率，用于调试诊断。
Frequence: 100ms/次
Note:
- `pulse_counter` 对应 `AbsoluteEncoder485::getRawCount()`，表示当前单圈位置，不做角度换算。
- `pulse_counter` 正常范围为 `0 ~ cpr - 1`。
- `cpr` 表示一圈对应的总计数（counts per revolution），例如 16bit 编码器可为 `65536`，17bit 编码器可为 `131072`。
- PC 侧可用 `angle_rad = pulse_counter / cpr * 2π` 计算机械角度。
- 仅当电机传感器为绝对值编码器 485（`motor->sensor->IsAbsoluteEncoder485() == true`）时才上传。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 4 | uint32_t | pulse_counter，绝对值编码器单圈原始计数值 |
| 4 | 4 | uint32_t | cpr，counts per revolution，单圈计数总数 |
| **DATA_LEN** | 8 |  |  |

### CMD 0x76 - External Flash ID Response
Direction: MCU → PC
Description: 响应 CMD 0x0E，返回外部 Flash 的 Manufacturer ID 与 Device ID（JEDEC ID）。
Frequence: 被动响应（仅在收到 CMD 0x0E 后发送，不主动上报）
Note:
- payload 固定 2 字节。
- Manufacturer ID：厂商标识，例如 Winbond = 0xEF。
- Device ID：设备标识，例如 W25Q128 = 0x17。

| Offset | Size | Type | Description |
|------|------|------|-------------|
| 0 | 1 | uint8_t | Manufacturer ID |
| 1 | 1 | uint8_t | Device ID |
| **DATA_LEN** | 2 |  |  |


---
