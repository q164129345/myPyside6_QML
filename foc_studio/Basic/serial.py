import sys
from typing import Dict, List
from typing import Optional, Callable
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo

class mySerial(QObject):
    
    RXBUFFER_SIZE = 20 * 1024 # 20 KB（限制缓冲区的大小，防止内存不断增长导致崩溃）
    connectionStatusChanged = Signal(bool, str)
    isConnectedChanged = Signal()
    portsListChanged = Signal(list)  # 发射串口列表给QML
    dataReceived = Signal(bytes)     # 发射接收到的数据给QML
    
    def __init__(self) -> None:
        super().__init__()
        self._serial_port = QSerialPort() # create serial port object
        self._is_connected = False
        self._ports_list = [] # available ports list
        self._serial_port.readyRead.connect(self.On_Data_Ready) # 关键！当串口有数据，自动调用回调函数_on_data_ready
        self.Scan_Ports()  # 初始化时扫描串口

    @Property(bool, notify=isConnectedChanged)  # type: ignore
    def isConnected(self) -> bool:
        """QML可读取的连接状态属性"""
        return self._is_connected
    
    @Property(list, notify=portsListChanged)  # type: ignore
    def portsList(self) -> list:
        """QML可读取的串口列表属性"""
        return self._ports_list

    def Scan_Ports(self) -> None:
        available_ports = QSerialPortInfo.availablePorts() # search available serial ports
        
        # Scan and print available ports
        for port in available_ports:
            port_name = port.portName()
            if port_name.startswith("COM"):
                self._ports_list.append({"portName": port_name, "description": port.description()})
                print(f"[mySerial] find: {port_name} - {port.description()}", flush=True)

        print(f"[mySerial] scanning completed，{len(self._ports_list)} ports found", flush=True)
        self.portsListChanged.emit(self._ports_list)  # 发射串口列表给QML

    @Slot(str, int)
    def openPort(self, port_name: str, baud_rate: int = 9600) -> None:
        """
        Args:
            port_name:  for example :"COM1"
            baud_rate:  default: 9600
        """
        if self._is_connected:
            print(f"[mySerial] {port_name} is already open, closing it first", flush=True)
            self.closePort()

        # Serial port settings
        self._serial_port.setPortName(port_name)
        self._serial_port.setBaudRate(baud_rate)             
        self._serial_port.setDataBits(QSerialPort.Data8)  # type: ignore   
        self._serial_port.setParity(QSerialPort.NoParity) # type: ignore    
        self._serial_port.setStopBits(QSerialPort.OneStop) # type: ignore
        self._serial_port.setFlowControl(QSerialPort.NoFlowControl) # type: ignore
        
        print(f"[mySerial] try to open: {port_name}, baud rate: {baud_rate}", flush=True)
        if self._serial_port.open(QSerialPort.ReadWrite): # type: ignore
            self._is_connected = True
            self.isConnectedChanged.emit()  # 触发属性变化信号
            success_msg = f"open successfully: {port_name}"
            print(f"[mySerial] {success_msg}", flush=True)
            print(f"[mySerial] baud_rate:{baud_rate}, data_bit:8, Parity:no, stop_bit:1", flush=True)
            self.connectionStatusChanged.emit(True, success_msg)
        else:
            error_msg = f"open failed: {port_name}"
            error_detail = self._serial_port.errorString()
            print(f"[mySerial] {error_msg}: {error_detail}", flush=True)
            self.connectionStatusChanged.emit(False, error_msg)

    @Slot()
    def closePort(self) -> None:
        """关闭串口"""
        if self._is_connected and self._serial_port.isOpen():
            self._serial_port.close()
            self._is_connected = False
            self.isConnectedChanged.emit()  # 触发属性变化信号
            print("[mySerial] Port closed", flush=True)
            self.connectionStatusChanged.emit(False, "Port closed")

    def On_Data_Ready(self) -> None:
        """
        Performance optimized: 
        - Uses readAll() to get all available bytes at once
        - Uses bytearray for efficient byte-level operations
        - Avoids repeated memory allocations
        """
        if self._serial_port.bytesAvailable() > 0:
            # Read all available bytes at once (more efficient than reading one by one)
            data = self._serial_port.readAll()

            bytesData = data.data() # QByteArray to bytes

            # 发送信号，通过信号将数据传递出去
            self.dataReceived.emit(bytesData)
            
            # print debug info
            # print(f"[mySerial] Processing {len(bytesData)} bytes {bytesData}", flush=True)

# Test the mySerial class
if __name__ == "__main__":
    # Simple test
    serial = mySerial()


