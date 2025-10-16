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
    dataReceived = Signal(str, str)
    dataSent = Signal(str, str)
    
    def __init__(self):
        super().__init__()
        self._serial_port = QSerialPort()
        self._is_connected = False
        self._serial_port.errorOccurred.connect(self._on_error)
        self._serial_port.readyRead.connect(self._on_data_ready)
    
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
        if self._is_connected:
            self.closePort()
        
        print(f"[SerialBackend] 打开: {port_name}, 波特率: {baud_rate}", flush=True)
        self._serial_port.setPortName(port_name)
        self._serial_port.setBaudRate(baud_rate)
        self._serial_port.setDataBits(QSerialPort.Data8)
        self._serial_port.setParity(QSerialPort.NoParity)
        self._serial_port.setStopBits(QSerialPort.OneStop)
        self._serial_port.setFlowControl(QSerialPort.NoFlowControl)
        
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
            hex_clean = hex_string.replace(" ", "").replace("\n", "").strip()
            
            if not all(c in '0123456789ABCDEFabcdef' for c in hex_clean):
                self.errorOccurred.emit("无效HEX格式")
                return
            if len(hex_clean) % 2 != 0:
                self.errorOccurred.emit("HEX长度必须为偶数")
                return
            
            byte_data = QByteArray.fromHex(hex_clean.encode('ascii'))
            hex_formatted = ' '.join([hex_clean[i:i+2] for i in range(0, len(hex_clean), 2)]).upper()
            ascii_str = ''.join([chr(b) if 32 <= b < 127 else '.' for b in byte_data])
            
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
        
        byte_data = self._serial_port.readAll()
        if byte_data.isEmpty():
            return
        
        ascii_str = byte_data.data().decode('utf-8', errors='replace')
        hex_formatted = self._format_hex(byte_data)
        print(f"[SerialBackend] 接收: {ascii_str} | {hex_formatted}", flush=True)
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
