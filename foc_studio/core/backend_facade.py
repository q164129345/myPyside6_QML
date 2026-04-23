from typing import Any

from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot

from core.command.motor_command import build_motor_control
from core.command.motor_type_command import build_query_motor_type
from core.command.pc_heartbeat_command import build_pc_heartbeat
from core.command.software_version_command import build_query_software_version
from core.command.tune_params_command import (
    build_save_current_tune_params_to_flash,
    build_query_current_loop_params,
    build_query_motor_limits,
    build_query_speed_loop_params,
    build_set_current_loop_params,
    build_set_motor_limits,
    build_set_speed_loop_params,
)
from core.service.data_processor import DataProcessor
from core.service.frame_dispatcher import FrameDispatcher
from core.service.serial_statistics_service import SerialStatisticsService
from core.transport.serial import mySerial


DEFAULT_MCU_VERSION = "0.0.0.0"
DEFAULT_MOTOR_TYPE = 0
HALL_SUPPORTED_MOTOR_TYPE = 2
TUNE_PARAM_READ_TIMEOUT_MS = 1500
TUNE_PARAM_SAVE_TIMEOUT_MS = 3000
TUNE_PARAM_STATUS_IDLE = "未读取参数"
TUNE_PARAM_STATUS_READING = "正在读取参数"
TUNE_PARAM_STATUS_APPLYING = "正在应用参数并读回校验"
TUNE_PARAM_STATUS_SYNCED = "参数已同步"
TUNE_PARAM_STATUS_APPLY_TIMEOUT = "应用参数后读回超时"
TUNE_PARAM_STATUS_READ_TIMEOUT = "读取参数超时"
TUNE_PARAM_STATUS_SAVE_REQUIRES_SYNC = "请先读取并确认当前 TUNE 参数后再保存"
TUNE_PARAM_STATUS_SAVING = "正在保存当前 TUNE 参数到 FLASH"
TUNE_PARAM_STATUS_SAVE_SUCCESS = "当前 TUNE 参数已保存到 FLASH"
TUNE_PARAM_STATUS_SAVE_TIMEOUT = "保存当前 TUNE 参数超时"
TUNE_PARAM_STATUS_SAVE_FAILED = "保存当前 TUNE 参数失败"


