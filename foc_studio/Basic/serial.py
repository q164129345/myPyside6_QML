import sys
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo

class mySerial(QObject):
    
    connectionStatusChanged = Signal(bool, str)
    isConnectedChanged = Signal()
    
    def __init__(self):
        super().__init__()
        self._serial_port = QSerialPort() # create serial port object
        self._is_connected = False
        self._ports_list = [] # available ports list
        self._receive_buffer = bytearray()  # Efficient byte buffer using bytearray
        self._serial_port.readyRead.connect(self.On_Data_Ready) # 关键！当串口有数据，自动调用回调函数_on_data_ready
        self.Scan_Ports()

    @Property(bool, notify=isConnectedChanged)
    def isConnected(self):
        """QML可读取的连接状态属性"""
        return self._is_connected

    def Scan_Ports(self):
        available_ports = QSerialPortInfo.availablePorts() # search available serial ports
        
        # Scan and print available ports
        for port in available_ports:
            port_name = port.portName()
            if port_name.startswith("COM"):
                self._ports_list.append({"portName": port_name, "description": port.description()})
                print(f"[mySerial] find: {port_name} - {port.description()}", flush=True)

        print(f"[mySerial] scanning completed，{len(self._ports_list)} ports found", flush=True)

    @Slot(str, int)
    def openPort(self, port_name, baud_rate=9600):
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
        self._serial_port.setDataBits(QSerialPort.Data8)      
        self._serial_port.setParity(QSerialPort.NoParity)     
        self._serial_port.setStopBits(QSerialPort.OneStop)
        self._serial_port.setFlowControl(QSerialPort.NoFlowControl)
        
        print(f"[mySerial] try to open: {port_name}, baud rate: {baud_rate}", flush=True)
        if self._serial_port.open(QSerialPort.ReadWrite):
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
    def closePort(self):
        """关闭串口"""
        if self._is_connected and self._serial_port.isOpen():
            self._serial_port.close()
            self._is_connected = False
            self.isConnectedChanged.emit()  # 触发属性变化信号
            print("[mySerial] Port closed", flush=True)
            self.connectionStatusChanged.emit(False, "Port closed")

    def On_Data_Ready(self):
        """
        Performance optimized: 
        - Uses readAll() to get all available bytes at once
        - Uses bytearray for efficient byte-level operations
        - Avoids repeated memory allocations
        """
        if self._serial_port.bytesAvailable() > 0:
            # Read all available bytes at once (more efficient than reading one by one)
            data = self._serial_port.readAll()
            
            # Convert QByteArray to bytes and extend the buffer
            # bytearray.extend() is highly optimized for appending bytes
            self._receive_buffer.extend(data.data())
            
            # print debug info
            # print(f"[mySerial] received {data.size()} bytes" , flush=True)

    def read_buffer(self, size):
        """
        read and remove specified number of bytes from buffer
        Args:
            size: 
                - n : specified number of bytes to read, 
                - -1 : means read all
        Returns:
            bytes: read data
        """
        if size == -1 or size >= len(self._receive_buffer):
            data = bytes(self._receive_buffer)
            self._receive_buffer.clear()
            return data
        else:
            data = bytes(self._receive_buffer[:size])
            del self._receive_buffer[:size]  # Efficient deletion from bytearray
            return data
    
    def clear_buffer(self):
        self._receive_buffer.clear() # clear all
    
    def get_buffer_size(self):
        return len(self._receive_buffer)

# Test the mySerial class
if __name__ == "__main__":
    # Simple test
    serial = mySerial()


