"""FrameDispatcher - 帧分发器

职责:
  - 接收来自 DataProcessor 的 ParsedFrame
  - 根据 CMD 字段路由到对应解码方法
  - 解码 payload 并发出业务语义信号

协议支持（MCU → PC）:
  CMD 0x64  Speed Feedback       当前转速（int16, rpm）
  CMD 0x65  Motor Temperature    电机温度（int16, 单位 0.1℃）
  CMD 0x66  MOS Temperature      MOS 温度（int16, 单位 0.1℃）
  CMD 0x67  Motor Enable State   使能状态（uint8）
  CMD 0x68  Error Code           错误码（uint16）
"""

import struct

from PySide6.QtCore import QObject, Signal, Slot

from core.protocol.protocol_frame import ParsedFrame

# ── 命令字常量 ─────────────────────────────────────────────────────────────────
CMD_SPEED_FEEDBACK:        int = 0x64   # MCU → PC: 转速反馈（2 bytes, int16, big-endian）
CMD_MOTOR_TEMPERATURE:     int = 0x65   # MCU → PC: 电机温度（2 bytes, int16, 单位 0.1℃）
CMD_MOS_TEMPERATURE:       int = 0x66   # MCU → PC: MOS 温度（2 bytes, int16, 单位 0.1℃）
CMD_MOTOR_ENABLE_STATE:    int = 0x67   # MCU → PC: 使能状态（1 byte, uint8）
CMD_ERROR_CODE:            int = 0x68   # MCU → PC: 错误码（2 bytes, uint16）


class FrameDispatcher(QObject):
    """
    帧分发器，将 ParsedFrame 解码为业务信号。

    被 DataProcessor.telemetryUpdated 信号驱动，
    不持有缓冲区，不做 CRC 验证（已由协议层完成）。

    Signals:
        speedUpdated(int):       CMD 0x64 — 当前转速 rpm（有符号）
        motorTempUpdated(float): CMD 0x65 — 电机温度 ℃（已转换为浮点）
        mosTempUpdated(float):   CMD 0x66 — MOS 温度 ℃（已转换为浮点）
        enableStateUpdated(int): CMD 0x67 — 使能状态（0/1）
        errorCodeUpdated(int):   CMD 0x68 — 错误码（无符号）
    """

    speedUpdated      = Signal(int)    # 当前转速 rpm
    motorTempUpdated  = Signal(float)  # 电机温度 ℃
    mosTempUpdated    = Signal(float)  # MOS 温度 ℃
    enableStateUpdated = Signal(int)   # 使能状态 0/1
    errorCodeUpdated  = Signal(int)    # 错误码

    def __init__(self, parent=None):
        super().__init__(parent)
        self._handlers = {
            CMD_SPEED_FEEDBACK:     self._handle_speed_feedback,
            CMD_MOTOR_TEMPERATURE:  self._handle_motor_temperature,
            CMD_MOS_TEMPERATURE:    self._handle_mos_temperature,
            CMD_MOTOR_ENABLE_STATE: self._handle_motor_enable_state,
            CMD_ERROR_CODE:         self._handle_error_code,
        }

    # ── 帧分发入口 ──────────────────────────────────────────────────────────────

    @Slot(object)
    def dispatch(self, frame: ParsedFrame) -> None:
        """
        接收 ParsedFrame，根据 cmd 路由到对应处理方法。
        未知 cmd 静默忽略，不抛出异常。
        """
        handler = self._handlers.get(frame.cmd)
        if handler is not None:
            handler(frame)

    # ── CMD 0x64: Speed Feedback ───────────────────────────────────────────────

    def _handle_speed_feedback(self, frame: ParsedFrame) -> None:
        """
        解码转速反馈帧（CMD 0x64）。

        Payload 格式:
            Offset 0  2 bytes  int16  当前转速 (rpm), Big-Endian
        """
        if frame.datalen < 2:
            return
        (speed,) = struct.unpack_from('>h', frame.data, 0)
        print(f"[FrameDispatcher] Speed Feedback: {speed} rpm", flush=True)  # Debug log
        self.speedUpdated.emit(speed)

    # ── CMD 0x65: Motor Temperature ───────────────────────────────────────────

    def _handle_motor_temperature(self, frame: ParsedFrame) -> None:
        """
        解码电机温度帧（CMD 0x65）。

        Payload 格式:
            Offset 0  2 bytes  int16  当前温度（单位 0.1℃），转换后发出 float ℃
        """
        if frame.datalen < 2:
            return
        (raw,) = struct.unpack_from('>h', frame.data, 0)
        print(f"[FrameDispatcher] Motor Temperature: {raw / 10.0} ℃", flush=True)  # Debug log  
        self.motorTempUpdated.emit(raw / 10.0)

    # ── CMD 0x66: MOS Temperature ─────────────────────────────────────────────

    def _handle_mos_temperature(self, frame: ParsedFrame) -> None:
        """
        解码 MOS 温度帧（CMD 0x66）。

        Payload 格式:
            Offset 0  2 bytes  int16  当前温度（单位 0.1℃），转换后发出 float ℃
        """
        if frame.datalen < 2:
            return
        (raw,) = struct.unpack_from('>h', frame.data, 0)
        print(f"[FrameDispatcher] MOS Temperature: {raw / 10.0} ℃", flush=True)  # Debug log
        self.mosTempUpdated.emit(raw / 10.0)

    # ── CMD 0x67: Motor Enable State ─────────────────────────────────────────

    def _handle_motor_enable_state(self, frame: ParsedFrame) -> None:
        """
        解码使能状态帧（CMD 0x67）。

        Payload 格式:
            Offset 0  1 byte  uint8  使能状态（0：未使能，1：使能）
        """
        if frame.datalen < 1:
            return
        state = frame.data[0]
        print(f"[FrameDispatcher] Motor Enable State: {state}", flush=True)  # Debug log
        self.enableStateUpdated.emit(state)

    # ── CMD 0x68: Error Code ──────────────────────────────────────────────────

    def _handle_error_code(self, frame: ParsedFrame) -> None:
        """
        解码错误码帧（CMD 0x68）。

        Payload 格式:
            Offset 0  2 bytes  uint16  错误码，Big-Endian
        """
        if frame.datalen < 2:
            return
        (code,) = struct.unpack_from('>H', frame.data, 0)
        print(f"[FrameDispatcher] Error Code: {code}", flush=True)  # Debug log
        self.errorCodeUpdated.emit(code)
