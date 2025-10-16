# python3.10.11 - PySide6==6.9
"""
serial03_send_receive - 基础收发数据
核心概念：
1. write() 发送数据
2. readyRead 信号接收数据
3. readAll() 读取缓冲区
4. HEX与ASCII格式切换显示
"""
import sys
from PySide6.QtCore import QObject, Signal, Slot, QByteArray
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo

class SerialBackend(QObject):
    """串口后端类 - 负责串口扫描、打开、关闭、收发数据"""
    
    # 定义信号
    portsListChanged = Signal(list)      # 串口列表更新
    connectionStatusChanged = Signal(bool, str)  # 连接状态改变（是否连接，状态信息）
    errorOccurred = Signal(str)          # 错误信息
    dataReceived = Signal(str, str)      # 接收到数据（ASCII格式，HEX格式）
    dataSent = Signal(str, str)          # 发送数据（ASCII格式，HEX格式）
    
    def __init__(self):
        super().__init__()
        self._ports_list = []              # 串口列表
        self._serial_port = QSerialPort()  # 串口对象
        self._is_connected = False         # 连接状态
        
        # 监听串口错误信号
        self._serial_port.errorOccurred.connect(self._on_error)
        # 监听串口数据接收信号
        self._serial_port.readyRead.connect(self._on_data_ready)
    
    @Slot()
    def scanPorts(self):
        """扫描系统中所有可用的COM口"""
        print("[SerialBackend] 开始扫描串口...", flush=True)
        
        # 获取所有可用串口信息
        available_ports = QSerialPortInfo.availablePorts()
        
        # 清空之前的列表
        self._ports_list = []
        
        if not available_ports:
            print("[SerialBackend] 未检测到可用串口", flush=True)
            self.portsListChanged.emit([])
            return
        
        # 遍历每个串口，只处理COM口
        for port in available_ports:
            port_name = port.portName()
            
            # 只处理COM口（Windows系统）
            if not port_name.startswith("COM"):
                print(f"[SerialBackend] 跳过非COM口: {port_name}", flush=True)
                continue
            
            port_info = {
                "portName": port_name,              # 端口名称（如 COM1, COM3）
                "description": port.description(),  # 设备描述
            }
            
            self._ports_list.append(port_info)
            print(f"[SerialBackend] 发现COM口: {port_info['portName']} - {port_info['description']}", flush=True)
        
        # 发射信号，通知QML更新界面
        self.portsListChanged.emit(self._ports_list)
        print(f"[SerialBackend] 扫描完成，共找到 {len(self._ports_list)} 个COM口", flush=True)
    
    @Slot(str, int)
    def openPort(self, port_name, baud_rate=9600):
        """打开指定的串口
        
        Args:
            port_name: 端口名称，如 "COM1"
            baud_rate: 波特率，默认9600
        """
        # 如果已经连接，先关闭
        if self._is_connected:
            print("[SerialBackend] 串口已连接，先关闭当前连接", flush=True)
            self.closePort()
        
        print(f"[SerialBackend] 尝试打开串口: {port_name}, 波特率: {baud_rate}", flush=True)
        
        # 设置串口名称
        self._serial_port.setPortName(port_name)
        
        # 配置串口参数
        self._serial_port.setBaudRate(baud_rate)              # 波特率
        self._serial_port.setDataBits(QSerialPort.Data8)      # 数据位：8
        self._serial_port.setParity(QSerialPort.NoParity)     # 校验位：无
        self._serial_port.setStopBits(QSerialPort.OneStop)    # 停止位：1
        self._serial_port.setFlowControl(QSerialPort.NoFlowControl)  # 流控：无
        
        # 尝试打开串口
        if self._serial_port.open(QSerialPort.ReadWrite):
            self._is_connected = True
            success_msg = f"成功打开 {port_name}"
            print(f"[SerialBackend] {success_msg}", flush=True)
            print(f"[SerialBackend] 串口参数 - 波特率:{baud_rate}, 数据位:8, 校验:无, 停止位:1", flush=True)
            self.connectionStatusChanged.emit(True, success_msg)
        else:
            error_msg = f"无法打开 {port_name}"
            error_detail = self._serial_port.errorString()
            print(f"[SerialBackend] {error_msg}: {error_detail}", flush=True)
            self.connectionStatusChanged.emit(False, error_msg)
            self.errorOccurred.emit(f"{error_msg}: {error_detail}")
    
    @Slot()
    def closePort(self):
        """关闭串口"""
        if not self._is_connected:
            print("[SerialBackend] 串口未连接", flush=True)
            return
        
        port_name = self._serial_port.portName()
        print(f"[SerialBackend] 关闭串口: {port_name}", flush=True)
        
        # 关闭串口
        self._serial_port.close()
        self._is_connected = False
        
        close_msg = f"已断开 {port_name}"
        print(f"[SerialBackend] {close_msg}", flush=True)
        self.connectionStatusChanged.emit(False, close_msg)
    
    @Slot(str)
    def sendData(self, data):
        """发送数据到串口
        
        Args:
            data: 要发送的字符串数据
        """
        if not self._is_connected:
            error_msg = "串口未连接，无法发送数据"
            print(f"[SerialBackend] {error_msg}", flush=True)
            self.errorOccurred.emit(error_msg)
            return
        
        if not data:
            print("[SerialBackend] 发送数据为空，已忽略", flush=True)
            return
        
        try:
            # 将字符串转换为字节数组
            byte_data = QByteArray(data.encode('utf-8'))
            
            # 写入串口
            bytes_written = self._serial_port.write(byte_data)
            
            if bytes_written == -1:
                error_msg = "数据发送失败"
                print(f"[SerialBackend] {error_msg}", flush=True)
                self.errorOccurred.emit(error_msg)
            else:
                # 刷新缓冲区，确保数据立即发送
                self._serial_port.flush()
                
                # 转换为HEX格式
                hex_str = byte_data.toHex().data().decode('ascii')
                hex_formatted = ' '.join([hex_str[i:i+2] for i in range(0, len(hex_str), 2)]).upper()
                
                print(f"[SerialBackend] 发送数据: ASCII='{data}' | HEX=[{hex_formatted}] | 字节数:{bytes_written}", flush=True)
                
                # 发射信号通知QML
                self.dataSent.emit(data, hex_formatted)
        
        except Exception as e:
            error_msg = f"发送数据异常: {str(e)}"
            print(f"[SerialBackend] {error_msg}", flush=True)
            self.errorOccurred.emit(error_msg)
    
    @Slot(str)
    def sendHexData(self, hex_string):
        """发送HEX格式数据
        
        Args:
            hex_string: 十六进制字符串，如 "01 02 03 FF"
        """
        if not self._is_connected:
            error_msg = "串口未连接，无法发送数据"
            print(f"[SerialBackend] {error_msg}", flush=True)
            self.errorOccurred.emit(error_msg)
            return
        
        if not hex_string:
            print("[SerialBackend] 发送数据为空，已忽略", flush=True)
            return
        
        try:
            # 去除空格并验证是否为有效的HEX字符串
            hex_clean = hex_string.replace(" ", "").replace("\n", "").strip()
            
            if not all(c in '0123456789ABCDEFabcdef' for c in hex_clean):
                error_msg = "无效的HEX格式，只能包含0-9和A-F"
                print(f"[SerialBackend] {error_msg}", flush=True)
                self.errorOccurred.emit(error_msg)
                return
            
            if len(hex_clean) % 2 != 0:
                error_msg = "HEX字符串长度必须为偶数"
                print(f"[SerialBackend] {error_msg}", flush=True)
                self.errorOccurred.emit(error_msg)
                return
            
            # 将HEX字符串转换为字节数组
            byte_data = QByteArray.fromHex(hex_clean.encode('ascii'))
            
            # 写入串口
            bytes_written = self._serial_port.write(byte_data)
            
            if bytes_written == -1:
                error_msg = "数据发送失败"
                print(f"[SerialBackend] {error_msg}", flush=True)
                self.errorOccurred.emit(error_msg)
            else:
                # 刷新缓冲区
                self._serial_port.flush()
                
                # 格式化HEX显示
                hex_formatted = ' '.join([hex_clean[i:i+2] for i in range(0, len(hex_clean), 2)]).upper()
                
                # 尝试转换为ASCII显示（非可打印字符用'.'表示）
                ascii_str = ''.join([chr(b) if 32 <= b < 127 else '.' for b in byte_data])
                
                print(f"[SerialBackend] 发送HEX: [{hex_formatted}] | ASCII='{ascii_str}' | 字节数:{bytes_written}", flush=True)
                
                # 发射信号通知QML
                self.dataSent.emit(ascii_str, hex_formatted)
        
        except Exception as e:
            error_msg = f"发送HEX数据异常: {str(e)}"
            print(f"[SerialBackend] {error_msg}", flush=True)
            self.errorOccurred.emit(error_msg)
    
    def _on_data_ready(self):
        """当串口有数据可读时触发（内部回调）"""
        if not self._is_connected:
            return
        
        # 读取所有可用数据
        byte_data = self._serial_port.readAll()
        
        if byte_data.isEmpty():
            return
        
        # 转换为ASCII格式（UTF-8解码）
        try:
            ascii_str = byte_data.data().decode('utf-8', errors='replace')
        except:
            # 如果解码失败，用替换字符
            ascii_str = byte_data.data().decode('ascii', errors='replace')
        
        # 转换为HEX格式
        hex_str = byte_data.toHex().data().decode('ascii')
        hex_formatted = ' '.join([hex_str[i:i+2] for i in range(0, len(hex_str), 2)]).upper()
        
        print(f"[SerialBackend] 接收数据: ASCII='{ascii_str}' | HEX=[{hex_formatted}] | 字节数:{byte_data.size()}", flush=True)
        
        # 发射信号通知QML
        self.dataReceived.emit(ascii_str, hex_formatted)
    
    def _on_error(self, error):
        """串口错误处理"""
        if error == QSerialPort.NoError:
            return
        
        error_msg = self._serial_port.errorString()
        print(f"[SerialBackend] 串口错误: {error_msg}", flush=True)
        
        # 如果发生严重错误，断开连接
        if self._is_connected:
            self._is_connected = False
            self.connectionStatusChanged.emit(False, f"连接错误: {error_msg}")
        
        self.errorOccurred.emit(error_msg)
    

if __name__ == "__main__":
    # 创建应用程序和引擎
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # 创建串口后端对象
    backend = SerialBackend()
    
    # 注册到QML环境
    engine.rootContext().setContextProperty("backend", backend)

    # 应用程序退出前自动关闭串口（重要！防止资源泄漏）
    app.aboutToQuit.connect(backend.closePort)
    
    # 加载QML文件
    engine.addImportPath(sys.path[0])  # 当前项目路径
    engine.loadFromModule("Example", "Main")  # 模块(Example) + QML文件名(Main.qml)

    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec())
