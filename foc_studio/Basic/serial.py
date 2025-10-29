import sys
from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo

class mySerial(QObject):
    """串口后端类"""
    
    portsListChanged = Signal(list)
    connectionStatusChanged = Signal(bool, str)
    errorOccurred = Signal(str)
    
    def __init__(self):
        super().__init__()
        self._serial_port = QSerialPort() # 创建串口对象
        self._is_connected = False
        self._serial_port.errorOccurred.connect(self._on_error)
        self._serial_port.readyRead.connect(self._on_data_ready) # 关键！当串口有数据，自动调用回调函数_on_data_ready
    
    @Slot()
    def scanPorts(self):
        """扫描可用串口"""
        available_ports = QSerialPortInfo.availablePorts()
        ports_list = []
        
        for port in available_ports:
            port_name = port.portName()
            if port_name.startswith("COM"):
                ports_list.append({"portName": port_name, "description": port.description()})
                print(f"[mySerial] 发现: {port_name} - {port.description()}", flush=True)
        
        self.portsListChanged.emit(ports_list)
        print(f"[mySerial] 扫描完成，共 {len(ports_list)} 个串口", flush=True)



