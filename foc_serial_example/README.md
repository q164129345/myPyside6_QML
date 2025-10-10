# FOC上位机 - 多任务串口通讯架构

## 📌 架构说明

本示例展示了如何在 PySide6 + QML 中实现多个并行周期性任务,特别适合串口通讯场景。

### 🏗️ 任务架构

```
主线程 (UI)
    │
    ├─ [线程1] SerialReceiver - 阻塞式接收串口数据
    │   └─ 持续监听 while loop
    │
    ├─ [线程2] ProtocolParser - 解析通讯协议
    │   └─ 接收原始数据 → 解析 → 发送结构化数据
    │
    └─ [线程3] PeriodicSender - 周期性发送指令
        └─ QTimer 定时触发 (100ms)
```

### ✅ 优势

1. **串口接收独立线程** - 避免阻塞UI
2. **协议解析独立线程** - CPU密集型任务不影响接收
3. **周期发送使用QTimer** - 精确控制发送频率
4. **信号槽通讯** - 线程间安全传递数据
5. **易于扩展** - 可轻松添加更多并行任务

### 📝 实际使用建议

#### 1. 串口接收任务
- 使用 `pyserial` 库
- 阻塞式 `serial.read()` 放在独立线程
- 设置合理的超时时间

```python
import serial
self.serial_port = serial.Serial('COM3', 115200, timeout=0.1)
data = self.serial_port.read(64)  # 最多读64字节
```

#### 2. 协议解析任务
- 维护接收缓冲区
- 逐字节查找帧头
- 校验完整性 (长度、校验和、CRC)
- 解析后发送 dict 或自定义类

#### 3. 周期性任务
- **快速任务** (< 100ms): 独立 QTimer Worker
- **慢速任务** (> 1s): 可合并到一个 Worker
- **关键任务**: 监控执行时间,避免堆积

#### 4. 错误处理
- 串口断开重连机制
- 超时检测
- 异常包丢弃策略

### 🚀 运行方式

```bash
cd foc_serial_example
python main.py
```

### 🔧 集成真实串口

1. 安装依赖:
```bash
pip install pyserial
```

2. 修改 `SerialReceiver.__init__()`:
```python
import serial
self.serial_port = serial.Serial(
    port='COM3',      # Windows: COM3, Linux: /dev/ttyUSB0
    baudrate=115200,
    timeout=0.1
)
```

3. 替换 `_mock_serial_read()` 为真实读取:
```python
data = self.serial_port.read(64)
```

### 📊 性能建议

- **串口波特率**: 115200 或更高
- **接收缓冲区**: 1024 字节起步
- **解析延迟**: < 10ms
- **发送频率**: 根据协议调整 (建议10-100ms)

### ⚠️ 注意事项

1. **线程数量**: 不要超过5个,避免上下文切换开销
2. **信号槽**: 跨线程信号槽是队列连接,有微小延迟
3. **资源释放**: 应用退出前必须调用 `stop_communication()`
4. **UI更新**: 只能在主线程更新QML属性

---

## 🎯 适用场景

✅ FOC电机控制上位机  
✅ 传感器数据采集系统  
✅ 工业设备监控软件  
✅ 多协议网关程序  
✅ 实时数据可视化工具  
