from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot

from core.command.motor_command import build_motor_control
from core.command.pc_heartbeat_command import build_pc_heartbeat
from core.command.software_version_command import build_query_software_version
from core.service.data_processor import DataProcessor
from core.service.frame_dispatcher import FrameDispatcher
from core.transport.serial import mySerial


DEFAULT_MCU_VERSION = "0.0.0.0"


class BackendFacade(QObject):
    """后端门面对象。

    职责：
    - 创建并持有 Transport / Service / Dispatcher
    - 建立后端各层信号连接
    - 向 QML 暴露统一接口与遥测信号
    """

    # 转发来自 Transport 的连接状态信号
    connectionStatusChanged = Signal(bool, str)
    isConnectedChanged = Signal()
    portsListChanged = Signal(list)

    # 转发来自 FrameDispatcher 的遥测信号
    speedUpdated = Signal(int)                         # 当前转速 rpm
    motorTempUpdated = Signal(float)                  # 电机温度 ℃
    mosTempUpdated = Signal(float)                    # MOS 温度 ℃
    enableStateUpdated = Signal(int)                  # 使能状态 0/1
    errorCodeUpdated = Signal(int)                    # 错误码
    dqComponentsUpdated = Signal(float, float, float, float)  # Iq, Id, Uq, Ud
    motorCurrentUpdated = Signal(float)               # 电机电流 A
    mcuSoftwareVersionUpdated = Signal(str)           # 下位机软件版本（main.sub.mini.fixed）

    def __init__(self) -> None:
        super().__init__()
        self._serial = mySerial()
        self._processor = DataProcessor()
        self._dispatcher = FrameDispatcher()

        # 电机控制目标，用于 500ms 周期保活发送 CMD 0x01
        self._motor_enable: int = 0
        self._motor_target_speed: int = 0

        # 下位机软件版本缓存，默认值表示尚未获取到有效版本
        self._mcu_version_text: str = DEFAULT_MCU_VERSION

        self._motor_cmd_timer = QTimer(self)
        self._motor_cmd_timer.setInterval(500)
        self._motor_cmd_timer.timeout.connect(self._send_motor_cmd)

        self._heartbeat_timer = QTimer(self)
        self._heartbeat_timer.setInterval(1000)
        self._heartbeat_timer.timeout.connect(self._send_heartbeat)

        # 版本查询轮询定时器：连接后若版本仍是 0.0.0.0，每 1 秒发送一次 CMD 0x03
        self._version_query_timer = QTimer(self)
        self._version_query_timer.setInterval(1000)
        self._version_query_timer.timeout.connect(self._on_version_query_timer)

        # Transport -> Service
        self._serial.dataReceived.connect(self._processor.process_data)
        self._processor.telemetryUpdated.connect(self._dispatcher.dispatch)

        # Dispatcher -> Facade -> QML
        self._dispatcher.speedUpdated.connect(self.speedUpdated)
        self._dispatcher.motorTempUpdated.connect(self.motorTempUpdated)
        self._dispatcher.mosTempUpdated.connect(self.mosTempUpdated)
        self._dispatcher.enableStateUpdated.connect(self.enableStateUpdated)
        self._dispatcher.errorCodeUpdated.connect(self.errorCodeUpdated)
        self._dispatcher.dqComponentsUpdated.connect(self.dqComponentsUpdated)
        self._dispatcher.motorCurrentUpdated.connect(self.motorCurrentUpdated)
        self._dispatcher.mcuSoftwareVersionUpdated.connect(self._on_mcu_version_updated)

        # 将串口层状态信号转发给 QML
        self._serial.connectionStatusChanged.connect(self._on_connection_status_changed)
        self._serial.isConnectedChanged.connect(self.isConnectedChanged)
        self._serial.portsListChanged.connect(self.portsListChanged)

    @Property(bool, notify=isConnectedChanged)  # type: ignore
    def isConnected(self) -> bool:
        """QML 只读属性：当前串口是否已连接。"""
        return self._serial.isConnected  # type: ignore[return-value]

    @Property(list, notify=portsListChanged)  # type: ignore
    def portsList(self) -> list:
        """QML 只读属性：当前可用串口列表。"""
        return self._serial.portsList  # type: ignore[return-value]

    @Property(str, notify=mcuSoftwareVersionUpdated)  # type: ignore
    def mcuSoftwareVersion(self) -> str:
        """QML 只读属性：下位机软件版本。"""
        return self._mcu_version_text

    @Slot(str, int)
    def connectSerial(self, port_name: str, baud_rate: int = 9600) -> None:
        """打开串口连接。"""
        self._serial.openPort(port_name, baud_rate)

    @Slot()
    def disconnectSerial(self) -> None:
        """关闭串口连接，并停止心跳/版本轮询，版本回到默认值。"""
        self._stop_heartbeat()
        self._stop_version_query_loop()
        self._reset_mcu_version()
        self._serial.closePort()

    @Slot()
    def scanPorts(self) -> None:
        """扫描系统串口。"""
        self._serial.Scan_Ports()

    @Slot(str)
    def addManualPort(self, port_name: str) -> None:
        """手动添加串口名到列表。"""
        self._serial.addManualPort(port_name)

    @Slot(int, int)
    def setMotorControl(self, enable: int, speed_rpm: int) -> None:
        """设置电机使能与目标转速，并立即发送一次控制帧。"""
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
        """停止电机，并发送松轴/停止指令。"""
        self._motor_cmd_timer.stop()
        self._motor_enable = 0
        self._motor_target_speed = 0
        self._send_motor_cmd()

    @Slot()
    def queryMcuSoftwareVersion(self) -> None:
        """手动触发一次版本查询（可选）。"""
        self._send_version_query_once()
        if self._mcu_version_text == DEFAULT_MCU_VERSION:
            self._start_version_query_loop()

    def _send_motor_cmd(self) -> None:
        """编码并发送 CMD 0x01 电机控制帧。"""
        self._serial.sendData(build_motor_control(self._motor_enable, self._motor_target_speed))

    def _send_heartbeat(self) -> None:
        """编码并发送 CMD 0x02 心跳帧。"""
        self._serial.sendData(build_pc_heartbeat())

    def _send_version_query_once(self) -> None:
        """连接状态下发送一次 CMD 0x03 版本查询帧。"""
        if self._serial.isConnected:
            self._serial.sendData(build_query_software_version())

    def _start_heartbeat(self) -> None:
        """启动 PC 心跳定时器。"""
        if not self._heartbeat_timer.isActive():
            self._heartbeat_timer.start()

    def _stop_heartbeat(self) -> None:
        """停止 PC 心跳定时器。"""
        if self._heartbeat_timer.isActive():
            self._heartbeat_timer.stop()

    def _start_version_query_loop(self) -> None:
        """启动 1 秒版本查询轮询。"""
        if not self._version_query_timer.isActive():
            self._version_query_timer.start()

    def _stop_version_query_loop(self) -> None:
        """停止版本查询轮询。"""
        if self._version_query_timer.isActive():
            self._version_query_timer.stop()

    def _on_version_query_timer(self) -> None:
        """定时轮询：仅在版本仍为默认值时继续发送查询。"""
        if not self._serial.isConnected:
            self._stop_version_query_loop()
            return
        if self._mcu_version_text == DEFAULT_MCU_VERSION:
            self._send_version_query_once()
        else:
            self._stop_version_query_loop()

    @Slot(int, int, int, int)
    def _on_mcu_version_updated(self, main: int, sub: int, mini: int, fixed: int) -> None:
        """收到下位机版本后更新缓存并通知 UI。"""
        version_text = f"{main}.{sub}.{mini}.{fixed}"
        self._mcu_version_text = version_text
        self.mcuSoftwareVersionUpdated.emit(version_text)

        if version_text == DEFAULT_MCU_VERSION:
            if self._serial.isConnected:
                self._start_version_query_loop()
        else:
            self._stop_version_query_loop()

    def _reset_mcu_version(self) -> None:
        """将下位机版本复位到默认值，并在有变化时通知 UI。"""
        if self._mcu_version_text != DEFAULT_MCU_VERSION:
            self._mcu_version_text = DEFAULT_MCU_VERSION
            self.mcuSoftwareVersionUpdated.emit(self._mcu_version_text)

    @Slot(bool, str)
    def _on_connection_status_changed(self, connected: bool, message: str) -> None:
        """连接建立时启动心跳与版本查询；断开时停止并复位版本。"""
        if connected:
            self._start_heartbeat()
            if self._mcu_version_text == DEFAULT_MCU_VERSION:
                self._send_version_query_once()
                self._start_version_query_loop()
        else:
            self._stop_heartbeat()
            self._stop_version_query_loop()
            self._reset_mcu_version()
        self.connectionStatusChanged.emit(connected, message)

