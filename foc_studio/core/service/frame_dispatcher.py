"""FrameDispatcher - 帧分发器。
职责：
  - 接收来自 DataProcessor 的 ParsedFrame
  - 根据 CMD 路由到对应解码方法
  - 将 payload 解码为业务语义信号
协议支持（MCU -> PC）：
  CMD 0x64  转速反馈            int16, rpm
  CMD 0x65  电机温度            int16, 单位 0.1℃
  CMD 0x66  MOS 温度            int16, 单位 0.1℃
  CMD 0x67  电机使能状态        uint8
  CMD 0x68  软件版本响应         4 * uint8 (main/sub/mini/fixed)
  CMD 0x69  Iq/Id/Uq/Ud         4 * int16，按 1/1000 还原为 float
  CMD 0x6A  电机电流            int16, 单位 0.001A
  CMD 0x6C  错误码              uint16
  CMD 0x6D  电机类型            uint8
  CMD 0x6E  速度环参数          5 * int32，按 1/1000000 还原为 float
  CMD 0x6F  电流环参数          5 * int32，按 1/1000000 还原为 float
  CMD 0x70  TUNE 参数保存结果     uint8，0=成功 1=失败
  CMD 0x72  电机限幅参数         2 * int32，按 1/1000000 还原为 float
"""

import struct

from PySide6.QtCore import QObject, Signal, Slot

from core.protocol.protocol_frame import ParsedFrame

# 命令字常量
CMD_SPEED_FEEDBACK: int = 0x64
CMD_MOTOR_TEMPERATURE: int = 0x65
CMD_MOS_TEMPERATURE: int = 0x66
CMD_MOTOR_ENABLE_STATE: int = 0x67
CMD_SOFTWARE_VERSION: int = 0x68
CMD_DQ_COMPONENTS: int = 0x69
CMD_MOTOR_CURRENT: int = 0x6A
CMD_ERROR_CODE: int = 0x6C
CMD_MOTOR_TYPE: int = 0x6D
CMD_SPEED_LOOP_PARAMS: int = 0x6E
CMD_CURRENT_LOOP_PARAMS: int = 0x6F
CMD_SAVE_TUNE_PARAMS_RESULT: int = 0x70
CMD_MOTOR_LIMITS: int = 0x72
CMD_LOG_MESSAGE: int = 0x73