def _default_control_params() -> dict[str, dict[str, float]]:
    """创建默认的 PID 参数缓存对象。"""
    return {
        "speedLoop": {"kp": 0.0, "ki": 0.0, "kd": 0.0, "ramp": 0.0, "tf": 0.0},
        "currentLoop": {"kp": 0.0, "ki": 0.0, "kd": 0.0, "ramp": 0.0, "tf": 0.0},
        "motorLimits": {"voltage_limit": 0.0, "current_limit": 0.0},
    }


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
    speedUpdated = Signal(int, float)                         # 当前转速 rpm, pc_timestamp_ms
    motorTempUpdated = Signal(float)                          # 电机温度 ℃
    mosTempUpdated = Signal(float)                            # MOS 温度 ℃
    enableStateUpdated = Signal(int)                          # 使能状态 0/1
    errorCodeUpdated = Signal(int)                            # 错误码
    dqComponentsUpdated = Signal(float, float, float, float, float)  # Iq, Id, Uq, Ud, pc_ts
    motorCurrentUpdated = Signal(float, float)                # 电机电流 A, pc_timestamp_ms
    mcuSoftwareVersionUpdated = Signal(str)           # 下位机软件版本（main.sub.mini.fixed）

    mcuMotorTypeUpdated = Signal(int)                 # 下位机电机类型（1~5，0=未知）
    hallTelemetryUpdated = Signal(int, int, int, int, int, float)  # Hall A/B/C、hall_state、电气扇区、pc_ts
    hallTelemetryChanged = Signal()

    txFrameCountTotalChanged = Signal()
    rxFrameCountTotalChanged = Signal()
    txBytesTotalChanged = Signal()
    rxBytesTotalChanged = Signal()
    txBytesPerSecChanged = Signal()
    rxBytesPerSecChanged = Signal()
    rxCrcErrorCountChanged = Signal()
    rxInvalidFrameCountChanged = Signal()
    controlParamsChanged = Signal()
    controlParamsAvailableChanged = Signal()
    controlParamsBusyChanged = Signal()
    controlParamsLastStatusChanged = Signal()
    tuneSaveSucceeded = Signal()
    logMessageReceived = Signal(int, str)              # level, message（转发自 FrameDispatcher）

    def __init__(self) -> None:
        super().__init__()
        # 统一纳入 Qt 对象树，避免未来重建门面对象时出现悬挂 QObject。
        self._serial = mySerial(self)
        self._processor = DataProcessor(self)
        self._dispatcher = FrameDispatcher(self)
        self._serial_stats = SerialStatisticsService(self)

        # 电机控制目标，用于 500ms 周期保活发送 CMD 0x01
        self._motor_enable: int = 0
        self._motor_target_speed: int = 0

        # 下位机软件版本缓存，默认值表示尚未获取到有效版本
        self._mcu_version_text: str = DEFAULT_MCU_VERSION
        # 下位机电机类型缓存，0 表示未知
        self._mcu_motor_type: int = DEFAULT_MOTOR_TYPE
        # HALL 页面缓存：保存最近一次有效霍尔遥测，available 表示是否收到过有效帧
        self._hall_a: int = 0
        self._hall_b: int = 0
        self._hall_c: int = 0
        self._hall_state: int = 0
        self._electric_sector: int = -1
        self._hall_telemetry_available: bool = False
        # TUNE 页面控制参数缓存，按速度环 / 电流环分别保存最近一次回读值
        self._control_params: dict[str, dict[str, float]] = _default_control_params()
        # TUNE 页面参数是否已完成一轮有效读回
        self._control_params_available: bool = False
        # TUNE 页面参数当前是否处于读取或写后读回阶段
        self._control_params_busy: bool = False
        # TUNE 页面最近一次参数操作的状态文案
        self._control_params_last_status: str = TUNE_PARAM_STATUS_IDLE
        # 当前一轮参数读回仍在等待的环路集合，用于判断何时完成同步
        self._pending_param_loops: set[str] = set()
        # 标记当前读回是否属于“应用参数后读回校验”流程
        self._post_write_readback_pending: bool = False
        # 标记当前是否处于“保存当前运行参数到 FLASH”流程
        self._save_to_flash_pending: bool = False

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

        # 电机类型查询轮询定时器：连接后若类型仍是 0，每 1 秒发送一次 CMD 0x04
        self._motor_type_query_timer = QTimer(self)
        self._motor_type_query_timer.setInterval(1000)
        self._motor_type_query_timer.timeout.connect(self._on_motor_type_query_timer)

        # TUNE 页面参数超时定时器：读取或写后读回超时后复位 busy 并更新状态
        self._tune_param_timeout_timer = QTimer(self)
        self._tune_param_timeout_timer.setSingleShot(True)
        self._tune_param_timeout_timer.setInterval(TUNE_PARAM_READ_TIMEOUT_MS)
        self._tune_param_timeout_timer.timeout.connect(self._on_tune_param_timeout)

        # Transport -> Service
        self._serial.dataReceived.connect(self._processor.process_data)
        self._serial.dataReceived.connect(self._serial_stats.onDataReceived)
        self._serial.dataWritten.connect(self._serial_stats.onDataWritten)
        self._processor.telemetryUpdated.connect(self._dispatcher.dispatch)
        self._processor.telemetryUpdated.connect(self._serial_stats.onFrameParsed)
        self._processor.crcErrorDetected.connect(self._serial_stats.onCrcErrorDetected)
        self._processor.invalidFrameDetected.connect(self._serial_stats.onInvalidFrameDetected)

        # Dispatcher -> Facade -> QML
        self._dispatcher.speedUpdated.connect(self.speedUpdated)
        self._dispatcher.motorTempUpdated.connect(self.motorTempUpdated)
        self._dispatcher.mosTempUpdated.connect(self.mosTempUpdated)
        self._dispatcher.enableStateUpdated.connect(self.enableStateUpdated)
        self._dispatcher.errorCodeUpdated.connect(self.errorCodeUpdated)
        self._dispatcher.dqComponentsUpdated.connect(self.dqComponentsUpdated)
        self._dispatcher.motorCurrentUpdated.connect(self.motorCurrentUpdated)
        self._dispatcher.mcuSoftwareVersionUpdated.connect(self._on_mcu_version_updated)
        self._dispatcher.mcuMotorTypeUpdated.connect(self._on_mcu_motor_type_updated)
        self._dispatcher.hallTelemetryUpdated.connect(self._on_hall_telemetry_updated)
        self._dispatcher.speedLoopParamsUpdated.connect(self._on_speed_loop_params_updated)
        self._dispatcher.currentLoopParamsUpdated.connect(self._on_current_loop_params_updated)
        self._dispatcher.saveTuneParamsResultUpdated.connect(self._on_save_tune_params_result_updated)
        self._dispatcher.motorLimitsUpdated.connect(self._on_motor_limits_updated)
        self._dispatcher.logMessageReceived.connect(self.logMessageReceived)
        self._serial_stats.txFrameCountTotalChanged.connect(self.txFrameCountTotalChanged)
        self._serial_stats.rxFrameCountTotalChanged.connect(self.rxFrameCountTotalChanged)
        self._serial_stats.txBytesTotalChanged.connect(self.txBytesTotalChanged)
        self._serial_stats.rxBytesTotalChanged.connect(self.rxBytesTotalChanged)
        self._serial_stats.txBytesPerSecChanged.connect(self.txBytesPerSecChanged)
        self._serial_stats.rxBytesPerSecChanged.connect(self.rxBytesPerSecChanged)
        self._serial_stats.rxCrcErrorCountChanged.connect(self.rxCrcErrorCountChanged)
        self._serial_stats.rxInvalidFrameCountChanged.connect(self.rxInvalidFrameCountChanged)

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

    @Property(int, notify=mcuMotorTypeUpdated)  # type: ignore
    def mcuMotorType(self) -> int:
        """QML 只读属性：下位机电机类型（0=未知）。"""
        return self._mcu_motor_type

    @Property(int, notify=hallTelemetryChanged)  # type: ignore
    def hallA(self) -> int:
        """QML 只读属性：霍尔 A 原始电平。"""
        return self._hall_a

    @Property(int, notify=hallTelemetryChanged)  # type: ignore
    def hallB(self) -> int:
        """QML 只读属性：霍尔 B 原始电平。"""
        return self._hall_b

    @Property(int, notify=hallTelemetryChanged)  # type: ignore
    def hallC(self) -> int:
        """QML 只读属性：霍尔 C 原始电平。"""
        return self._hall_c

    @Property(int, notify=hallTelemetryChanged)  # type: ignore
    def hallState(self) -> int:
        """QML 只读属性：hall_state 原始值。"""
        return self._hall_state

    @Property(int, notify=hallTelemetryChanged)  # type: ignore
    def electricSector(self) -> int:
        """QML 只读属性：electric_sector 原始值。"""
        return self._electric_sector

    @Property(bool, notify=hallTelemetryChanged)  # type: ignore
    def hallTelemetryAvailable(self) -> bool:
        """QML 只读属性：是否收到过有效的 HALL 遥测。"""
        return self._hall_telemetry_available

    @Property(int, notify=txFrameCountTotalChanged)  # type: ignore
    def txFrameCountTotal(self) -> int:
        """QML 只读属性：当前会话累计发送完整帧数。"""
        return self._serial_stats.txFrameCountTotal

    @Property(int, notify=rxFrameCountTotalChanged)  # type: ignore
    def rxFrameCountTotal(self) -> int:
        """QML 只读属性：当前会话累计接收有效帧数。"""
        return self._serial_stats.rxFrameCountTotal

    @Property(int, notify=txBytesTotalChanged)  # type: ignore
    def txBytesTotal(self) -> int:
        """QML 只读属性：当前会话累计发送字节数。"""
        return self._serial_stats.txBytesTotal

    @Property(int, notify=rxBytesTotalChanged)  # type: ignore
    def rxBytesTotal(self) -> int:
        """QML 只读属性：当前会话累计接收原始字节数。"""
        return self._serial_stats.rxBytesTotal

    @Property(int, notify=txBytesPerSecChanged)  # type: ignore
    def txBytesPerSec(self) -> int:
        """QML 只读属性：最近 1 秒发送字节速率。"""
        return self._serial_stats.txBytesPerSec

    @Property(int, notify=rxBytesPerSecChanged)  # type: ignore
    def rxBytesPerSec(self) -> int:
        """QML 只读属性：最近 1 秒接收字节速率。"""
        return self._serial_stats.rxBytesPerSec

    @Property(int, notify=rxCrcErrorCountChanged)  # type: ignore
    def rxCrcErrorCount(self) -> int:
        """QML 只读属性：当前会话累计 CRC 错误次数。"""
        return self._serial_stats.rxCrcErrorCount

    @Property(int, notify=rxInvalidFrameCountChanged)  # type: ignore
    def rxInvalidFrameCount(self) -> int:
        """QML 只读属性：当前会话累计无效帧恢复次数。"""
        return self._serial_stats.rxInvalidFrameCount

    @Property("QVariantMap", notify=controlParamsChanged)  # type: ignore
    def controlParams(self) -> dict[str, dict[str, float]]:
        """QML 只读属性：TUNE 页面控制参数缓存。"""
        return {
            "speedLoop": dict(self._control_params["speedLoop"]),
            "currentLoop": dict(self._control_params["currentLoop"]),
            "motorLimits": dict(self._control_params["motorLimits"]),
        }

    @Property(bool, notify=controlParamsAvailableChanged)  # type: ignore
    def controlParamsAvailable(self) -> bool:
        """QML 只读属性：TUNE 页面参数是否已完成有效回读。"""
        return self._control_params_available

    @Property(bool, notify=controlParamsBusyChanged)  # type: ignore
    def controlParamsBusy(self) -> bool:
        """QML 只读属性：TUNE 页面参数当前是否忙碌。"""
        return self._control_params_busy

    @Property(str, notify=controlParamsLastStatusChanged)  # type: ignore
    def controlParamsLastStatus(self) -> str:
        """QML 只读属性：TUNE 页面最近一次参数操作状态。"""
        return self._control_params_last_status

    @Slot(str, int)
    def connectSerial(self, port_name: str, baud_rate: int = 9600) -> None:
        """打开串口连接。"""
        self._serial.openPort(port_name, baud_rate)

    @Slot()
    def disconnectSerial(self) -> None:
        """关闭串口连接，并停止心跳/版本轮询，版本回到默认值。"""
        self._stop_heartbeat()
        self._stop_version_query_loop()
        self._stop_motor_type_query_loop()
        self._reset_mcu_version()
        self._reset_mcu_motor_type()
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

    @Slot()
    def queryControlParams(self) -> None:
        """兼容 TUNE 页面入口：触发一次速度环和电流环参数读取。"""
        self.requestTuneParamsRefresh()

    @Slot()
    def requestTuneParamsRefresh(self) -> None:
        """TUNE 页面高层入口：按固定顺序读取速度环和电流环参数。"""
        self._start_tune_param_refresh(post_write_readback=False)

    @Slot(dict)
    def applyControlParams(self, params: dict[str, Any]) -> None:
        """接收 QML 聚合参数并下发到 MCU 当前运行态。"""
        if not self._serial.isConnected:
            self._set_control_params_last_status("串口未连接，无法应用参数")
            return
        if self._control_params_busy:
            self._set_control_params_last_status("参数同步中，请稍后再试")
            return

        try:
            speed_loop = self._extract_loop_params(params, "speedLoop")
            current_loop = self._extract_loop_params(params, "currentLoop")
            motor_limits = self._extract_motor_limits(params)
            self._serial.sendData(build_set_speed_loop_params(*speed_loop))
            self._serial.sendData(build_set_current_loop_params(*current_loop))
            self._serial.sendData(build_set_motor_limits(*motor_limits))
        except (KeyError, TypeError, ValueError) as error:
            self._set_control_params_last_status(f"参数校验失败: {error}")
            return

        self._start_tune_param_refresh(post_write_readback=True)

    @Slot()
    def saveCurrentTuneParamsToFlash(self) -> None:
        """触发 MCU 将当前运行中的 TUNE 参数写入 FLASH。"""
        if not self._serial.isConnected:
            self._set_control_params_last_status("串口未连接，无法保存当前 TUNE 参数到 FLASH")
            return
        if self._control_params_busy:
            self._set_control_params_last_status("参数同步中，请稍后再试")
            return
        if not self._control_params_available:
            # 协议允许直接保存 MCU 当前运行参数，但交互上要求先读回确认一次，避免误存未知运行态
            self._set_control_params_last_status(TUNE_PARAM_STATUS_SAVE_REQUIRES_SYNC)
            return

        # 保存动作不依赖 UI 草稿，只持久化 MCU 当前已经生效的全部 TUNE 运行参数
        self._save_to_flash_pending = True
        self._set_control_params_busy(True)
        self._set_control_params_last_status(TUNE_PARAM_STATUS_SAVING)
        self._tune_param_timeout_timer.setInterval(TUNE_PARAM_SAVE_TIMEOUT_MS)
        self._serial.sendData(build_save_current_tune_params_to_flash())
        self._tune_param_timeout_timer.start()

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

    def _send_motor_type_query_once(self) -> None:
        """连接状态下发送一次 CMD 0x04 电机类型查询帧。"""
        if self._serial.isConnected:
            self._serial.sendData(build_query_motor_type())

    def _start_tune_param_refresh(self, post_write_readback: bool) -> None:
        """启动一轮 TUNE 页面参数读取或写后读回流程。"""
        if not self._serial.isConnected:
            self._set_control_params_last_status("串口未连接，无法读取参数")
            return
        if self._control_params_busy:
            return

        self._pending_param_loops = {"speedLoop", "currentLoop", "motorLimits"}
        self._post_write_readback_pending = post_write_readback
        self._save_to_flash_pending = False
        self._set_control_params_available(False)
        self._set_control_params_busy(True)
        self._set_control_params_last_status(
            TUNE_PARAM_STATUS_APPLYING if post_write_readback else TUNE_PARAM_STATUS_READING
        )
        # TUNE 参数读取顺序固定为速度环、电流环、限幅参数，便于和页面展示顺序保持一致
        self._serial.sendData(build_query_speed_loop_params())
        self._serial.sendData(build_query_current_loop_params())
        self._serial.sendData(build_query_motor_limits())
        self._tune_param_timeout_timer.setInterval(TUNE_PARAM_READ_TIMEOUT_MS)
        self._tune_param_timeout_timer.start()

    def _extract_loop_params(
        self,
        params: dict[str, Any],
        loop_key: str,
    ) -> tuple[float, float, float, float, float]:
        """从 QML 传入的聚合参数中提取单个环路的五个工程量。"""
        loop_params = params[loop_key]
        return (
            float(loop_params["kp"]),
            float(loop_params["ki"]),
            float(loop_params["kd"]),
            float(loop_params["ramp"]),
            float(loop_params["tf"]),
        )

    def _extract_motor_limits(self, params: dict[str, Any]) -> tuple[float, float]:
        """从 QML 传入的聚合参数中提取电机限幅工程量。"""
        motor_limits = params["motorLimits"]
        return (
            float(motor_limits["voltage_limit"]),
            float(motor_limits["current_limit"]),
        )

    def _update_loop_params(
        self,
        loop_key: str,
        kp: float,
        ki: float,
        kd: float,
        ramp: float,
        tf: float,
    ) -> None:
        """更新某个环路的 PID 参数缓存，并通知 QML 当前值已变化。"""
        self._control_params[loop_key] = {
            "kp": kp,
            "ki": ki,
            "kd": kd,
            "ramp": ramp,
            "tf": tf,
        }
        self.controlParamsChanged.emit()

    def _update_motor_limits(self, voltage_limit: float, current_limit: float) -> None:
        """更新电机限幅缓存，并通知 QML 当前值已变化。"""
        self._control_params["motorLimits"] = {
            "voltage_limit": voltage_limit,
            "current_limit": current_limit,
        }
        self.controlParamsChanged.emit()

    def _set_hall_telemetry(
        self,
        hall_a: int,
        hall_b: int,
        hall_c: int,
        hall_state: int,
        electric_sector: int,
        available: bool,
    ) -> None:
        """更新 HALL 缓存，并在状态变化时通知 QML。"""
        if (
            self._hall_a == hall_a
            and self._hall_b == hall_b
            and self._hall_c == hall_c
            and self._hall_state == hall_state
            and self._electric_sector == electric_sector
            and self._hall_telemetry_available == available
        ):
            return

        self._hall_a = hall_a
        self._hall_b = hall_b
        self._hall_c = hall_c
        self._hall_state = hall_state
        self._electric_sector = electric_sector
        self._hall_telemetry_available = available
        self.hallTelemetryChanged.emit()

    def _finish_param_loop_response(self, loop_key: str) -> None:
        """消费某个分组的回读结果，并在三组都完成时结束 busy。"""
        if loop_key not in self._pending_param_loops:
            return

        self._pending_param_loops.remove(loop_key)
        if self._pending_param_loops:
            return

        self._tune_param_timeout_timer.stop()
        self._set_control_params_busy(False)
        self._set_control_params_available(True)
        self._set_control_params_last_status(TUNE_PARAM_STATUS_SYNCED)
        self._post_write_readback_pending = False
        self._save_to_flash_pending = False

    def _set_control_params_available(self, available: bool) -> None:
        """更新参数可用态，并在变化时通知 QML。"""
        if self._control_params_available != available:
            self._control_params_available = available
            self.controlParamsAvailableChanged.emit()

    def _set_control_params_busy(self, busy: bool) -> None:
        """更新参数忙碌态，并在变化时通知 QML。"""
        if self._control_params_busy != busy:
            self._control_params_busy = busy
            self.controlParamsBusyChanged.emit()

    def _set_control_params_last_status(self, status_text: str) -> None:
        """更新参数状态文案，并在变化时通知 QML。"""
        if self._control_params_last_status != status_text:
            self._control_params_last_status = status_text
            self.controlParamsLastStatusChanged.emit()

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

    def _start_motor_type_query_loop(self) -> None:
        """启动 1 秒电机类型查询轮询。"""
        if not self._motor_type_query_timer.isActive():
            self._motor_type_query_timer.start()

    def _stop_motor_type_query_loop(self) -> None:
        """停止电机类型查询轮询。"""
        if self._motor_type_query_timer.isActive():
            self._motor_type_query_timer.stop()

    def _on_version_query_timer(self) -> None:
        """定时轮询：仅在版本仍为默认值时继续发送查询。"""
        if not self._serial.isConnected:
            self._stop_version_query_loop()
            return
        if self._mcu_version_text == DEFAULT_MCU_VERSION:
            self._send_version_query_once()
        else:
            self._stop_version_query_loop()


    def _on_motor_type_query_timer(self) -> None:
        """定时轮询：仅在电机类型仍为未知值时继续发送查询。"""
        if not self._serial.isConnected:
            self._stop_motor_type_query_loop()
            return
        if self._mcu_motor_type == DEFAULT_MOTOR_TYPE:
            self._send_motor_type_query_once()
        else:
            self._stop_motor_type_query_loop()

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


    @Slot(int)
    def _on_mcu_motor_type_updated(self, motor_type: int) -> None:
        """收到下位机电机类型后更新缓存并通知 UI。"""
        valid_motor_type = motor_type if 1 <= motor_type <= 5 else DEFAULT_MOTOR_TYPE
        self._mcu_motor_type = valid_motor_type
        self.mcuMotorTypeUpdated.emit(valid_motor_type)
        if valid_motor_type != HALL_SUPPORTED_MOTOR_TYPE:
            self._reset_hall_telemetry()

        if valid_motor_type == DEFAULT_MOTOR_TYPE:
            if self._serial.isConnected:
                self._start_motor_type_query_loop()
        else:
            self._stop_motor_type_query_loop()

    @Slot(int, int, int, int, int)
    def _on_hall_telemetry_updated(
        self,
        hall_a: int,
        hall_b: int,
        hall_c: int,
        hall_state: int,
        electric_sector: int,
        pc_timestamp_ms: float,
    ) -> None:
        """收到 CMD 0x74 后更新 HALL 缓存，并转发给 QML 实时显示。"""
        self._set_hall_telemetry(
            hall_a,
            hall_b,
            hall_c,
            hall_state,
            electric_sector,
            True,
        )
        self.hallTelemetryUpdated.emit(
            hall_a,
            hall_b,
            hall_c,
            hall_state,
            electric_sector,
            pc_timestamp_ms,
        )

    @Slot(float, float, float, float, float)
    def _on_speed_loop_params_updated(
        self,
        kp: float,
        ki: float,
        kd: float,
        ramp: float,
        tf: float,
    ) -> None:
        """收到速度环参数回读后更新缓存，并尝试结束当前同步流程。"""
        self._update_loop_params("speedLoop", kp, ki, kd, ramp, tf)
        self._finish_param_loop_response("speedLoop")

    @Slot(float, float, float, float, float)
    def _on_current_loop_params_updated(
        self,
        kp: float,
        ki: float,
        kd: float,
        ramp: float,
        tf: float,
    ) -> None:
        """收到电流环参数回读后更新缓存，并尝试结束当前同步流程。"""
        self._update_loop_params("currentLoop", kp, ki, kd, ramp, tf)
        self._finish_param_loop_response("currentLoop")

    @Slot(float, float)
    def _on_motor_limits_updated(self, voltage_limit: float, current_limit: float) -> None:
        """收到电机限幅回读后更新缓存，并尝试结束当前同步流程。"""
        self._update_motor_limits(voltage_limit, current_limit)
        self._finish_param_loop_response("motorLimits")

    @Slot(int)
    def _on_save_tune_params_result_updated(self, status: int) -> None:
        """处理 MCU 返回的当前 TUNE 参数保存结果。"""
        if not self._save_to_flash_pending:
            return

        self._tune_param_timeout_timer.stop()
        self._save_to_flash_pending = False
        self._set_control_params_busy(False)
        self._set_control_params_last_status(
            TUNE_PARAM_STATUS_SAVE_SUCCESS if status == 0 else TUNE_PARAM_STATUS_SAVE_FAILED
        )
        if status == 0:
            self.tuneSaveSucceeded.emit()

    def _reset_mcu_motor_type(self) -> None:
        """将下位机电机类型复位到默认值，并在有变化时通知 UI。"""
        if self._mcu_motor_type != DEFAULT_MOTOR_TYPE:
            self._mcu_motor_type = DEFAULT_MOTOR_TYPE
            self.mcuMotorTypeUpdated.emit(self._mcu_motor_type)
        self._reset_hall_telemetry()

    def _reset_hall_telemetry(self) -> None:
        """将 HALL 页面缓存复位到默认无效态。"""
        self._set_hall_telemetry(0, 0, 0, 0, -1, False)

    def _reset_control_params(self) -> None:
        """断开串口时复位 TUNE 页面参数状态和缓存。"""
        self._tune_param_timeout_timer.stop()
        self._pending_param_loops.clear()
        self._post_write_readback_pending = False
        self._save_to_flash_pending = False
        self._control_params = _default_control_params()
        self.controlParamsChanged.emit()
        self._set_control_params_available(False)
        self._set_control_params_busy(False)
        self._set_control_params_last_status(TUNE_PARAM_STATUS_IDLE)

    def _on_tune_param_timeout(self) -> None:
        """处理 TUNE 页面参数读取或写后读回超时。"""
        if self._save_to_flash_pending:
            self._save_to_flash_pending = False
            self._set_control_params_busy(False)
            self._set_control_params_last_status(TUNE_PARAM_STATUS_SAVE_TIMEOUT)
            return

        self._pending_param_loops.clear()
        self._set_control_params_busy(False)
        self._set_control_params_available(False)
        self._set_control_params_last_status(
            TUNE_PARAM_STATUS_APPLY_TIMEOUT
            if self._post_write_readback_pending
            else TUNE_PARAM_STATUS_READ_TIMEOUT
        )
        self._post_write_readback_pending = False

    @Slot(bool, str)
    def _on_connection_status_changed(self, connected: bool, message: str) -> None:
        """连接建立时启动心跳与查询轮询；断开时停止并复位状态。"""
        if connected:
            # 新会话开始前先清空服务层接收缓冲，避免把上一会话半帧统计成错误
            self._processor.reset()
            self._serial_stats.reset()
            self._start_heartbeat()
            if self._mcu_version_text == DEFAULT_MCU_VERSION:
                self._send_version_query_once()
                self._start_version_query_loop()
            if self._mcu_motor_type == DEFAULT_MOTOR_TYPE:
                self._send_motor_type_query_once()
                self._start_motor_type_query_loop()
        else:
            self._stop_heartbeat()
            self._stop_version_query_loop()
            self._stop_motor_type_query_loop()
            # 断开时同步清空解析缓冲，避免残留字节带到下一次连接
            self._processor.reset()
            self._dispatcher.reset_clock_sync()
            self._reset_mcu_version()
            self._reset_mcu_motor_type()
            self._reset_hall_telemetry()
            self._reset_control_params()
        self.connectionStatusChanged.emit(connected, message)
