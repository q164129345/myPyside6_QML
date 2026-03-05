from PySide6.QtCore import QObject, Signal, Slot, Property

from core.protocol.protocol_frame import ParsedFrame, parse_frame_from_buffer


class DataProcessor(QObject):
    """
    数据处理模块，负责处理接收到的原始数据。

    职责：
      - 维护接收缓冲区，将碎片字节拼接成完整帧（应对粘包/半包）
      - 调用协议层完成帧识别与 CRC 校验
      - 将解析结果通过 Qt 信号分发给上层（待实现）
    """
    telemetryUpdated = Signal(ParsedFrame) # 解析成功时发出，携带 ParsedFrame对象

    def __init__(self):
        super().__init__()
        self._buffer = bytearray() # 接收缓冲区：持续累积来自串口的原始字节，直到凑齐完整帧

    @Slot(bytes)
    def process_data(self, data: bytes) -> None:
        # print(f"[DataProcessor] Processing {len(data)} bytes {data}", flush=True)
        self._buffer.extend(data) # 将新到达的字节追加到缓冲区末尾

        # 循环尝试从缓冲区中解析出尽可能多的完整帧
        while True:
            result = parse_frame_from_buffer(self._buffer)

            if result is None: # 缓冲区内字节不足以构成一帧，等待下一次数据到达
                break

            frame_data, consumed = result # 解析结果：frame_data为ParsedFrame对象或None，consumed为已处理字节数

            # 从缓冲区头部移除已处理的字节（包括垃圾前缀或完整帧）
            del self._buffer[:consumed]

            if frame_data is None: # 发现无效帧头或 CRC 校验失败，已丢弃垃圾字节，继续尝试解析
                continue

            self.telemetryUpdated.emit(frame_data) # 发出信号   














