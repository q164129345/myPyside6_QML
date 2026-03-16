from PySide6.QtCore import QObject, Signal, Slot

from core.protocol.protocol_frame import (
    PARSE_STATUS_CRC_ERROR,
    PARSE_STATUS_FRAME,
    PARSE_STATUS_INVALID,
    ParsedFrame,
    parse_frame_from_buffer,
)


class DataProcessor(QObject):
    """
    数据处理模块，负责处理接收到的原始数据。

    职责：
      - 维护接收缓冲区，将碎片字节拼接成完整帧
      - 调用协议层完成帧识别与 CRC 校验
      - 将有效帧与错误事件通过 Qt 信号分发给上层
    """

    telemetryUpdated = Signal(ParsedFrame)  # 解析成功时发出，携带 ParsedFrame 对象
    crcErrorDetected = Signal()  # CRC 校验失败时发出，用于统计接收质量
    invalidFrameDetected = Signal()  # 丢弃前导垃圾或无效帧头时发出

    def __init__(self):
        """初始化接收缓冲区，准备做增量解析。"""
        super().__init__()
        self._buffer = bytearray()  # 接收缓冲区：持续累积来自串口的原始字节，直到凑齐完整帧

    @Slot()
    def reset(self) -> None:
        """在连接边界清空解析缓冲区，避免上一会话残留半帧污染新会话。"""
        self._buffer.clear()

    @Slot(bytes)
    def process_data(self, data: bytes) -> None:
        """处理原始接收字节流，并按解析结果分类发出信号。"""
        self._buffer.extend(data)  # 将新到达的字节追加到缓冲区末尾

        # 循环尝试从缓冲区中解析出尽可能多的完整帧
        while True:
            result = parse_frame_from_buffer(self._buffer)

            if result is None:  # 缓冲区内字节不足以构成一帧，等待下一次数据到达
                break

            # 从缓冲区头部移除已处理的字节，包括前导垃圾、CRC 错误帧或有效帧
            del self._buffer[:result.consumed]

            # 将不同错误类型拆分成独立信号，便于统计层精确计数
            if result.status == PARSE_STATUS_INVALID:
                self.invalidFrameDetected.emit()
                continue

            if result.status == PARSE_STATUS_CRC_ERROR:
                self.crcErrorDetected.emit()
                continue

            if result.status == PARSE_STATUS_FRAME and result.frame is not None:
                self.telemetryUpdated.emit(result.frame)
