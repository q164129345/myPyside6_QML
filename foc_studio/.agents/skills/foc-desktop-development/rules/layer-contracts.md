# Layer Contracts（各层约束）

---

# 1 - Protocol Layer（协议层）

Location:
core.protocol.protocol_frame

Frame format (already defined):
head1 head2 cmd datalen data[] crc16_h crc16_l
0xAA  0xBB  1B  1B      N     1B      1B

CRC:
- CRC16-MODBUS
- Polynomial: 0x8005
- Initial: 0xFFFF
- Big-endian storage

Rules:
- All protocol functions must be pure（纯函数）
- No QObject usage（不依赖Qt特性）
- No state（无状态）
- No buffer ownership（不拥有缓冲区）
- No side effects（无副作用）
- CRC must be verified before accepting frame（必须验证CRC）
- Must support incremental parsing（必须支持增量解析,适应粘包和半包）

It is strictly responsible for:
1. Frame construction (encode)
2. attempt_parse_frame(data: bytes)

The protocol layer MUST NOT:
- Store or manage buffers
- Maintain state
- Implement retry logic
- Perform business logic dispatch
- Access UI
- Access transport
- Raise runtime exceptions for malformed data
All functions must be pure and side-effect free.

---

# 2 - Transport Layer（传输层）

Location:
core.transport.serial.mySerial

Characteristics:
- Uses QSerialPort（使用 QSerialPort，串口通讯时）
- Emits: dataReceived(bytes)（发出：dataReceived(bytes)）
- No protocol parsing（不进行协议解析）
- No business logic（不进行业务逻辑处理）
- Lightweight only（仅轻量级）
Transport is byte carrier only.（传输层仅负责字节传输）

Never move parsing logic into transport.（切勿将解析逻辑移动到传输层）

---

# 3 - Service Layer（服务层）

Location:
core.service.data_processor.DataProcessor

Responsibilities:（责任）
- Maintain persistent bytearray buffer（持久化字节数组缓冲区）
- Append incoming bytes（追加接收字节）
- Call protocol parsing function（调用协议解析函数）
- Handle:（处理）
    - valid frame（有效帧）
    - discardable bytes（可丢弃字节）
    - insufficient data（数据不足）
- Remove consumed bytes safely（安全移除已消耗字节）
- Dispatch parsed data via Qt signals（通过 Qt 信号分发解析后的数据）

Service layer is:
- Stateful（有状态）
- Deterministic（确定性）
- Thread-safe (UI thread safe, no blocking)（线程安全，UI 线程安全，无阻塞）
- Business logic only（仅业务逻辑）
- Signal provider for UI（UI数据提供者）
- State manager（状态管理者）

Service layer must NOT:
- Direct function calls are prohibited between them（之间禁止直接函数调用）
   - Use: Service -> BackendFacade -> Service
- Perform blocking operations（执行阻塞操作）
- Modify transport logic（修改传输逻辑）

---

# 4 - Data Processing Strategy（数据处理策略）

When implementing receive logic:
1. Maintain:
   self._buffer: bytearray

2. On dataReceived(bytes):
   - append to buffer
   - loop:
       - try parse_frame_from_buffer()
       - if frame valid:
             process frame
             remove consumed bytes
       - if insufficient data:
             break
       - if invalid header:
             discard one byte and continue

Never assume full frame arrives in one read.（切勿假设完整帧在一次读取中到达）

Must support:
- Sticky packets（粘包）
- Partial packets（半包）
- Multiple frames in one read（一次读取多个帧）
