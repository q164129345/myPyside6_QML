# python3.10.11 - PySide6==6.9
"""
serial01_basic_scan - 串口扫描与基本信息
核心概念：
1. QSerialPortInfo - 获取系统可用串口信息
2. 扫描并显示串口详细信息（端口名、描述）
3. 信号机制更新QML界面
"""
import sys

from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtSerialPort import QSerialPortInfo

class SerialBackend(QObject):
    """串口后端类 - 负责串口扫描和信息管理"""
    
    # 定义信号：当串口列表更新时发射
    portsListChanged = Signal(list)  # 发送串口信息列表
    statusChanged = Signal(str)      # 发送状态消息
    
    def __init__(self):
        super().__init__()
        self._ports_list = []  # 内部存储串口列表
    
    @Slot()
    def scanPorts(self):
        """扫描系统中所有可用的串口"""
        print("[SerialBackend] 开始扫描串口...")
        
        # 获取所有可用串口信息
        available_ports = QSerialPortInfo.availablePorts()
        
        # 清空之前的列表
        self._ports_list = []
        
        if not available_ports:
            print("[SerialBackend] 未检测到可用串口")
            self.statusChanged.emit("未检测到可用串口")
            self.portsListChanged.emit([])
            return
        
        # 遍历每个串口，提取详细信息
        for port in available_ports:
            port_name = port.portName()
            
            # 只处理COM口（Windows系统）
            if not port_name.startswith("COM"):
                print(f"[SerialBackend] 跳过非COM口: {port_name}")
                continue
            
            port_info = {
                "portName": port_name,              # 端口名称（如 COM1, COM3）
                "description": port.description(),  # 设备描述
            }
            
            self._ports_list.append(port_info)
            
            # 打印到控制台（调试用）
            print(f"[SerialBackend] 发现COM口: {port_info['portName']} - {port_info['description']}")
        
        # 发射信号，通知QML更新界面
        self.statusChanged.emit(f"找到 {len(self._ports_list)} 个串口")
        self.portsListChanged.emit(self._ports_list)
        print(f"[SerialBackend] 扫描完成，共找到 {len(self._ports_list)} 个串口")
    
    @Slot(str)
    def showPortDetails(self, port_name):
        """显示指定串口的详细信息（调试用）"""
        print(f"[SerialBackend] 查看串口详情: {port_name}")
        for port in self._ports_list:
            if port["portName"] == port_name:
                print(f"  端口名称: {port['portName']}")
                print(f"  描述: {port['description']}")
                break


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
