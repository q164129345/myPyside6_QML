# python3.10.11 - PySide6==6.9
"""
serial02_open_close - 串口打开与关闭
核心概念：
1. QSerialPort - 串口打开、关闭操作
2. 串口参数配置（波特率、数据位、停止位、校验位）
3. 连接状态管理与反馈
"""
import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo

class SerialBackend(QObject):
    """串口后端类 - 负责串口扫描、打开、关闭管理"""
    
    # 定义信号
    portsListChanged = Signal(list)      # 串口列表更新
    connectionStatusChanged = Signal(bool, str)  # 连接状态改变（是否连接，状态信息）
    errorOccurred = Signal(str)          # 错误信息
    
    def __init__(self):
        super().__init__()
        self._ports_list = []              # 串口列表
        self._serial_port = QSerialPort()  # 串口对象
        self._is_connected = False         # 连接状态
        
        # 监听串口错误信号
        self._serial_port.errorOccurred.connect(self._on_error)
    
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
    
    @Slot(result=bool)
    def isConnected(self):
        """返回当前连接状态"""
        return self._is_connected


if __name__ == "__main__":
    # 创建应用程序和引擎
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # 创建串口后端对象
    backend = SerialBackend()
    
    # 注册到QML环境
    engine.rootContext().setContextProperty("backend", backend)

    # 加载QML文件
    engine.addImportPath(sys.path[0])  # 当前项目路径
    engine.loadFromModule("Example", "Main")  # 模块(Example) + QML文件名(Main.qml)

    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec())