class FrameDispatcher(QObject):
    """将协议帧解码为 Qt 业务信号。"""

    speedUpdated = Signal(int)                         # 当前转速 rpm
    motorTempUpdated = Signal(float)                  # 电机温度 ℃
    mosTempUpdated = Signal(float)                    # MOS 温度 ℃
    enableStateUpdated = Signal(int)                  # 使能状态 0/1
    mcuSoftwareVersionUpdated = Signal(int, int, int, int)  # main, sub, mini, fixed
    errorCodeUpdated = Signal(int)                    # 错误码
    dqComponentsUpdated = Signal(float, float, float, float)  # Iq, Id, Uq, Ud
    motorCurrentUpdated = Signal(float)               # 电机电流 A

    mcuMotorTypeUpdated = Signal(int)                 # 电机类型 0~255
    speedLoopParamsUpdated = Signal(float, float, float, float, float)    # Kp, Ki, Kd, Ramp, Tf
    currentLoopParamsUpdated = Signal(float, float, float, float, float)  # Kp, Ki, Kd, Ramp, Tf
    saveTuneParamsResultUpdated = Signal(int)          # 0=成功 1=失败
    motorLimitsUpdated = Signal(float, float)         # voltage_limit, current_limit
    logMessageReceived = Signal(int, str)              # level(0=INFO,1=WARN,2=ERROR), message

    def __init__(self, parent=None):
        super().__init__(parent)
        self._handlers = {
            CMD_SPEED_FEEDBACK: self._handle_speed_feedback,
            CMD_MOTOR_TEMPERATURE: self._handle_motor_temperature,
            CMD_MOS_TEMPERATURE: self._handle_mos_temperature,
            CMD_MOTOR_ENABLE_STATE: self._handle_motor_enable_state,
            CMD_SOFTWARE_VERSION: self._handle_software_version,
            CMD_DQ_COMPONENTS: self._handle_dq_components,
            CMD_MOTOR_CURRENT: self._handle_motor_current,
            CMD_ERROR_CODE: self._handle_error_code,
            CMD_MOTOR_TYPE: self._handle_motor_type,
            CMD_SPEED_LOOP_PARAMS: self._handle_speed_loop_params,
            CMD_CURRENT_LOOP_PARAMS: self._handle_current_loop_params,
            CMD_SAVE_TUNE_PARAMS_RESULT: self._handle_save_tune_params_result,
            CMD_MOTOR_LIMITS: self._handle_motor_limits,
            CMD_LOG_MESSAGE: self._handle_log_message,
        }

    @Slot(object)
    def dispatch(self, frame: ParsedFrame) -> None:
        """按命令字分发帧；未知命令静默忽略。"""
        handler = self._handlers.get(frame.cmd)
        if handler is not None:
            handler(frame)

    def _handle_speed_feedback(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x64：当前转速。"""
        if frame.datalen != 2:
            return
        (speed,) = struct.unpack_from(">h", frame.data, 0)
        self.speedUpdated.emit(speed)

    def _handle_motor_temperature(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x65：电机温度，原始单位 0.1℃。"""
        if frame.datalen != 2:
            return
        (raw,) = struct.unpack_from(">h", frame.data, 0)
        self.motorTempUpdated.emit(raw / 10.0)

    def _handle_mos_temperature(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x66：MOS 温度，原始单位 0.1℃。"""
        if frame.datalen != 2:
            return
        (raw,) = struct.unpack_from(">h", frame.data, 0)
        self.mosTempUpdated.emit(raw / 10.0)

    def _handle_motor_enable_state(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x67：电机使能状态。"""
        if frame.datalen != 1:
            return
        self.enableStateUpdated.emit(frame.data[0])

    def _handle_software_version(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x68：软件版本 main/sub/mini/fixed。"""
        if frame.datalen != 4:
            return
        self.mcuSoftwareVersionUpdated.emit(
            frame.data[0],
            frame.data[1],
            frame.data[2],
            frame.data[3],
        )

    def _handle_error_code(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x6C：错误码。"""
        if frame.datalen != 2:
            return
        (code,) = struct.unpack_from(">H", frame.data, 0)
        self.errorCodeUpdated.emit(code)

    def _handle_dq_components(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x69：Iq/Id/Uq/Ud，按 1/1000 转换为工程量。"""
        if frame.datalen != 8:
            return
        raw_iq, raw_id, raw_uq, raw_ud = struct.unpack_from(">hhhh", frame.data, 0)
        self.dqComponentsUpdated.emit(
            raw_iq / 1000.0,
            raw_id / 1000.0,
            raw_uq / 1000.0,
            raw_ud / 1000.0,
        )

    def _handle_motor_current(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x6A：电机电流，原始单位 0.001A。"""
        if frame.datalen != 2:
            return
        (raw,) = struct.unpack_from(">h", frame.data, 0)
        self.motorCurrentUpdated.emit(raw / 1000.0)

    def _handle_motor_type(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x6D：电机类型。"""
        if frame.datalen != 1:
            return
        self.mcuMotorTypeUpdated.emit(frame.data[0])

    def _handle_speed_loop_params(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x6E：速度环 PID 参数，按 1/1000000 还原为工程量。"""
        if frame.datalen != 20:
            return
        # 协议已升级为五参数模型，固定顺序为 kp/ki/kd/ramp/tf
        raw_kp, raw_ki, raw_kd, raw_ramp, raw_tf = struct.unpack_from(">iiiii", frame.data, 0)
        self.speedLoopParamsUpdated.emit(
            raw_kp / 1000000.0,
            raw_ki / 1000000.0,
            raw_kd / 1000000.0,
            raw_ramp / 1000000.0,
            raw_tf / 1000000.0,
        )

    def _handle_current_loop_params(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x6F：电流环 PID 参数，按 1/1000000 还原为工程量。"""
        if frame.datalen != 20:
            return
        # 协议已升级为五参数模型，固定顺序为 kp/ki/kd/ramp/tf
        raw_kp, raw_ki, raw_kd, raw_ramp, raw_tf = struct.unpack_from(">iiiii", frame.data, 0)
        self.currentLoopParamsUpdated.emit(
            raw_kp / 1000000.0,
            raw_ki / 1000000.0,
            raw_kd / 1000000.0,
            raw_ramp / 1000000.0,
            raw_tf / 1000000.0,
        )

    def _handle_save_tune_params_result(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x70：当前 TUNE 参数保存结果。"""
        if frame.datalen != 1:
            return
        self.saveTuneParamsResultUpdated.emit(frame.data[0])

    def _handle_motor_limits(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x72：电机限幅参数，按 1/1000000 还原为工程量。"""
        if frame.datalen != 8:
            return
        raw_voltage_limit, raw_current_limit = struct.unpack_from(">ii", frame.data, 0)
        self.motorLimitsUpdated.emit(
            raw_voltage_limit / 1000000.0,
            raw_current_limit / 1000000.0,
        )

    def _handle_log_message(self, frame: ParsedFrame) -> None:
        """解码 CMD 0x73：日志消息，Level(1byte) + Message(ASCII)。"""
        if frame.datalen < 1:
            return
        level = min(frame.data[0], 2)  # 0=INFO, 1=WARN, 2=ERROR；越界归为 ERROR
        message = frame.data[1:].decode("ascii", errors="replace")
        self.logMessageReceived.emit(level, message)
