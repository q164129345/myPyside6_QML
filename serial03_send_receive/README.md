# serial03_send_receive - 基础收发数据

## 📚 学习目标

本实例基于 `serial02_open_close` 扩展，添加串口数据收发功能，帮助你掌握：

1. **发送数据** - 使用 `QSerialPort.write()` 发送数据
2. **接收数据** - 监听 `readyRead` 信号接收数据
3. **数据格式转换** - ASCII 和 HEX 格式相互转换
4. **数据显示** - 分别显示发送和接收历史

---

## 🎯 核心知识点

### 1. 发送数据 (write)

```python
# ASCII 文本发送
byte_data = QByteArray(data.encode('utf-8'))
bytes_written = self._serial_port.write(byte_data)
self._serial_port.flush()  # 刷新缓冲区，立即发送

# HEX 格式发送
hex_clean = hex_string.replace(" ", "")  # 去除空格
byte_data = QByteArray.fromHex(hex_clean.encode('ascii'))
self._serial_port.write(byte_data)
```

**要点：**
- `write()` 返回实际写入的字节数（-1 表示失败）
- `flush()` 确保数据立即发送，不在缓冲区滞留
- 发送前需要将字符串转换为 `QByteArray`

### 2. 接收数据 (readyRead 信号)

```python
# 连接信号
self._serial_port.readyRead.connect(self._on_data_ready)

# 读取数据
def _on_data_ready(self):
    byte_data = self._serial_port.readAll()  # 读取所有可用数据
    
    # 转换为 ASCII
    ascii_str = byte_data.data().decode('utf-8', errors='replace')
    
    # 转换为 HEX
    hex_str = byte_data.toHex().data().decode('ascii')
```

**要点：**
- `readyRead` 信号在有数据可读时自动触发
- `readAll()` 读取当前缓冲区的所有数据
- 使用 `errors='replace'` 处理解码错误

### 3. HEX 与 ASCII 转换

```python
# ASCII 转 HEX
byte_data = QByteArray(data.encode('utf-8'))
hex_str = byte_data.toHex().data().decode('ascii')
hex_formatted = ' '.join([hex_str[i:i+2] for i in range(0, len(hex_str), 2)]).upper()

# HEX 转字节数组
hex_clean = "01 02 03 FF".replace(" ", "")
byte_data = QByteArray.fromHex(hex_clean.encode('ascii'))
```

**格式示例：**
- ASCII: `"Hello"` 
- HEX: `48 65 6C 6C 6F`

### 4. 数据验证（HEX 输入）

```python
# 检查是否只包含有效的 HEX 字符
if not all(c in '0123456789ABCDEFabcdef' for c in hex_clean):
    # 无效格式
    
# 检查长度是否为偶数（每个字节由2个HEX字符组成）
if len(hex_clean) % 2 != 0:
    # 长度错误
```

---

## 🖥️ UI 功能说明

### 界面布局

```
┌─────────────────────────────────────────────────┐
│          串口收发数据测试                          │
├──────────────────┬────────────────────────────────┤
│   串口配置       │      连接控制                  │
│  - 选择串口      │    - 连接状态指示灯             │
│  - 波特率        │    - 连接/断开按钮              │
├──────────────────────────────────────────────────┤
│              数据发送                             │
│  格式选择: ○ ASCII  ○ HEX                        │
│  [输入框]                      [📤 发送]          │
├────────────────────┬─────────────────────────────┤
│    发送历史         │      接收历史                │
│  [时间] 📤 发送:... │  [时间] 📥 接收:...         │
│                    │                             │
├────────────────────┴─────────────────────────────┤
│  显示设置: ASCII/HEX  │  系统日志                 │
└──────────────────────────────────────────────────┘
```

### 主要功能

1. **发送格式切换**
   - ASCII 模式：直接发送文本
   - HEX 模式：发送十六进制数据（如 `01 02 03`）

2. **显示格式切换**
   - ASCII 显示：显示可读文本
   - HEX 显示：显示十六进制格式

3. **发送/接收历史**
   - 带时间戳记录
   - 支持清空操作
   - 自动滚动到最新数据

4. **快捷操作**
   - 输入框按回车键快速发送
   - 发送后自动清空输入框

---

## 🚀 使用方法

### 1. 运行程序

```bash
cd serial03_send_receive
python main.py
```

### 2. 连接串口

1. 程序启动后自动扫描串口
2. 选择目标串口和波特率
3. 点击 "🔌 连接" 按钮

### 3. 发送数据

**发送文本（ASCII）：**
1. 选择 "ASCII" 格式
2. 输入文本，如 `Hello World`
3. 点击 "📤 发送" 或按回车键

