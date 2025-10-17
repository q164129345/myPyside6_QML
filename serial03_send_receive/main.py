"""串口收发数据示例 - PySide6 + QML"""
import sys
from PySide6.QtCore import QObject, Signal, Slot, QByteArray
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo

class SerialBackend(QObject):
    """串口后端类"""
    
    portsListChanged = Signal(list)
    connectionStatusChanged = Signal(bool, str)
    errorOccurred = Signal(str)
    dataReceived = Signal(str, str) # 两种数据格式ASCII, HEX
    dataSent = Signal(str, str)     # 两种数据格式ASCII, HEX
    
    def __init__(self):
        super().__init__()
        self._serial_port = QSerialPort()
        self._is_connected = False
        self._serial_port.errorOccurred.connect(self._on_error)
        self._serial_port.readyRead.connect(self._on_data_ready) # 关键！当串口有数据，自动调用回调函数_on_data_ready
    
    @Slot()
    def scanPorts(self):
        """扫描可用串口"""
        print("[SerialBackend] 开始扫描串口...", flush=True)
        available_ports = QSerialPortInfo.availablePorts()
        ports_list = []
        
        for port in available_ports:
            port_name = port.portName()
            if port_name.startswith("COM"):
                ports_list.append({"portName": port_name, "description": port.description()})
                print(f"[SerialBackend] 发现: {port_name} - {port.description()}", flush=True)
        
        self.portsListChanged.emit(ports_list)
        print(f"[SerialBackend] 扫描完成，共 {len(ports_list)} 个串口", flush=True)
    
    @Slot(str, int)
    def openPort(self, port_name, baud_rate=9600):
        """打开串口"""

        # 如果串口已经连接，先关闭它才能重新打开
        if self._is_connected:
            self.closePort()
        
        print(f"[SerialBackend] 打开: {port_name}, 波特率: {baud_rate}", flush=True)
        self._serial_port.setPortName(port_name)                    # 设置端口名（如 COM3）
        self._serial_port.setBaudRate(baud_rate)                    # 设置波特率
        self._serial_port.setDataBits(QSerialPort.Data8)            # 数据位8bit
        self._serial_port.setParity(QSerialPort.NoParity)           # 无奇偶校验
        self._serial_port.setStopBits(QSerialPort.OneStop)          # 1个停止位
        self._serial_port.setFlowControl(QSerialPort.NoFlowControl) # 无流控
        
        if self._serial_port.open(QSerialPort.ReadWrite):
            self._is_connected = True
            msg = f"成功打开 {port_name}"
            print(f"[SerialBackend] {msg}", flush=True)
            self.connectionStatusChanged.emit(True, msg)
        else:
            msg = f"无法打开 {port_name}: {self._serial_port.errorString()}"
            print(f"[SerialBackend] {msg}", flush=True)
            self.connectionStatusChanged.emit(False, msg)
            self.errorOccurred.emit(msg)
    
    @Slot()
    def closePort(self):
        """关闭串口"""
        if not self._is_connected:
            return
        
        port_name = self._serial_port.portName()
        self._serial_port.close()
        self._is_connected = False
        msg = f"已断开 {port_name}"
        print(f"[SerialBackend] {msg}", flush=True)
        self.connectionStatusChanged.emit(False, msg)
    
    def _format_hex(self, byte_data):
        """格式化字节数组为HEX字符串"""
        hex_str = byte_data.toHex().data().decode('ascii')
        return ' '.join([hex_str[i:i+2] for i in range(0, len(hex_str), 2)]).upper()
    
    @Slot(str)
    def sendData(self, data):
        """发送ASCII数据"""
        if not self._is_connected:
            self.errorOccurred.emit("串口未连接")
            return
        if not data:
            return
        
        try:
            byte_data = QByteArray(data.encode('utf-8'))
            if self._serial_port.write(byte_data) != -1:
                self._serial_port.flush()
                print(f"[SerialBackend] 发送: {data} | {self._format_hex(byte_data)}", flush=True)
                self.dataSent.emit(data, self._format_hex(byte_data))
            else:
                self.errorOccurred.emit("发送失败")
        except Exception as e:
            self.errorOccurred.emit(f"发送异常: {e}")
    
    @Slot(str)
    def sendHexData(self, hex_string):
        """发送HEX数据"""
        if not self._is_connected:
            self.errorOccurred.emit("串口未连接")
            return
        if not hex_string:
            return
        
        try:
            # 清洗用户输入的 HEX 字符串，去除所有无关字符，得到纯净的十六进制字符串。 
            # 1.先移除所有空格。2.移除所有换行符。3.去除字符串首尾的空白字符。
            hex_clean = hex_string.replace(" ", "").replace("\n", "").strip()
            
            # 验证 HEX 字符串的合法性：检查是否只包含十六进制字符且长度为偶数。
            if not all(c in '0123456789ABCDEFabcdef' for c in hex_clean):
                self.errorOccurred.emit("无效HEX格式")
                return
            if len(hex_clean) % 2 != 0:
                self.errorOccurred.emit("HEX长度必须为偶数")
                return
            
            # 将清洗后的 HEX 字符串转换为字节数组
            byte_data = QByteArray.fromHex(hex_clean.encode('ascii'))
            # 格式化 HEX 字符串用于显示
            hex_formatted = ' '.join([hex_clean[i:i+2] for i in range(0, len(hex_clean), 2)]).upper()
            # 生成 ASCII 可读字符串，非打印字符用 '.' 替代
            ascii_str = ''.join([chr(b) if 32 <= b < 127 else '.' for b in byte_data.data()])
            
            if self._serial_port.write(byte_data) != -1:
                self._serial_port.flush()
                print(f"[SerialBackend] 发送: {ascii_str} | {hex_formatted}", flush=True)
                self.dataSent.emit(ascii_str, hex_formatted)
            else:
                self.errorOccurred.emit("发送失败")
        except Exception as e:
            self.errorOccurred.emit(f"发送异常: {e}")
    
    def _on_data_ready(self):
        """接收数据回调"""
        if not self._is_connected:
            return
        
        byte_data = self._serial_port.readAll() # 读取串口的所有可用数据
        if byte_data.isEmpty():
            return
        
        # 将接收到的字节数据解码为UTF-8字符串，如果解码出错则用替换字符处理
        ascii_str = byte_data.data().decode('utf-8', errors='replace')
        # 调用内部方法格式化字节数据为HEX字符串（大写，空格分隔）
        hex_formatted = self._format_hex(byte_data)
        # 在控制台打印接收到的数据，包括ASCII表示和HEX表示
        print(f"[SerialBackend] 接收: {ascii_str} | {hex_formatted}", flush=True)
        # 发出数据接收信号，传递ASCII字符串和HEX字符串给QML前端
        self.dataReceived.emit(ascii_str, hex_formatted)
    
    def _on_error(self, error):
        """错误处理"""
        if error == QSerialPort.NoError:
            return
        
        msg = self._serial_port.errorString()
        print(f"[SerialBackend] 错误: {msg}", flush=True)
        if self._is_connected:
            self._is_connected = False
            self.connectionStatusChanged.emit(False, f"连接错误: {msg}")
        self.errorOccurred.emit(msg)
    

if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    backend = SerialBackend()
    
    engine.rootContext().setContextProperty("backend", backend)
    app.aboutToQuit.connect(backend.closePort)
    
    engine.addImportPath(sys.path[0])
    engine.loadFromModule("Example", "Main")
    
    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
