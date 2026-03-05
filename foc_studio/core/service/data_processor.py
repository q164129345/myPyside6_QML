from PySide6.QtCore import QObject, Signal, Slot, Property

from core.protocol.protocol_frame import ParsedFrame, parse_frame_from_buffer

class DataProcessor(QObject):
    """
    数据处理模块，负责处理接收到的原始数据
    """
    def __init__(self):
        super().__init__()
        self._buffer = bytearray()

    @Slot(bytes)
    def process_data(self, data: bytes) -> None:
        print(f"[DataProcessor] Processing {len(data)} bytes {data}", flush=True)
        self._buffer.extend(data)

        while True:
            result = parse_frame_from_buffer(self._buffer)
            if result is None:
                break

            frame_data, consumed = result
            full_frame = bytes(self._buffer[:consumed])
            del self._buffer[:consumed]

            if frame_data is None:
                continue

            print(
                "[DataProcessor] Protocol parsed: "
                f"frame={full_frame.hex(' ').upper()} "
                f"cmd=0x{frame_data.cmd:02X} "
                f"len={frame_data.datalen} "
                f"data={frame_data.data.hex(' ').upper()} "
                f"crc=0x{frame_data.crc:04X}",
                flush=True,
            )