**发送 HEX 数据：**
1. 选择 "HEX" 格式
2. 输入 HEX 数据，如 `01 02 03 FF`（空格可选）
3. 点击 "📤 发送"

### 4. 接收数据

- 当串口接收到数据时，自动显示在 "接收历史" 区域
- 可通过切换显示格式查看 ASCII 或 HEX 格式

---

## 🧪 测试建议

### 方法 1：使用虚拟串口（推荐）

Windows 用户可以使用虚拟串口工具测试：

1. **安装虚拟串口软件**
   - VSPD (Virtual Serial Port Driver)
   - com0com（免费开源）

2. **创建虚拟串口对**
   - 例如：COM1 ↔ COM2

3. **测试方案**
   - 打开本程序连接 COM1
   - 使用串口调试助手连接 COM2
   - 互相收发数据

### 方法 2：硬件回环测试

如果有真实串口：

1. 将 TX 和 RX 短接（回环）
2. 发送的数据会立即返回
3. 验证收发功能正常

### 方法 3：使用 Arduino

1. Arduino 烧录简单回显程序：
```cpp
void setup() {
  Serial.begin(9600);
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    Serial.write(c);  // 回显
  }
}
```

2. 连接 Arduino 串口
3. 发送数据，Arduino 会回显

---

## 📊 代码对比：serial02 vs serial03

### serial02（打开/关闭）
```python
class SerialBackend:
    def openPort(self, port_name, baud_rate)
    def closePort(self)
```

### serial03（新增收发功能）
```python
class SerialBackend:
    # 继承 serial02 的功能
    def openPort(self, port_name, baud_rate)
    def closePort(self)
    
    # ✨ 新增功能
    def sendData(self, data)           # 发送 ASCII 数据
    def sendHexData(self, hex_string)  # 发送 HEX 数据
    def _on_data_ready(self)           # 接收数据回调
    
    # ✨ 新增信号
    dataReceived = Signal(str, str)    # 接收数据信号
    dataSent = Signal(str, str)        # 发送数据信号
```

---

## 🔍 常见问题

### 1. 发送数据但没有反应？

**原因：**
- 对方设备未连接或未打开
- 波特率不匹配
- TX/RX 线接反

**解决方法：**
- 检查物理连接
- 确认波特率一致
- 使用回环测试验证程序功能

### 2. 接收到乱码？

**原因：**
- 波特率设置不正确
- 数据位/停止位/校验位不匹配
- 传输过程中数据损坏

**解决方法：**
- 统一串口参数配置
- 切换到 HEX 显示查看原始数据

### 3. HEX 发送失败？

**原因：**
- HEX 字符串格式错误
- 包含非法字符（只允许 0-9, A-F）
- 长度不是偶数

**解决方法：**
- 确保格式正确：`01 02 03` 或 `010203`
- 每个字节由 2 个 HEX 字符组成

### 4. 数据丢失或不完整？

**原因：**
- 数据发送过快，缓冲区溢出
- 接收处理不及时

**解决方法：**
- 发送后添加延时
- 下一节 serial04 将学习数据缓冲处理

---

## 📖 下一步学习

完成 serial03 后，你已经掌握了基础的串口收发！

**serial04_hex_conversion** 将深入学习：
- 更复杂的 HEX 数据处理
- 数据格式化和校验
- 数据包的封装与解析

**serial05_auto_response** 将学习：
- 协议解析
- 自动应答机制
- 简单的指令系统

---

## 💡 实践建议

1. **先测试 ASCII 发送**：发送简单文本，观察接收
2. **尝试 HEX 发送**：发送 `48 65 6C 6C 6F`（Hello的HEX）
3. **格式切换**：同一数据用不同格式显示
4. **压力测试**：快速连续发送多条数据
5. **记录观察**：查看系统日志了解底层行为

---

## 📝 技术要点总结

| 功能 | Python 方法 | 说明 |
|------|------------|------|
| 发送数据 | `write(QByteArray)` | 返回写入字节数 |
| 刷新缓冲 | `flush()` | 立即发送数据 |
| 接收信号 | `readyRead` | 有数据可读时触发 |
| 读取数据 | `readAll()` | 读取所有可用数据 |
| 转HEX | `toHex()` | 字节数组转HEX字符串 |
| 从HEX转 | `fromHex()` | HEX字符串转字节数组 |

---

**🎓 学习建议：**
- 理解信号驱动的异步接收机制
- 掌握字节数组与字符串的转换
- 熟悉 HEX 和 ASCII 两种数据表示方式
- 为后续协议解析打下基础
