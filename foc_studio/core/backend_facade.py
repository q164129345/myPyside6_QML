from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer

from core.transport.serial import mySerial
from core.service.data_processor import DataProcessor
from core.service.frame_dispatcher import FrameDispatcher
from core.command.motor_command import build_motor_control
from core.command.pc_heartbeat_command import build_pc_heartbeat


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

    # 转发来自 FrameDispatcher 的信号
    speedUpdated        = Signal(int)       # 当前转速 rpm
    motorTempUpdated    = Signal(float)     # 电机温度 ℃
    mosTempUpdated      = Signal(float)     # MOS 温度 ℃
    enableStateUpdated  = Signal(int)       # 使能状态 0/1
    errorCodeUpdated    = Signal(int)       # 错误码
    iqIdUpdated         = Signal(int, int)  # Iq 分量, Id 分量
    motorCurrentUpdated = Signal(float)     # 电机电流 A

    def __init__(self) -> None:
        super().__init__()
        self._serial = mySerial()
        self._processor = DataProcessor()
        self._dispatcher = FrameDispatcher()

        # 电机状态（用于 500 ms 周期性保活发送）
        self._motor_enable: int = 0
        self._motor_target_speed: int = 0

        # Periodic motor command timer: CMD 0x01 is sent every 500 ms while enabled.
        self._motor_cmd_timer = QTimer(self)
        self._motor_cmd_timer.setInterval(500)
        self._motor_cmd_timer.timeout.connect(self._send_motor_cmd)

        self._heartbeat_timer = QTimer(self)
        self._heartbeat_timer.setInterval(1000)
        self._heartbeat_timer.timeout.connect(self._send_heartbeat)

        # Transport → Service
        self._serial.dataReceived.connect(self._processor.process_data)

        # Service → FrameDispatcher
        self._processor.telemetryUpdated.connect(self._dispatcher.dispatch)

        # FrameDispatcher → Facade (再由 QML 订阅)
        self._dispatcher.speedUpdated.connect(self.speedUpdated)
        self._dispatcher.motorTempUpdated.connect(self.motorTempUpdated)
        self._dispatcher.mosTempUpdated.connect(self.mosTempUpdated)
        self._dispatcher.enableStateUpdated.connect(self.enableStateUpdated)
        self._dispatcher.errorCodeUpdated.connect(self.errorCodeUpdated)
        self._dispatcher.iqIdUpdated.connect(self.iqIdUpdated)
        self._dispatcher.motorCurrentUpdated.connect(self.motorCurrentUpdated)

        # 将 Transport 信号转发至 Facade（供 QML 订阅）
        self._serial.connectionStatusChanged.connect(self._on_connection_status_changed)
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
        self._stop_heartbeat()
        self._serial.closePort()

    @Slot()
    def scanPorts(self) -> None:
        self._serial.Scan_Ports()

    @Slot(str)
    def addManualPort(self, port_name: str) -> None:
        self._serial.addManualPort(port_name)

    # ── 电机命令 API ──────────────────────────────────────────────────────────────

    @Slot(int, int)
    def setMotorControl(self, enable: int, speed_rpm: int) -> None:
        """
        设置电机控制目标并立即发送一帧，同时启动周期性保活定时器。

        CMD 0x01 Payload:
            Offset 0  1 byte  uint8  使能位（0=松轴, 1=使能）
            Offset 1  2 bytes int16  目标转速 (rpm), Big-Endian

        Args:
            enable:    0 = 松轴 / 停止, 1 = 使能
            speed_rpm: 目标转速（rpm，有符号）
        """
        self._motor_enable = enable
        self._motor_target_speed = speed_rpm
        self._send_motor_cmd()

        if enable:
            if not self._motor_cmd_timer.isActive():
                self._motor_cmd_timer.start()
        else:
            self._motor_cmd_timer.stop()

    @Slot()
    def stopMotor(self) -> None:
        """紧急停机：停止保活定时器并发送松轴指令。"""
        self._motor_cmd_timer.stop()
        self._motor_enable = 0
        self._motor_target_speed = 0
        self._send_motor_cmd()

    def _send_motor_cmd(self) -> None:
        """内部：编码 CMD 0x01 帧并通过 Transport 发送。"""
        frame = build_motor_control(self._motor_enable, self._motor_target_speed)
        self._serial.sendData(frame)

    def _send_heartbeat(self) -> None:
        """Internal: encode CMD 0x02 heartbeat frame and send it via Transport."""
        self._serial.sendData(build_pc_heartbeat())

    def _start_heartbeat(self) -> None:
        if not self._heartbeat_timer.isActive():
            self._heartbeat_timer.start()

    def _stop_heartbeat(self) -> None:
        if self._heartbeat_timer.isActive():
            self._heartbeat_timer.stop()

    @Slot(bool, str)
    def _on_connection_status_changed(self, connected: bool, message: str) -> None:
        if connected:
            self._start_heartbeat()
        else:
            self._stop_heartbeat()
        self.connectionStatusChanged.emit(connected, message)
