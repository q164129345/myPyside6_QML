from PySide6.QtCore import QObject, Signal, Slot, Property

from core.transport.serial import mySerial
from core.service.data_processor import DataProcessor


class BackendFacade(QObject):
    """
    系统控制中心，负责：
    - 创建并持有 backend 对象
    - 建立信号连接
    - 向 QML UI 暴露接口
    """

    # 转发来自 Transport 的信号
    connectionStatusChanged = Signal(bool, str)
    isConnectedChanged = Signal()
    portsListChanged = Signal(list)

    def __init__(self) -> None:
        super().__init__()
        self._serial = mySerial()
        self._processor = DataProcessor()

        # Transport → Service
        self._serial.dataReceived.connect(self._processor.process_data)

        # 将 Transport 信号转发至 Facade（供 QML 订阅）
        self._serial.connectionStatusChanged.connect(self.connectionStatusChanged)
        self._serial.isConnectedChanged.connect(self.isConnectedChanged)
        self._serial.portsListChanged.connect(self.portsListChanged)

    # ── QML 可读属性 ────────────────────────────────────────────────────

    @Property(bool, notify=isConnectedChanged)  # type: ignore
    def isConnected(self) -> bool:
        return self._serial.isConnected  # type: ignore[return-value]

    @Property(list, notify=portsListChanged)  # type: ignore
    def portsList(self) -> list:
        return self._serial.portsList  # type: ignore[return-value]

    # ── 串口控制 API ─────────────────────────────────────────────────────

    @Slot(str, int)
    def connectSerial(self, port_name: str, baud_rate: int = 9600) -> None:
        self._serial.openPort(port_name, baud_rate)

    @Slot()
    def disconnectSerial(self) -> None:
        self._serial.closePort()

    @Slot()
    def scanPorts(self) -> None:
        self._serial.Scan_Ports()

    @Slot(str)
    def addManualPort(self, port_name: str) -> None:
        self._serial.addManualPort(port_name)

    # ── 电机命令 API（待协议层编码实现后完善）────────────────────────────

    @Slot(int, bytes)
    def sendMotorCommand(self, cmd: int, data: bytes = b'') -> None:
        """
        发送电机控制命令。
        QML → BackendFacade → Protocol.encode() → Transport.write()
        """
        # TODO: 调用 Protocol.encode(cmd, data) 后经 Transport 发送
        pass
