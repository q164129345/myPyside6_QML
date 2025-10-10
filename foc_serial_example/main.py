# python3.10.11 - PySide6==6.9
"""
FOC上位机 - 多任务串口通讯架构示例
包含:串口接收、周期发送、协议解析、状态监控
"""
import sys
import time
import threading
from PySide6.QtCore import QObject, Signal, Slot, QThread, QTimer, Property
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


# ========== 1. 串口接收 Worker ==========
class SerialReceiver(QObject):
    """持续监听串口数据"""
    dataReceived = Signal(bytes)  # 原始字节数据
    errorOccurred = Signal(str)   # 错误信息
    
    def __init__(self):
        super().__init__()
        self.running = False
        self.serial_port = None  # 这里需要替换为实际的 serial.Serial 对象
        
    @Slot()
    def start_receiving(self):
        """在独立线程中持续接收数据"""
        self.running = True
        print(f"[SerialReceiver] 启动接收线程: {threading.get_ident()}")
        
        while self.running:
            try:
                # 模拟串口读取 (实际使用: data = self.serial_port.read(size))
                # data = self.serial_port.read(64)
                data = self._mock_serial_read()  # 模拟数据
                
                if data:
                    self.dataReceived.emit(data)
                    
                # 避免CPU占用过高
                time.sleep(0.01)
                
            except Exception as e:
                self.errorOccurred.emit(f"串口读取错误: {str(e)}")
                time.sleep(0.1)
    
    @Slot()
    def stop_receiving(self):
        """停止接收"""
        self.running = False
        print("[SerialReceiver] 已停止接收")
    
    def _mock_serial_read(self):
        """模拟串口数据(实际项目中删除此方法)"""
        import random
        if random.random() > 0.7:
            return bytes([0xAA, 0x55, 0x01, 0x02, 0x03, 0xFF])
        return None


# ========== 2. 协议解析 Worker ==========
class ProtocolParser(QObject):
    """解析串口协议包"""
    packetParsed = Signal(dict)  # 解析后的数据字典
    
    def __init__(self):
        super().__init__()
        self.buffer = bytearray()
        
    @Slot(bytes)
    def parse_data(self, raw_data: bytes):
        """解析协议(在独立线程中执行)"""
        self.buffer.extend(raw_data)
        
        # 示例协议: [0xAA 0x55] [CMD] [LEN] [DATA...] [CHECKSUM]
        while len(self.buffer) >= 6:  # 最小包长度
            # 查找帧头
            if self.buffer[0] == 0xAA and self.buffer[1] == 0x55:
                cmd = self.buffer[2]
                length = self.buffer[3]
                
                # 检查包是否完整
                if len(self.buffer) >= 5 + length:
                    packet_data = self.buffer[4:4+length]
                    checksum = self.buffer[4+length]
                    
                    # 简单校验(实际项目中使用CRC等)
                    if self._verify_checksum(packet_data, checksum):
                        # 解析成功,发送数据
                        parsed = {
                            'cmd': cmd,
                            'data': bytes(packet_data),
                            'timestamp': time.time()
                        }
                        self.packetParsed.emit(parsed)
                        print(f"[ProtocolParser] 解析包: CMD={hex(cmd)}, Data={packet_data.hex()}")
                    
                    # 移除已处理的数据
                    self.buffer = self.buffer[5+length:]
                else:
                    break  # 数据不完整,等待更多数据
            else:
                # 帧头错误,移除一个字节继续查找
                self.buffer.pop(0)
    
    def _verify_checksum(self, data, checksum):
        """校验和验证(简化版)"""
        return sum(data) & 0xFF == checksum


# ========== 3. 周期发送 Worker ==========
class PeriodicSender(QObject):
    """周期性发送指令到串口"""
    sendCommand = Signal(bytes)  # 需要发送的指令
    
    def __init__(self, interval_ms: int):
        super().__init__()
        self.interval_ms = interval_ms
        self.timer = None
        self.enabled = False
        
    @Slot()
    def start_periodic_send(self):
        """启动定时发送"""
        self.timer = QTimer()
        self.timer.setInterval(self.interval_ms)
        self.timer.timeout.connect(self.on_timeout)
        self.enabled = True
        self.timer.start()
        print(f"[PeriodicSender] 启动周期发送: {self.interval_ms}ms")
    
    @Slot()
    def stop_periodic_send(self):
        """停止定时发送"""
        self.enabled = False
        if self.timer:
            self.timer.stop()
        print("[PeriodicSender] 已停止周期发送")
    
    @Slot()
    def on_timeout(self):
        """定时器触发"""
        if self.enabled:
            # 构造查询指令 (示例: 查询电机状态)
            cmd = self._build_query_command(0x01)  # 0x01 = 查询状态
            self.sendCommand.emit(cmd)
    
    def _build_query_command(self, cmd_type):
        """构造指令包"""
        # 格式: [0xAA 0x55] [CMD] [LEN] [DATA] [CHECKSUM]
        packet = bytearray([0xAA, 0x55, cmd_type, 0x00])
        checksum = sum(packet[2:]) & 0xFF
        packet.append(checksum)
        return bytes(packet)


# ========== 4. 数据管理后端 ==========
class FOCBackend(QObject):
    """主控制类,管理所有Worker"""
    statusChanged = Signal(str)      # 状态文本
    motorSpeedChanged = Signal(int)  # 电机转速
    
    def __init__(self):
        super().__init__()
        self._status = "未连接"
        self._motor_speed = 0
        
        # 创建 Workers 和 Threads
        self.threads = []
        self.workers = []
        
        # 1. 串口接收线程
        self.receiver = SerialReceiver()
        self.receiver_thread = QThread()
        self.receiver.moveToThread(self.receiver_thread)
        self.receiver_thread.started.connect(self.receiver.start_receiving)
        self.receiver.dataReceived.connect(self.on_data_received)
        
        # 2. 协议解析线程
        self.parser = ProtocolParser()
        self.parser_thread = QThread()
        self.parser.moveToThread(self.parser_thread)
        self.receiver.dataReceived.connect(self.parser.parse_data)
        self.parser.packetParsed.connect(self.on_packet_parsed)
        
        # 3. 周期发送线程 (100ms发送一次)
        self.sender = PeriodicSender(100)
        self.sender_thread = QThread()
        self.sender.moveToThread(self.sender_thread)
        self.sender_thread.started.connect(self.sender.start_periodic_send)
        self.sender.sendCommand.connect(self.send_to_serial)
        
        # 保存引用
        self.threads = [self.receiver_thread, self.parser_thread, self.sender_thread]
        self.workers = [self.receiver, self.parser, self.sender]
    
    # ===== QML 属性 =====
    def get_status(self):
        return self._status
    
    def get_motor_speed(self):
        return self._motor_speed
    
    status = Property(str, get_status, notify=statusChanged)
    motorSpeed = Property(int, get_motor_speed, notify=motorSpeedChanged)
    
    # ===== 控制方法 =====
    @Slot()
    def start_communication(self):
        """启动所有通讯任务"""
        print("[FOCBackend] 启动所有任务...")
        for thread in self.threads:
            thread.start()
        self._status = "已连接"
        self.statusChanged.emit(self._status)
    
    @Slot()
    def stop_communication(self):
        """停止所有通讯任务"""
        print("[FOCBackend] 停止所有任务...")
        # 1. 停止 Workers
        self.receiver.stop_receiving()
        self.sender.stop_periodic_send()
        
        # 2. 停止线程事件循环
        for thread in self.threads:
            thread.quit()
        
        # 3. 等待线程结束
        for thread in self.threads:
            thread.wait(2000)
        
        self._status = "已断开"
        self.statusChanged.emit(self._status)
    
    # ===== 数据处理 =====
    @Slot(bytes)
    def on_data_received(self, data: bytes):
        """接收到原始数据"""
        print(f"[FOCBackend] 收到数据: {data.hex()}")
    
    @Slot(dict)
    def on_packet_parsed(self, packet: dict):
        """接收到解析后的数据包"""
        cmd = packet['cmd']
        data = packet['data']
        
        # 根据CMD类型更新UI数据
        if cmd == 0x01:  # 状态查询响应
            if len(data) >= 2:
                speed = int.from_bytes(data[0:2], 'big')
                self._motor_speed = speed
                self.motorSpeedChanged.emit(speed)
                print(f"[FOCBackend] 电机转速: {speed} RPM")
    
    @Slot(bytes)
    def send_to_serial(self, data: bytes):
        """发送数据到串口"""
        print(f"[FOCBackend] 发送指令: {data.hex()}")
        # 实际项目中: self.serial_port.write(data)
    
    @Slot(int)
    def set_motor_speed(self, speed: int):
        """设置电机转速(由QML调用)"""
        cmd = self._build_set_speed_command(speed)
        self.send_to_serial(cmd)
    
    def _build_set_speed_command(self, speed: int):
        """构造设置转速指令"""
        data = speed.to_bytes(2, 'big')
        packet = bytearray([0xAA, 0x55, 0x02, len(data)])
        packet.extend(data)
        checksum = sum(packet[2:]) & 0xFF
        packet.append(checksum)
        return bytes(packet)


# ========== 主程序 ==========
if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    backend = FOCBackend()
    engine.rootContext().setContextProperty("backend", backend)
    
    # 延迟启动通讯
    QTimer.singleShot(500, backend.start_communication)
    
    # 应用退出时停止
    app.aboutToQuit.connect(backend.stop_communication)
    
    engine.addImportPath(sys.path[0])
    engine.loadFromModule("Example", "Main")
    
    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec())
